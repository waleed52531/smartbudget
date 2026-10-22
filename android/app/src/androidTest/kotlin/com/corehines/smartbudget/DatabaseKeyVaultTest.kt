package com.corehines.smartbudget

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.util.UUID
import android.system.Os

@RunWith(AndroidJUnit4::class)
class DatabaseKeyVaultTest {
    private lateinit var root: File
    private lateinit var prefix: String
    private lateinit var vault: DatabaseKeyVault
    private val project = "smartbudget-test"
    @Before fun prepare() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals("com.corehines.smartbudget", context.packageName)
        prefix = "smartbudget.test.${UUID.randomUUID()}."
        root = File(context.cacheDir, prefix).apply { mkdirs() }
        vault = DatabaseKeyVault(root, prefix)
    }
    @After fun cleanupOnlyThisTest() {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        store.aliases().toList().filter { it.startsWith(prefix) }.forEach { store.deleteEntry(it) }
        root.deleteRecursively()
    }
    private fun rejected(action: () -> Unit) {
        try { action(); fail("Expected fail-closed recovery condition") } catch (_: Exception) { }
    }
    private fun envelope(): File = root.walkTopDown().single { it.name == "key.envelope.json" }
    @Test fun canonicalParentAliasesWorkButLinkedVaultRootsAreRejected() {
        val parentAlias = File(root.parentFile, "${prefix}parent-link")
        val linkedRoot = File(root.parentFile, "${prefix}root-link")
        try {
            Os.symlink(root.parentFile!!.absolutePath, parentAlias.absolutePath)
            val throughParentAlias = File(parentAlias, root.name)
            val throughAlias = DatabaseKeyVault(throughParentAlias, prefix)
            assertEquals(root.canonicalPath, throughAlias.rootPath())
            val created = throughAlias.create(project, "alias-user")
            assertArrayEquals(created["key"] as ByteArray, vault.load(project, "alias-user")["key"] as ByteArray)
            Os.symlink(root.absolutePath, linkedRoot.absolutePath)
            rejected { DatabaseKeyVault(linkedRoot, prefix).rootPath() }
        } finally {
            if (parentAlias.exists()) parentAlias.delete()
            if (linkedRoot.exists()) linkedRoot.delete()
        }
    }
    @Test fun independentKeysReopenAndNonExportableWrappingKeys() {
        val a = vault.create(project, "a")
        val b = vault.create(project, "b")
        val reopened = DatabaseKeyVault(root, prefix).load(project, "a")
        assertArrayEquals(a["key"] as ByteArray, reopened["key"] as ByteArray)
        assertFalse((a["key"] as ByteArray).contentEquals(b["key"] as ByteArray))
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        store.aliases().toList().filter { it.startsWith(prefix) }.forEach {
            assertNull(store.getKey(it, null).encoded)
        }
        rejected { vault.create(project, "a") }
    }
    @Test fun tamperAndMissingAliasNeverRegenerateOrOverwrite() {
        vault.create(project, "a")
        val file = envelope()
        val record = JSONObject(file.readText()).put("databaseId", UUID.randomUUID().toString())
        file.writeText(record.toString())
        val tampered = file.readBytes()
        rejected { vault.load(project, "a") }
        assertArrayEquals(tampered, file.readBytes())
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        store.aliases().toList().filter { it.startsWith(prefix) }.forEach { store.deleteEntry(it) }
        rejected { vault.load(project, "a") }
        rejected { vault.create(project, "a") }
        assertArrayEquals(tampered, file.readBytes())
    }
    @Test fun orphanAliasMissingEnvelopeAndExistingDatabaseAreRecoveryConditions() {
        vault.create(project, "a")
        val file = envelope()
        file.delete() // Only this test's disposable envelope.
        assertTrue(vault.contains(project, "a"))
        rejected { vault.load(project, "a") }
        rejected { vault.create(project, "a") }
        File(file.parentFile, "financial.sqlite").writeBytes(byteArrayOf(1,2,3))
        rejected { vault.create(project, "a") }
    }
    @Test fun corruptEnvelopeAndWrongUserBindingFailClosed() {
        vault.create(project, "a")
        val file = envelope()
        file.writeText(JSONObject(file.readText()).put("uid", "b").toString())
        rejected { vault.load(project, "a") }
        file.writeText("invalid-envelope")
        rejected { vault.load(project, "a") }
        rejected { vault.load(project, "b") }
    }
}
