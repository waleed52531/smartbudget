import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "SmartBudgetDatabaseStorage") {
      let channel = FlutterMethodChannel(name: "com.corehines.smartbudget/database_keys",
                                        binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "root" else { result(FlutterMethodNotImplemented); return }
        do {
          let support = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
          var root = support.appendingPathComponent("user_storage_v1", isDirectory: true)
          try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
          try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
            ofItemAtPath: root.path)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try root.setResourceValues(values)
          result(root.path)
        } catch {
          result(FlutterError(code: "database-key-unavailable",
            message: "Protected storage unavailable.", details: nil))
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
