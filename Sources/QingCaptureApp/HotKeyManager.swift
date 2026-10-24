import AppKit
import Carbon
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

final class HotKeyManager {
    private var handler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var monitor: Any?
    private var sequence: UInt32 = 0
    private var activeID: UInt32 = 0
    private let signature: OSType = 0x51434150
    let defaults: UserDefaults
    private(set) var current: ScreenshotShortcut
    private(set) var error: String?
    private(set) var suspended = false
    var onTrigger: (() -> Void)?
    var isRegistered: Bool { hotKey != nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults; current = ShortcutStore.load(from: defaults)
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == manager.signature, identifier.id == manager.activeID, !manager.suspended else { return OSStatus(eventNotHandledErr) }
            manager.onTrigger?(); return noErr
        }
        let status = InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        if status != noErr { error = "无法安装快捷键监听（\(status)），请重新打开轻截。" }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.suspended, self.isRegistered, !event.isARepeat, self.current.matches(event) else { return event }
            self.onTrigger?(); return nil
        }
    }

    @discardableResult func update(_ proposal: ScreenshotShortcut, persist: Bool = true) -> String? {
        guard proposal.isValid else { return "请使用 Control、Option 或 Command 加普通按键；避开系统截图及常用编辑快捷键。" }
        guard handler != nil else { return error ?? "快捷键监听未启动。" }
        if proposal == current, hotKey != nil { return nil }
        sequence &+= 1
        var candidate: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: signature, id: sequence)
        let status = RegisterEventHotKey(proposal.keyCode, proposal.carbonModifiers, identifier, GetEventDispatcherTarget(), OptionBits(kEventHotKeyExclusive), &candidate)
        guard status == noErr, let candidate else {
            let message = "\(proposal.display) 已被系统或其他应用占用（\(status)）。请选择其他组合；原快捷键保持有效。"
            error = message; return message
        }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = candidate; activeID = sequence; current = proposal; error = nil; suspended = false
        if persist { ShortcutStore.save(proposal, to: defaults) }
        return nil
    }
    func suspend() { suspended = true; if let hotKey { UnregisterEventHotKey(hotKey) }; hotKey = nil }
    func resume() { suspended = false; _ = update(current, persist: false) }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
