import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(name: "com.corehines.smartbudget/database_keys",
                                      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "root" else { result(FlutterMethodNotImplemented); return }
      do {
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
          in: .userDomainMask, appropriateFor: nil, create: true)
        // macOS Application Support is shared; retain the existing bundle namespace.
        guard let bundleId = Bundle.main.bundleIdentifier else { throw CocoaError(.fileNoSuchFile) }
        var root = support.appendingPathComponent(bundleId, isDirectory: true)
          .appendingPathComponent("user_storage_v1", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        result(root.path)
      } catch {
        result(FlutterError(code: "database-key-unavailable",
          message: "Protected storage unavailable.", details: nil))
      }
    }


    super.awakeFromNib()
  }
}
