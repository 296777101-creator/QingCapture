import AppKit
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = CaptureController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem(); mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(); appMenuItem.submenu = appMenu
        let preferences = NSMenuItem(title: "设置快捷键…", action: #selector(CaptureController.showSettings), keyEquivalent: ",")
        preferences.target = controller; appMenu.addItem(preferences); appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "退出轻截", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appMenu.addItem(quit)
        let editItem = NSMenuItem(); mainMenu.addItem(editItem)
        let edit = NSMenu(title: "编辑"); editItem.submenu = edit
        edit.addItem(NSMenuItem(title: "撤销", action: #selector(CaptureCanvas.undo(_:)), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "重做", action: #selector(CaptureCanvas.redo(_:)), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]; edit.addItem(redo); edit.addItem(.separator())
        for (title, selector, key) in [("剪切", #selector(NSText.cut(_:)), "x"), ("复制", #selector(NSText.copy(_:)), "c"), ("粘贴", #selector(NSText.paste(_:)), "v"), ("全选", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(NSMenuItem(title: title, action: selector, keyEquivalent: key))
        }
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "保存截图…", action: #selector(CaptureCanvas.saveDocument(_:)), keyEquivalent: "s"))
        NSApp.mainMenu = mainMenu
        controller.launch()
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--smoke-test"), arguments.count > index + 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                IntegrationChecks.run(controller: self.controller, output: arguments[index + 1])
                NSApp.terminate(nil)
            }
        } else if let index = arguments.firstIndex(of: "--capture-test"), arguments.count > index + 1 {
            let output = arguments[index + 1]
            controller.onCaptureReady = {
                let results = self.controller.canvases.map { canvas -> [String: Any] in
                    canvas.selection = CGRect(x: 20, y: 20, width: min(300, canvas.bounds.width - 40), height: min(200, canvas.bounds.height - 40))
                    let image = self.controller.output(canvas)
                    return ["screenWidthPoints": canvas.bounds.width, "screenHeightPoints": canvas.bounds.height, "capturedWidthPixels": canvas.image.width, "capturedHeightPixels": canvas.image.height, "cropWidthPixels": image?.width ?? 0, "cropHeightPixels": image?.height ?? 0]
                }
                let report: [String: Any] = ["captured": !results.isEmpty, "screens": results]
                if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: output)) }
                self.controller.cancel(restore: false); NSApp.terminate(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard CGPreflightScreenCaptureAccess() else {
                    try? Data("{\"captured\":false,\"reason\":\"permission-required\"}".utf8).write(to: URL(fileURLWithPath: output))
                    NSApp.terminate(nil); return
                }
                self.controller.startCapture()
            }
        } else if arguments.contains("--translation-demo") {
            controller.welcome?.close(); controller.showTranslation(text: "Hello! Welcome to QingCapture. This screenshot tool helps you capture long pages and translate text on your Mac.")
        } else if arguments.contains("--demo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Demo.show(controller: self.controller) }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.reopenExisting()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let singleInstance = SingleInstanceLock()
let isDiagnostic = ProcessInfo.processInfo.arguments.contains("--smoke-test") || ProcessInfo.processInfo.arguments.contains("--capture-test")
if !isDiagnostic {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("QingCapture/instance.lock")
    if !singleInstance.acquire(at: support) {
        DistributedNotificationCenter.default().postNotificationName(Notification.Name("local.qingcapture.reopen"), object: nil, userInfo: nil, deliverImmediately: true)
        exit(0)
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
