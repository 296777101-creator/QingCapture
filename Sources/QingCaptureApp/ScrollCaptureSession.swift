import AppKit
import ScreenCaptureKit
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

private final class ScrollBorder: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemGreen.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1)); path.lineWidth = 2; path.stroke()
    }
}

/// Captures without injecting scroll events or asking for Accessibility permission.
final class ScrollCaptureSession: NSObject, NSWindowDelegate {
    let panel: NSPanel
    let border: NSWindow
    let stitcher = VerticalStitcher()
    private let screen: NSScreen
    private let region: CGRect
    private let status = NSTextField(wrappingLabelWithString: "准备捕获，请在绿色框内向下滚动…")
    private let pauseButton = NSButton(title: "暂停", target: nil, action: nil)
    private var timer: Timer?
    private var filter: SCContentFilter?
    private var config: SCStreamConfiguration?
    private var sampling = false
    private(set) var stopped = false
    private(set) var paused = false
    private var finishing = false
    private var failures = 0
    var onFinish: ((CGImage) -> Void)?
    var onCancel: (() -> Void)?

    init(screen: NSScreen, region: CGRect) {
        self.screen = screen; self.region = region
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 510, height: 138), styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        let global = region.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY)
        border = NSWindow(contentRect: global.insetBy(dx: -2, dy: -2), styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        border.isOpaque = false; border.backgroundColor = .clear; border.ignoresMouseEvents = true; border.hasShadow = false
        border.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        border.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        border.contentView = ScrollBorder(frame: NSRect(origin: .zero, size: border.frame.size)); border.isReleasedWhenClosed = false
        panel.title = "滚动长截图 · 在原应用中慢慢向下滚动"; panel.isReleasedWhenClosed = false; panel.delegate = self
        panel.hidesOnDeactivate = false; panel.isFloatingPanel = true; panel.level = NSWindow.Level(rawValue: border.level.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        status.frame = NSRect(x: 16, y: 69, width: 478, height: 48); status.font = .systemFont(ofSize: 13); panel.contentView?.addSubview(status)
        pauseButton.target = self; pauseButton.action = #selector(togglePause); pauseButton.frame = NSRect(x: 12, y: 19, width: 90, height: 34); pauseButton.bezelStyle = .rounded; panel.contentView?.addSubview(pauseButton)
        let capture = NSButton(title: "捕获一段", target: self, action: #selector(captureNow)); capture.frame = NSRect(x: 108, y: 19, width: 110, height: 34); capture.bezelStyle = .rounded; panel.contentView?.addSubview(capture)
        let finish = NSButton(title: "完成长截图", target: self, action: #selector(finish)); finish.frame = NSRect(x: 230, y: 19, width: 140, height: 34); finish.bezelStyle = .rounded; panel.contentView?.addSubview(finish)
        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel)); cancel.frame = NSRect(x: 386, y: 19, width: 100, height: 34); cancel.bezelStyle = .rounded; panel.contentView?.addSubview(cancel)
        let x = min(max(global.midX - 255, screen.visibleFrame.minX + 10), screen.visibleFrame.maxX - 520)
        let y = global.minY - 175 >= screen.visibleFrame.minY ? global.minY - 175 : screen.visibleFrame.maxY - 175
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func start() {
        border.orderFrontRegardless(); panel.orderFrontRegardless()
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard !stopped, let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                      let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { return }
                let apps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
                let filter = SCContentFilter(display: display, excludingApplications: apps, exceptingWindows: [])
                let config = SCStreamConfiguration(); config.width = Int(screen.frame.width * CGFloat(filter.pointPixelScale)); config.height = Int(screen.frame.height * CGFloat(filter.pointPixelScale))
                config.showsCursor = false; config.captureResolution = .best; config.pixelFormat = kCVPixelFormatType_32BGRA
                self.filter = filter; self.config = config
                captureNow()
                armTimer()
            } catch { status.stringValue = "无法捕获：\(error.localizedDescription)。请取消后重试。" }
        }
    }

    private func armTimer() {
        timer?.invalidate(); timer = Timer.scheduledTimer(timeInterval: 0.55, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
    }
    @objc private func tick() { if !paused { captureNow() } }
    func show() { panel.orderFrontRegardless() }
    @objc func togglePause() { paused.toggle(); pauseButton.title = paused ? "继续" : "暂停"; status.stringValue = paused ? "已暂停。点击继续，或完成已捕获的长截图。" : "继续向下滚动，保留足够的重合区域。" }
    @objc func captureNow() {
        guard !stopped, !sampling, !finishing, let filter, let config else { return }
        sampling = true
        Task { @MainActor in
            defer { sampling = false; if finishing && !stopped { complete() } }
            do {
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                guard !stopped, let crop = CaptureGeometry.pixelRect(selection: region, canvasSize: screen.frame.size, imageSize: CGSize(width: image.width, height: image.height)), let frame = image.cropping(to: crop) else { return }
                let update = stitcher.append(frame)
                guard !stopped else { return }
                switch update {
                case .started, .appended:
                    failures = 0; status.stringValue = "已捕获 \(stitcher.frameCount) 段 · \(stitcher.width) × \(stitcher.outputHeight) px\n继续慢慢向下滚动；完成后可添加标注、复制或保存。"
                case .unchanged: break
                case .insufficientOverlap:
                    failures += 1
                    if failures >= 3 { status.stringValue = "暂未对齐：请慢些滚动，或向上回滚一点以保留重合区域。\n已捕获的内容仍保留。" }
                case .limitReached:
                    paused = true; pauseButton.title = "已达上限"; status.stringValue = "已达长图尺寸上限，点击完成保存已捕获内容。"
                case .incompatibleSize:
                    paused = true; status.stringValue = "画面尺寸已变化，请完成当前长图或取消重试。"
                }
            } catch { if !stopped { status.stringValue = "捕获失败：\(error.localizedDescription)。可稍后重试或完成已有内容。" } }
        }
    }
    @objc func finish() {
        guard !stopped else { return }; finishing = true; timer?.invalidate(); timer = nil
        if !sampling { complete() }
    }
    private func complete() {
        guard let image = stitcher.image() else {
            finishing = false
            if paused { status.stringValue = "尚无可用画面。点击继续后重试；选区过大时，请取消并缩小范围。" }
            else { status.stringValue = "还没有可用画面，正在重试捕获第一段。"; if config != nil { armTimer() } }
            return
        }
        let callback = onFinish; shutdown(); callback?(image)
    }
    @objc func cancel() { guard !stopped else { return }; let callback = onCancel; shutdown(); callback?() }
    func shutdown() {
        stopped = true; timer?.invalidate(); timer = nil; panel.delegate = nil
        border.orderOut(nil); border.close(); panel.orderOut(nil); panel.close(); onFinish = nil; onCancel = nil
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { cancel(); return false }
    deinit { timer?.invalidate() }
}
