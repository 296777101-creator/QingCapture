import AppKit

final class PinnedScreenshot: NSObject, NSWindowDelegate {
    let window: NSPanel
    let image: CGImage
    var onClose: (() -> Void)?
    init(image: CGImage) {
        self.image = image
        let width = min(640, max(240, CGFloat(image.width) / 2))
        let height = min(560, max(160, width * CGFloat(image.height) / CGFloat(image.width)))
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height + 42), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        super.init(); window.title = "轻截贴图 · 可拖动与缩放"; window.delegate = self
        window.level = .floating; window.hidesOnDeactivate = false; window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; window.minSize = NSSize(width: 220, height: 150)
        window.isMovableByWindowBackground = true; window.center()
        let content = window.contentView!
        let view = NSImageView(frame: NSRect(x: 0, y: 42, width: width, height: height))
        view.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)); view.imageScaling = .scaleProportionallyUpOrDown
        view.autoresizingMask = [.width, .height]; content.addSubview(view)
        let copy = NSButton(title: "复制图片", target: self, action: #selector(copyImage)); copy.bezelStyle = .rounded; copy.frame = NSRect(x: 8, y: 6, width: 96, height: 30); content.addSubview(copy)
        let save = NSButton(title: "保存…", target: self, action: #selector(saveImage)); save.bezelStyle = .rounded; save.frame = NSRect(x: 108, y: 6, width: 80, height: 30); content.addSubview(save)
    }
    func show() { window.makeKeyAndOrderFront(nil) }
    @objc func copyImage() {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setData(data, forType: .png)
    }
    @objc func saveImage() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = "轻截贴图.png"
        if panel.runModal() == .OK, let url = panel.url, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            do { try data.write(to: url, options: .atomic) } catch { let alert = NSAlert(error: error); alert.runModal() }
        }
    }
    func windowWillClose(_ notification: Notification) { onClose?() }
}

final class OCRResultWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    let textView = NSTextView()
    var onTranslate: ((String) -> Void)?
    var onClose: (() -> Void)?
    init(text: String) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(); window.title = "文字识别 · 本机处理"; window.delegate = self; window.isReleasedWhenClosed = false; window.center()
        let scroll = NSScrollView(frame: NSRect(x: 18, y: 65, width: 584, height: 355)); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.autoresizingMask = [.width, .height]
        textView.frame = NSRect(x: 0, y: 0, width: 580, height: 350); textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true; textView.isHorizontallyResizable = false; textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 14, height: 14); textView.font = .systemFont(ofSize: 16)
        textView.string = text.isEmpty ? "未识别到文字，可以返回标注后重新选择区域。" : text
        textView.isRichText = false; scroll.documentView = textView; window.contentView?.addSubview(scroll)
        let copy = NSButton(title: "复制全部文字", target: self, action: #selector(copyText)); copy.frame = NSRect(x: 16, y: 16, width: 150, height: 34); copy.bezelStyle = .rounded; copy.isEnabled = !text.isEmpty; window.contentView?.addSubview(copy)
        let translate = NSButton(title: "翻译文字", target: self, action: #selector(translateText)); translate.frame = NSRect(x: 180, y: 16, width: 120, height: 34); translate.bezelStyle = .rounded; translate.isEnabled = !text.isEmpty; window.contentView?.addSubview(translate)
        let back = NSButton(title: "返回标注", target: self, action: #selector(back)); back.frame = NSRect(x: 460, y: 16, width: 145, height: 34); back.bezelStyle = .rounded; back.autoresizingMask = [.minXMargin]; window.contentView?.addSubview(back)
    }
    func show() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func copyText() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(textView.string, forType: .string) }
    @objc func translateText() {
        let range = textView.selectedRange()
        let text = range.length > 0 ? (textView.string as NSString).substring(with: range) : textView.string
        onTranslate?(text)
    }
    @objc func back() { window.close() }
    func windowWillClose(_ notification: Notification) { onClose?() }
}
