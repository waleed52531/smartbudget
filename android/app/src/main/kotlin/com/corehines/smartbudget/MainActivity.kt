package com.corehines.smartbudget

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.SystemClock
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private fun returnDatabaseKey(result: MethodChannel.Result, record: Map<String, Any>) {
        try { result.success(record) } finally { (record["key"] as? ByteArray)?.fill(0) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val databaseKeys by lazy { DatabaseKeyVault(applicationContext) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.corehines.smartbudget/database_keys").setMethodCallHandler { call, result ->
            try {
                if (call.method == "root") {
                    result.success(databaseKeys.rootPath())
                } else {
                    val project = call.argument<String>("projectId") ?: throw DatabaseKeyVault.Unavailable()
                    val uid = call.argument<String>("uid") ?: throw DatabaseKeyVault.Unavailable()
                    when (call.method) {
                        "contains" -> result.success(databaseKeys.contains(project, uid))
                        "create" -> returnDatabaseKey(result, databaseKeys.create(project, uid))
                        "load" -> returnDatabaseKey(result, databaseKeys.load(project, uid))
                        "syncDirectory" -> result.success(databaseKeys.syncDirectory(project, uid))
                        else -> result.notImplemented()
                    }
                }
            } catch (_: Exception) {
                // Do not send provider errors, key bytes or envelope contents to Dart/logcat.
                result.error("database-key-unavailable", "Protected database key unavailable.", null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.corehines.smartbudget/session_clock").setMethodCallHandler { call, result ->
            if (call.method != "snapshot") {
                result.notImplemented()
            } else {
                val bootCount = Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1)
                if (bootCount < 0) {
                    result.error("clock-unavailable", "Trusted session clock unavailable.", null)
                } else {
                    result.success(mapOf("wallMs" to System.currentTimeMillis(),
                        "elapsedMs" to SystemClock.elapsedRealtime(), "bootId" to bootCount.toString()))
                }
            }
        }
    }
}
