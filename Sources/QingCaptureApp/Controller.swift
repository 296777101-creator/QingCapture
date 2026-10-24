import AppKit
import Carbon
import ScreenCaptureKit
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

final class CaptureWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class CaptureController: NSObject, NSWindowDelegate {
    var windows: [CaptureWindow] = []
    var canvases: [CaptureCanvas] = []
    var toolbar: CaptureToolbar?
    var welcome: NSWindow?
    var permissionLabel: NSTextField?
    var statusItem: NSStatusItem!
    let hotKeys: HotKeyManager = {
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") { return HotKeyManager(defaults: IntegrationChecks.preferences()) }
        return HotKeyManager()
    }()
    var hotKeyRegistered: Bool { hotKeys.isRegistered }
    var settings: SettingsWindow?
    var shortcutLabel: NSTextField?
    var captureMenuItem: NSMenuItem?
    var pinnedWindows: [PinnedScreenshot] = []
    var ocrWindow: OCRResultWindow?
    var translationWindow: TranslationWindow?
    var scrollSession: ScrollCaptureSession?
    var busy = false
    var previousApp: NSRunningApplication?
    var toast: NSPanel?
    var onCaptureReady: (() -> Void)?
    var savePanelDriver: ((NSSavePanel) -> Void)?

    func launch() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "crop", accessibilityDescription: "轻截")
        let menu = NSMenu()
        captureMenuItem = addItem(menu, "开始截图", #selector(startCapture))
        addItem(menu, "打开轻截", #selector(showWelcome))
        addItem(menu, "设置快捷键…", #selector(showSettings))
        menu.addItem(.separator())
        addItem(menu, "屏幕录制权限…", #selector(openPrivacy))
        addItem(menu, "使用说明", #selector(showHelp))
        menu.addItem(.separator())
        addItem(menu, "退出轻截", #selector(quit))
        statusItem.menu = menu
        hotKeys.onTrigger = { [weak self] in self?.startCapture() }
        _ = hotKeys.update(hotKeys.current, persist: false)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(reopenExisting), name: Notification.Name("local.qingcapture.reopen"), object: nil)
        refreshShortcutUI()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshPermission), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        showWelcome()
    }

    @discardableResult private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; menu.addItem(item); return item
    }

    @objc func showWelcome() {
        if welcome == nil { makeWelcome() }
        refreshPermission()
        NSApp.activate(ignoringOtherApps: true)
        welcome?.makeKeyAndOrderFront(nil)
    }

    private func makeWelcome() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 500), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "轻截"; window.isReleasedWhenClosed = false; window.center()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 500))
        view.wantsLayer = true; view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        window.contentView = view
        func label(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
            let label = NSTextField(wrappingLabelWithString: text)
            label.frame = NSRect(x: x, y: y, width: width, height: 52)
            label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
            view.addSubview(label); return label
        }
        let icon = NSImageView(frame: NSRect(x: 42, y: 398, width: 48, height: 48))
        icon.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: nil)
        icon.contentTintColor = .systemGreen; view.addSubview(icon)
        _ = label("轻截", x: 104, y: 396, width: 390, size: 34, weight: .bold)
        _ = label("框选一瞬间，表达更清楚。", x: 44, y: 348, width: 460, size: 17, color: .secondaryLabelColor)
        let shortcut = hotKeyRegistered ? hotKeys.current.display + "  ·  全局截图快捷键" : "快捷键未生效，请打开设置重新选择"
        shortcutLabel = label(shortcut, x: 44, y: 292, width: 470, size: 19, weight: .medium)
        _ = label("拖框选区 → 标注 → Enter 复制\n形状 · 荧光笔 · 序号 · 文字 · 马赛克 · 贴图 · OCR", x: 44, y: 221, width: 470, size: 15, color: .secondaryLabelColor)
        permissionLabel = label("", x: 44, y: 146, width: 470, size: 13, color: .secondaryLabelColor)
        let start = NSButton(title: "开始截图", target: self, action: #selector(startCapture))
        start.frame = NSRect(x: 40, y: 78, width: 160, height: 40); start.bezelStyle = .rounded
        start.keyEquivalent = "\r"; view.addSubview(start)
        let privacy = NSButton(title: "屏幕录制授权…", target: self, action: #selector(openPrivacy))
        privacy.frame = NSRect(x: 216, y: 78, width: 180, height: 40); privacy.bezelStyle = .rounded; view.addSubview(privacy)
        let settingsButton = NSButton(title: "快捷键设置…", target: self, action: #selector(showSettings))
        settingsButton.frame = NSRect(x: 402, y: 78, width: 135, height: 40); settingsButton.bezelStyle = .rounded; view.addSubview(settingsButton)
        _ = label("关闭此窗口后，轻截仍在顶部菜单栏运行。截图仅在本机处理。", x: 44, y: 12, width: 480, size: 12, color: .tertiaryLabelColor)
        welcome = window
    }

    @objc func refreshPermission() {
        permissionLabel?.stringValue = CGPreflightScreenCaptureAccess()
            ? "✓ 屏幕录制权限已开启，可以开始截图。"
            : "首次使用：在系统设置中允许「轻截」录制屏幕。\n授权后若仍提示未开启，请退出轻截再重新打开。"
    }

    @objc func openPrivacy() {
        if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
    }

    @objc func showHelp() {
        let alert = NSAlert(); alert.messageText = "轻截 · 使用说明"
        alert.informativeText = "\(hotKeys.current.display)：开始截图\n拖动：选择区域；拖角点：调整大小\n选区工具：移动选区；在外侧拖动可重选\n矩形 / 椭圆 / 单双箭头 / 直线 / 画笔 / 荧光笔 / 文字 / 马赛克 / 模糊 / 序号 / 橡皮擦\n颜色圆点：直接选色；加号：自定义颜色；下拉框：线宽、字号、形状、箭头与马赛克强度\n⌘Z：撤销；⇧⌘Z：重做\nEnter 或 ⌘C：复制；⌘S：保存 PNG\nEsc / 鼠标右键：取消\n\n文字 Shift+Enter 换行，Enter 确认；再次 Enter 复制。\n工具栏支持识别文字、贴图置顶、全屏选区及可撤销的清空。\n设置中可以录制和保存你自己的全局截图快捷键。\n多屏幕可在任意一块屏幕选区，暂不支持跨屏拼接。"
        alert.addButton(withTitle: "知道了"); NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }

    @objc func startCapture() {
        settings?.recorder.stop()
        if let scrollSession { scrollSession.show(); return }
        guard !busy else { return }
        if let modal = NSApp.modalWindow { modal.makeKeyAndOrderFront(nil); return }
        if !windows.isEmpty {
            NSApp.activate(ignoringOtherApps: true)
            if let result = translationWindow { result.show() }
            else if let result = ocrWindow { result.show() }
            else if let canvas = canvases.first { restore(canvas) }
            return
        }
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess(); showWelcome(); return
        }
        previousApp = NSWorkspace.shared.frontmostApplication
        settings?.window.orderOut(nil); welcome?.close(); toast?.orderOut(nil); busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                var captured: [(NSScreen, CGImage)] = []
                for screen in NSScreen.screens {
                    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                          let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { continue }
                    let filter = SCContentFilter(display: display, excludingWindows: [])
                    let config = SCStreamConfiguration()
                    let scale = CGFloat(filter.pointPixelScale)
                    config.width = Int(screen.frame.width * scale); config.height = Int(screen.frame.height * scale)
                    config.showsCursor = false; config.captureResolution = .best
                    config.pixelFormat = kCVPixelFormatType_32BGRA
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    captured.append((screen, image))
                }
                guard !captured.isEmpty else { throw CaptureError.noDisplay }
                present(captured)
            } catch {
                cancel(restore: false); showWelcome()
                let alert = NSAlert(); alert.messageText = "暂时无法截图"
                alert.informativeText = "请检查屏幕录制权限，然后重试。\n\(error.localizedDescription)"
                alert.addButton(withTitle: "知道了"); alert.runModal()
            }
        }
    }

    func present(_ captures: [(NSScreen, CGImage)]) {
        for (screen, image) in captures {
            let window = CaptureWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.title = "轻截 · 截图"
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
            window.backgroundColor = .clear; window.isOpaque = true; window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]; window.isReleasedWhenClosed = false
            let canvas = CaptureCanvas(frame: NSRect(origin: .zero, size: screen.frame.size), image: image, controller: self)
            window.contentView = canvas; windows.append(window); canvases.append(canvas); window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        let mouse = NSEvent.mouseLocation
        let target = windows.first(where: { $0.frame.contains(mouse) }) ?? windows.first
        target?.makeKey(); target?.makeFirstResponder(target?.contentView); NSCursor.crosshair.set()
        onCaptureReady?()
    }

    func selected(_ canvas: CaptureCanvas) {
        for other in canvases where other !== canvas { other.window?.orderOut(nil) }
        if toolbar == nil || toolbar?.canvas !== canvas { toolbar?.close(); toolbar = CaptureToolbar(canvas: canvas, controller: self) }
        positionToolbar(canvas)
    }

    func positionToolbar(_ canvas: CaptureCanvas) {
        guard let selection = canvas.selection, let window = canvas.window, let toolbar else { return }
        if canvas.enclosingScrollView != nil {
            let rect = window.convertToScreen(NSRect(x: max(12, (window.contentView!.bounds.width - toolbar.frame.width) / 2), y: 10, width: min(toolbar.frame.width, window.contentView!.bounds.width - 24), height: toolbar.frame.height))
            toolbar.setFrame(rect, display: true)
            if toolbar.parent == nil { window.addChildWindow(toolbar, ordered: .above) }
            toolbar.orderFrontRegardless(); toolbar.refresh(); return
        }
        let global = selection.offsetBy(dx: window.frame.minX, dy: window.frame.minY)
        let margin: CGFloat = 12, width = min(toolbar.frame.width, window.frame.width - 24)
        let x = min(max(global.maxX - width, window.frame.minX + margin), window.frame.maxX - width - margin)
        let below = global.minY - toolbar.frame.height - 12
        let y = below >= window.frame.minY + margin ? below : min(global.maxY + 12, window.frame.maxY - toolbar.frame.height - margin)
        toolbar.setFrame(NSRect(x: x, y: y, width: width, height: toolbar.frame.height), display: true)
        if toolbar.parent == nil { window.addChildWindow(toolbar, ordered: .above) }
        toolbar.orderFrontRegardless(); toolbar.refresh()
    }

    func output(_ canvas: CaptureCanvas) -> CGImage? {
        canvas.commitText(); guard let selection = canvas.selection else { return nil }
        return ScreenshotRenderer.render(image: canvas.image, canvasSize: canvas.bounds.size, selection: selection, annotations: canvas.history.items)
    }

    func copy(_ canvas: CaptureCanvas) {
        guard let image = output(canvas), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        let pasteboard = NSPasteboard.general, item = NSPasteboardItem()
        item.setData(data, forType: .png)
        if let tiff = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)).tiffRepresentation { item.setData(tiff, forType: .tiff) }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { showError("未能复制图片，请尝试保存到文件。"); return }
        cancel(); showToast("已复制，可直接粘贴")
    }

    func save(_ canvas: CaptureCanvas) {
        guard let image = output(canvas), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]; panel.canCreateDirectories = true
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        panel.nameFieldStringValue = "轻截 \(formatter.string(from: Date())).png"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        toolbar?.orderOut(nil); windows.forEach { $0.orderOut(nil) }
        if let savePanelDriver {
            let timer = Timer(timeInterval: 0.2, repeats: false) { _ in savePanelDriver(panel) }
            RunLoop.main.add(timer, forMode: .modalPanel)
        }
        if panel.runModal() == .OK, let url = panel.url {
            do { try data.write(to: url, options: .atomic); cancel(); showToast("截图已保存") }
            catch { showError("保存失败：\(error.localizedDescription)"); restore(canvas) }
        } else { restore(canvas) }
    }

    private func restore(_ canvas: CaptureCanvas) { canvas.window?.makeKeyAndOrderFront(nil); canvas.window?.makeFirstResponder(canvas); positionToolbar(canvas) }
    func cancel(restore: Bool = true) {
        scrollSession?.shutdown(); scrollSession = nil
        translationWindow?.onClose = nil; translationWindow?.window.close(); translationWindow = nil
        ocrWindow?.onClose = nil; ocrWindow?.window.close(); ocrWindow = nil
        if let toolbar, let parent = toolbar.parent { parent.removeChildWindow(toolbar) }
        NSColorPanel.shared.orderOut(nil)
        toolbar?.close(); toolbar = nil
        let closing = windows; windows.removeAll(); canvases.removeAll()
        closing.forEach { $0.orderOut(nil); $0.close() }; NSCursor.arrow.set()
        if restore, let previousApp, previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp.activate() }
        previousApp = nil
    }
    func showError(_ message: String) { let alert = NSAlert(); alert.messageText = message; alert.addButton(withTitle: "知道了"); alert.runModal() }
    func showToast(_ message: String) {
        toast?.close()
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 54), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.84); panel.isOpaque = false; panel.hasShadow = true; panel.level = .floating
        panel.contentView?.wantsLayer = true; panel.contentView?.layer?.cornerRadius = 12; panel.contentView?.layer?.masksToBounds = true
        let label = NSTextField(labelWithString: "✓  \(message)"); label.textColor = .white; label.alignment = .center
        label.frame = NSRect(x: 10, y: 17, width: 240, height: 22); panel.contentView?.addSubview(label)
        panel.center(); panel.orderFrontRegardless(); toast = panel
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak panel] in panel?.orderOut(nil) }
    }
    @objc func screenChanged() { if !windows.isEmpty { cancel(); showToast("屏幕已变化，请重新截图") } }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func reopenExisting() {
        if let scrollSession { scrollSession.show(); return }
        if let translationWindow { translationWindow.show(); return }
        if let ocrWindow { ocrWindow.show(); return }
        if settings?.window.isVisible == true { settings?.window.makeKeyAndOrderFront(nil); return }
        if let window = windows.first(where: { $0.isVisible }) { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
        else { showWelcome() }
    }
    @objc func showSettings() {
        if settings == nil {
            settings = SettingsWindow(manager: hotKeys)
            settings?.onSaved = { [weak self] in self?.refreshShortcutUI() }
        }
        settings?.show()
    }
    func refreshShortcutUI() {
        captureMenuItem?.title = "开始截图    " + (hotKeys.isRegistered ? hotKeys.current.display : "快捷键未注册")
        shortcutLabel?.stringValue = hotKeys.isRegistered ? hotKeys.current.display + "  ·  全局截图快捷键" : "快捷键未生效，请打开设置重新选择"
    }
    func pin(_ canvas: CaptureCanvas) {
        guard let image = output(canvas) else { return }; cancel()
        let pinned = PinnedScreenshot(image: image)
        pinned.onClose = { [weak self, weak pinned] in self?.pinnedWindows.removeAll { $0 === pinned } }
        pinnedWindows.append(pinned); pinned.show()
    }
    func recognize(_ canvas: CaptureCanvas, translate: Bool = false) {
        guard let image = output(canvas), toolbar?.recognizing != true else { return }
        toolbar?.recognizing = true; toolbar?.refresh()
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak canvas] in
            let result = Result { try TextRecognition.recognize(image: image) }
            DispatchQueue.main.async {
                guard let self, let canvas, self.canvases.contains(where: { $0 === canvas }) else { return }
                self.toolbar?.recognizing = false; self.toolbar?.refresh()
                switch result {
                case .success(let text):
                    self.toolbar?.orderOut(nil); self.windows.forEach { $0.orderOut(nil) }
                    if translate {
                        self.showTranslation(text: text, returnTo: canvas); return
                    }
                    self.ocrWindow = OCRResultWindow(text: text)
                    self.ocrWindow?.onTranslate = { [weak self, weak canvas] text in
                        guard let self, let canvas else { return }
                        self.ocrWindow?.window.orderOut(nil); self.showTranslation(text: text, returnTo: canvas, returnToOCR: true)
                    }
                    self.ocrWindow?.onClose = { [weak self, weak canvas] in
                        if let self, let canvas, self.canvases.contains(where: { $0 === canvas }) { self.restore(canvas) }
                        self?.ocrWindow = nil
                    }
                    self.ocrWindow?.show()
                case .failure(let error):
                    self.toolbar?.orderOut(nil); self.windows.forEach { $0.orderOut(nil) }
                    self.showError("文字识别失败：\(error.localizedDescription)"); self.restore(canvas)
                }
            }
        }
    }
    func showTranslation(text: String, returnTo canvas: CaptureCanvas? = nil, returnToOCR: Bool = false) {
        translationWindow?.onClose = nil; translationWindow?.window.close()
        translationWindow = TranslationWindow(text: text)
        translationWindow?.onClose = { [weak self, weak canvas] in
            guard let self else { return }; self.translationWindow = nil
            if returnToOCR, let result = self.ocrWindow { result.show() }
            else if let canvas, self.canvases.contains(where: { $0 === canvas }) { self.restore(canvas) }
        }
        translationWindow?.show()
    }
    func startScrolling(_ canvas: CaptureCanvas) {
        guard scrollSession == nil, let selection = canvas.selection, let screen = canvas.window?.screen, canvas.enclosingScrollView == nil else { return }
        canvas.commitText(); toolbar?.orderOut(nil); windows.forEach { $0.orderOut(nil) }
        let session = ScrollCaptureSession(screen: screen, region: selection)
        session.onCancel = { [weak self, weak canvas] in
            self?.scrollSession = nil
            if let self, let canvas, self.canvases.contains(where: { $0 === canvas }) { self.restore(canvas) }
        }
        session.onFinish = { [weak self] image in
            guard let self else { return }; self.scrollSession = nil; self.cancel(restore: false); self.presentLongImage(image, screen: screen)
        }
        scrollSession = session; session.start()
        previousApp?.activate()
    }
    func presentLongImage(_ image: CGImage, screen: NSScreen? = nil) {
        let display = screen ?? NSScreen.main!
        let size = CGSize(width: min(980, display.visibleFrame.width - 32), height: min(780, display.visibleFrame.height - 48))
        let window = CaptureWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "轻截 · 长截图标注"; window.isReleasedWhenClosed = false; window.delegate = self; window.minSize = NSSize(width: 680, height: 450)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow))); window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 180, width: size.width, height: size.height - 180))
        scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let scale = display.backingScaleFactor
        let canvas = CaptureCanvas(frame: NSRect(x: 0, y: 0, width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale), image: image, controller: self)
        canvas.selection = canvas.bounds; scroll.documentView = canvas; window.contentView?.addSubview(scroll)
        windows.append(window); canvases.append(canvas); window.center(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(canvas)
        scroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, canvas.bounds.height - scroll.contentView.bounds.height))); scroll.reflectScrolledClipView(scroll.contentView)
        selected(canvas)
    }
    func windowDidMove(_ notification: Notification) { if let canvas = canvases.first(where: { $0.enclosingScrollView != nil }) { positionToolbar(canvas) } }
    func windowDidResize(_ notification: Notification) { windowDidMove(notification) }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if windows.contains(where: { $0 === sender }) { cancel(); return false }; return true
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, windows.contains(where: { $0 === window }) else { return }; cancel()
    }
    enum CaptureError: LocalizedError { case noDisplay; var errorDescription: String? { "没有找到可截图的显示器。" } }
}
