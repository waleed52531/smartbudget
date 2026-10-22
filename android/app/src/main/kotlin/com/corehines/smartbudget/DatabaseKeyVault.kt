package com.corehines.smartbudget

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.system.Os
import android.system.OsConstants
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Keystore wrapping keys never leave AndroidKeyStore. Only authenticated envelopes
 * reach disk, under noBackupFilesDir. No recovery/reset behavior is implicit. */
class DatabaseKeyVault(
    private val root: File,
    private val aliasPrefix: String = "smartbudget.db.wrap.v1."
) {
    constructor(context: Context) : this(File(context.noBackupFilesDir, "user_storage_v1"))

    class Unavailable : Exception("Protected database key unavailable")
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    fun rootPath(): String {
        if (!root.exists() && !root.mkdirs()) throw Unavailable()
        // Android may alias an app's parent directory (/data/user/0 vs /data/data).
        // Reject a linked vault root itself, then use its canonical parent path so
        // that the stricter child/envelope checks still reject app-created links.
        if (!root.isDirectory || OsConstants.S_ISLNK(Os.lstat(root.absolutePath).st_mode)) throw Unavailable()
        return root.canonicalPath
    }
    private fun scope(project: String, uid: String): String {
        if (!Regex("^[a-z][a-z0-9-]{4,62}$").matches(project) || uid.isEmpty() ||
            uid.length > 128 || uid.any { it.code < 32 || it.code == 127 }) throw Unavailable()
        return MessageDigest.getInstance("SHA-256").digest("$project\u0000$uid".toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 255) }
    }
    private fun folder(project: String, uid: String): File {
        val dir = File(rootPath(), scope(project, uid))
        if (dir.exists() && (!dir.isDirectory || dir.canonicalFile != dir.absoluteFile)) throw Unavailable()
        return dir
    }
    private fun envelope(project: String, uid: String): File {
        val file = File(folder(project, uid), "key.envelope.json")
        if (file.exists() && (!file.isFile || file.canonicalFile != file.absoluteFile)) throw Unavailable()
        return file
    }
    @Synchronized fun contains(project: String, uid: String): Boolean {
        // An orphan alias is also a recovery condition, never permission to rekey.
        return envelope(project, uid).exists() || keyStore.containsAlias(aliasPrefix + scope(project, uid))
    }
    @Synchronized fun syncDirectory(project: String, uid: String): Boolean {
        val dir = folder(project, uid)
        if (!dir.isDirectory) throw Unavailable()
        val descriptor = Os.open(dir.absolutePath, OsConstants.O_RDONLY, 0)
        try {
            if (!OsConstants.S_ISDIR(Os.fstat(descriptor).st_mode)) throw Unavailable()
            Os.fsync(descriptor)
        } finally { Os.close(descriptor) }
        return true
    }
    private fun aad(project: String, uid: String, id: String) =
        "smartbudget.database-key.v1\u0000$project\u0000$uid\u0000$id".toByteArray(Charsets.UTF_8)

    @Synchronized fun create(project: String, uid: String): Map<String, Any> {
        val file = envelope(project, uid)
        val alias = aliasPrefix + scope(project, uid)
        val dir = file.parentFile ?: throw Unavailable()
        if (contains(project, uid) || (dir.exists() && dir.listFiles()?.any { it.name != ".lock" } != false)) {
            throw Unavailable()
        }
        if (!dir.exists() && !dir.mkdirs()) throw Unavailable()
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true).build())
        val wrappingKey = generator.generateKey()
        val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
        val id = UUID.randomUUID().toString()
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, wrappingKey)
            cipher.updateAAD(aad(project, uid, id))
            val encrypted = cipher.doFinal(bytes)
            val record = JSONObject().put("version", 1).put("projectId", project).put("uid", uid)
                .put("databaseId", id).put("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                .put("ciphertext", Base64.encodeToString(encrypted, Base64.NO_WRAP))
            // Exclusive creation; a partial/crashed record remains a recovery condition.
            if (!file.createNewFile()) throw Unavailable()
            FileOutputStream(file, false).use { out ->
                out.write(record.toString().toByteArray(Charsets.UTF_8)); out.fd.sync()
            }
            return mapOf("key" to bytes.copyOf(), "databaseId" to id)
        } finally { bytes.fill(0) }
    }
    @Synchronized fun load(project: String, uid: String): Map<String, Any> {
        val file = envelope(project, uid)
        val alias = aliasPrefix + scope(project, uid)
        if (!file.isFile || file.length() !in 1..4096 || !keyStore.containsAlias(alias)) throw Unavailable()
        val record = JSONObject(file.readText(Charsets.UTF_8))
        val fields = setOf("version", "projectId", "uid", "databaseId", "iv", "ciphertext")
        if (record.keys().asSequence().toSet() != fields || record.getInt("version") != 1 ||
            record.getString("projectId") != project || record.getString("uid") != uid) throw Unavailable()
        val id = record.getString("databaseId")
        if (!Regex("^[a-f0-9-]{36}$").matches(id)) throw Unavailable()
        val iv = Base64.decode(record.getString("iv"), Base64.NO_WRAP)
        val encrypted = Base64.decode(record.getString("ciphertext"), Base64.NO_WRAP)
        if (iv.size != 12 || encrypted.size != 48) throw Unavailable()
        val wrappingKey = keyStore.getKey(alias, null) as? SecretKey ?: throw Unavailable()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, wrappingKey, GCMParameterSpec(128, iv))
        cipher.updateAAD(aad(project, uid, id))
        val bytes = cipher.doFinal(encrypted)
        if (bytes.size != 32) { bytes.fill(0); throw Unavailable() }
        return mapOf("key" to bytes, "databaseId" to id)
    }
}
