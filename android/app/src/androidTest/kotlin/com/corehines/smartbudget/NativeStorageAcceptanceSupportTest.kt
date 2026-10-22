package com.corehines.smartbudget

import android.content.Context
import android.database.DatabaseErrorHandler
import android.content.pm.ApplicationInfo
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.xmlpull.v1.XmlPullParser
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest

/** Explicitly invoked support for a single disposable Dart acceptance run.
 * No generic delete/reset endpoint is added to the application. */
@RunWith(AndroidJUnit4::class)
class NativeStorageAcceptanceSupportTest {
    private lateinit var context: Context
    private lateinit var root: File
    private lateinit var runId: String
    private lateinit var project: String
    private lateinit var registry: JSONObject
    private val users = listOf("a", "b", "missing", "corrupt", "expiry")
    @Before fun bindDisposableRun() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals("com.corehines.smartbudget", context.packageName)
        runId = InstrumentationRegistry.getArguments().getString("acceptanceRun") ?: ""
        assumeTrue("Explicit disposable acceptance run required", Regex("^[a-f0-9]{12}$").matches(runId))
        project = "native-acceptance-$runId"
        root = File(DatabaseKeyVault(context).rootPath())
        registry = JSONObject(File(root, "acceptance-$runId-registry.json").readText())
        assertEquals(runId, registry.getString("runId"))
        assertEquals(project, registry.getString("project"))
        assertEquals(users, (0 until registry.getJSONArray("users").length()).map { registry.getJSONArray("users").getString(it) })
        assertEquals("passed", JSONObject(File(root, "acceptance-$runId-prepare-result.json").readText()).getString("status"))
    }
    private fun scope(uid: String): String {
        assertTrue(users.contains(uid))
        return MessageDigest.getInstance("SHA-256").digest("$project\u0000$uid".toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 255) }
    }
    private fun folder(uid: String) = File(root, scope(uid)).also {
        assertEquals(it.absolutePath, it.canonicalPath)
        assertTrue(it.isDirectory)
    }
    private fun hash(file: File) = MessageDigest.getInstance("SHA-256").digest(file.readBytes())
    @Test fun backupExclusionsAndOrdinarySQLiteRejection() {
        assertEquals(0, context.applicationInfo.flags and ApplicationInfo.FLAG_ALLOW_BACKUP)
        assertEquals(File(context.noBackupFilesDir, "user_storage_v1").canonicalPath, root.canonicalPath)
        val resource = context.resources.getIdentifier("data_extraction_rules", "xml", context.packageName)
        assertTrue(resource != 0)
        val found = mutableSetOf<String>()
        val parser = context.resources.getXml(resource)
        var section = ""
        try {
            while (parser.eventType != XmlPullParser.END_DOCUMENT) {
                if (parser.eventType == XmlPullParser.START_TAG) {
                    if (parser.name in listOf("cloud-backup", "device-transfer")) section = parser.name
                    if (parser.name == "exclude" && parser.getAttributeValue(null, "path") == ".") {
                        found.add("$section:${parser.getAttributeValue(null, "domain")}")
                    }
                }
                parser.next()
            }
        } finally { parser.close() }
        for (kind in listOf("cloud-backup", "device-transfer")) {
            for (domain in listOf("root", "file", "database", "sharedpref", "external")) assertTrue(found.contains("$kind:$domain"))
        }
        for (uid in listOf("a", "b")) {
            val file = File(folder(uid), "financial.sqlite")
            val before = hash(file)
            var opened: SQLiteDatabase? = null
            var rejected = false
            try {
                opened = SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY,
                    DatabaseErrorHandler { /* Never run Android's default corruption deletion. */ })
                opened.rawQuery("SELECT count(*) FROM sqlite_master", null).use { it.moveToFirst() }
            } catch (_: SQLiteException) { rejected = true }
            finally { opened?.close() }
            assertTrue("Ordinary Android SQLite must reject the encrypted file", rejected)
            assertArrayEquals(before, hash(file))
        }
    }
    @Test fun removeOnlyDisposableMissingWrappingKey() {
        val file = File(folder("missing"), "financial.sqlite")
        val envelope = File(folder("missing"), "key.envelope.json")
        val record = JSONObject(envelope.readText())
        assertEquals(project, record.getString("projectId")); assertEquals("missing", record.getString("uid"))
        val before = hash(file); val envelopeBefore = hash(envelope)
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "smartbudget.db.wrap.v1.${scope("missing")}"
        assertTrue(store.containsAlias(alias))
        store.deleteEntry(alias) // Only this run's known disposable test key.
        assertFalse(store.containsAlias(alias))
        var rejected = false
        try { DatabaseKeyVault(context).load(project, "missing") } catch (_: Exception) { rejected = true }
        assertTrue(rejected)
        assertFalse(store.containsAlias(alias))
        assertArrayEquals(before, hash(file)); assertArrayEquals(envelopeBefore, hash(envelope))
    }
    @Test fun cleanupEarlierFailedDisposableRuns() {
        val supplied = InstrumentationRegistry.getArguments().getString("failedAcceptanceRuns") ?: ""
        val oldRuns = supplied.split(',').filter { it.isNotEmpty() }
        assertTrue(oldRuns.isNotEmpty() && oldRuns.size <= 20)
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        for (oldRun in oldRuns) {
            assertTrue(Regex("^[a-f0-9]{12}$").matches(oldRun))
            assertNotEquals(runId, oldRun)
            val oldProject = "native-acceptance-$oldRun"
            val oldRegistry = JSONObject(File(root, "acceptance-$oldRun-registry.json").readText())
            assertEquals(oldRun, oldRegistry.getString("runId"))
            assertEquals(oldProject, oldRegistry.getString("project"))
            val listed = oldRegistry.getJSONArray("users")
            assertEquals(users, (0 until listed.length()).map { listed.getString(it) })
            for (uid in users) {
                val id = MessageDigest.getInstance("SHA-256").digest("$oldProject\u0000$uid".toByteArray(Charsets.UTF_8))
                    .joinToString("") { "%02x".format(it.toInt() and 255) }
                val dir = File(root, id)
                if (dir.exists()) {
                    assertEquals(dir.absolutePath, dir.canonicalPath)
                    val envelope = File(dir, "key.envelope.json")
                    if (envelope.exists()) {
                        val record = JSONObject(envelope.readText())
                        assertEquals(oldProject, record.getString("projectId"))
                        assertEquals(uid, record.getString("uid"))
                    }
                    assertTrue(dir.deleteRecursively())
                }
                val alias = "smartbudget.db.wrap.v1.$id"
                if (store.containsAlias(alias)) store.deleteEntry(alias)
                assertFalse(dir.exists()); assertFalse(store.containsAlias(alias))
            }
        }
    }
    @Test fun confirmNoReplacementAndCleanupOnlyPassedDisposableRun() {
        assertEquals("passed", JSONObject(File(root, "acceptance-$runId-reopen-result.json").readText()).getString("status"))
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        assertFalse(store.containsAlias("smartbudget.db.wrap.v1.${scope("missing")}"))
        for (uid in users) {
            val dir = folder(uid)
            // Registry was exclusively created after verifying every scope absent.
            assertTrue(dir.deleteRecursively())
            val alias = "smartbudget.db.wrap.v1.${scope(uid)}"
            if (store.containsAlias(alias)) store.deleteEntry(alias)
            assertFalse(store.containsAlias(alias)); assertFalse(dir.exists())
        }
        // Keep only non-sensitive pass/fail evidence and one-way test fingerprints.
        File(root, "acceptance-$runId-cleaned").writeText("passed")
    }
}
