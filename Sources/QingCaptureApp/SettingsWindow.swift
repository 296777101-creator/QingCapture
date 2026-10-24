import AppKit
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

final class ShortcutRecorder: NSButton {
    var shortcut: ScreenshotShortcut = .standard { didSet { if !recording { title = shortcut.display + "  ·  点击修改" } } }
    private(set) var recording = false
    var onBegin: (() -> Void)?
    var onEnd: (() -> Void)?
    var onRecorded: ((ScreenshotShortcut) -> Void)?
    var onInvalid: ((String) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); bezelStyle = .rounded; target = self; action = #selector(beginRecording)
        font = .monospacedSystemFont(ofSize: 20, weight: .medium); setAccessibilityLabel("截图快捷键，点击后按下新组合键")
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func beginRecording() {
        guard !recording else { return }; recording = true; title = "请按下快捷键…（Esc 取消）"
        onBegin?(); window?.makeFirstResponder(self)
    }
    func stop() { guard recording else { return }; recording = false; title = shortcut.display + "  ·  点击修改"; onEnd?() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }; return super.performKeyEquivalent(with: event)
    }
    override func resignFirstResponder() -> Bool { stop(); return super.resignFirstResponder() }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { stop(); return }
        let candidate = ScreenshotShortcut(keyCode: UInt32(event.keyCode), modifiers: event.modifierFlags.rawValue)
        guard candidate.isValid else { onInvalid?("这个组合不适合作为截图快捷键，请换一组。比如 Control + Shift + S。"); return }
        shortcut = candidate; stop(); onRecorded?(candidate)
    }
}

final class SettingsWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    let manager: HotKeyManager
    let recorder = ShortcutRecorder(frame: NSRect(x: 34, y: 210, width: 492, height: 48))
    let status = NSTextField(wrappingLabelWithString: "")
    let saveButton = NSButton(title: "保存快捷键", target: nil, action: nil)
    var onSaved: (() -> Void)?
    init(manager: HotKeyManager) {
        self.manager = manager
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(); window.title = "轻截设置"; window.delegate = self; window.isReleasedWhenClosed = false; window.center()
        let view = window.contentView!
        func label(_ text: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular) {
            let field = NSTextField(wrappingLabelWithString: text); field.frame = rect; field.font = .systemFont(ofSize: size, weight: weight); view.addSubview(field)
        }
        label("全局截图快捷键", rect: NSRect(x: 34, y: 280, width: 490, height: 38), size: 23, weight: .semibold)
        label("点击下面的按钮，再按下你想使用的组合键。", rect: NSRect(x: 34, y: 250, width: 490, height: 30), size: 13)
        recorder.shortcut = manager.current
        recorder.onBegin = { [weak manager] in manager?.suspend() }
        recorder.onEnd = { [weak self] in
            guard let self else { return }; self.manager.resume(); self.onSaved?()
            if let error = self.manager.error { self.message(error, error: true) }
        }
        recorder.onRecorded = { [weak self] shortcut in self?.message("准备使用 \(shortcut.display)，点击保存后生效。", error: false) }
        recorder.onInvalid = { [weak self] message in self?.message(message, error: true) }
        view.addSubview(recorder)
        status.frame = NSRect(x: 34, y: 130, width: 490, height: 66); status.font = .systemFont(ofSize: 13); view.addSubview(status)
        let reset = NSButton(title: "恢复默认 ⌃⌥A", target: self, action: #selector(resetShortcut)); reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 30, y: 65, width: 180, height: 36); view.addSubview(reset)
        saveButton.target = self; saveButton.action = #selector(saveShortcut); saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 352, y: 65, width: 180, height: 36); view.addSubview(saveButton)
        label("快捷键会自动保存，重启后仍有效。冲突时会保留原设置。", rect: NSRect(x: 34, y: 13, width: 490, height: 32), size: 12)
    }
    func message(_ text: String, error: Bool) { status.stringValue = text; status.textColor = error ? .systemRed : .secondaryLabelColor }
    func show() {
        recorder.shortcut = manager.current
        message(manager.isRegistered ? "当前使用 \(manager.current.display)，可从任意应用唤起截图。" : (manager.error ?? "快捷键未注册，请选择新的组合。"), error: !manager.isRegistered)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func saveShortcut() {
        recorder.stop()
        if let error = manager.update(recorder.shortcut) { message(error, error: true) }
        else { message("已保存：\(manager.current.display)。可以切换到其他应用后试用。", error: false); onSaved?() }
    }
    @objc func resetShortcut() { recorder.stop(); recorder.shortcut = .standard; saveShortcut() }
    func windowDidResignKey(_ notification: Notification) { recorder.stop() }
    func windowWillClose(_ notification: Notification) { recorder.stop() }
}
