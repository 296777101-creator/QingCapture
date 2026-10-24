import AppKit
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

final class CaptureCanvas: NSView, NSTextFieldDelegate {
    let image: CGImage
    weak var controller: CaptureController?
    var selection: CGRect?
    var history = AnnotationHistory()
    var tool: Tool = .selection
    var ink: NSColor = .systemRed
    var lineWidth: CGFloat = 3
    var fontSize: CGFloat = 24
    var filled = false
    var doubleArrow = false
    var mosaicSize: CGFloat = 12
    private var mosaicCache: [Int: CGImage] = [:]
    lazy var blurred = ScreenshotRenderer.blurred(image: image)
    var draft: Annotation?
    var anchor = CGPoint.zero
    var priorRect = CGRect.zero
    var mode = DragMode.none
    var textField: NSTextField?
    var textOrigin = CGPoint.zero
    lazy var mosaic = ScreenshotRenderer.pixelated(image: image, blockSize: Int(12 * CGFloat(image.width) / bounds.width))
    enum DragMode { case none, selecting, moving, resizing(CGPoint), drawing }

    init(frame: CGRect, image: CGImage, controller: CaptureController) {
        self.image = image; self.controller = controller
        super.init(frame: frame); setAccessibilityLabel("截图选区与标注画布")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(image, in: bounds)
        let shade = NSBezierPath(rect: bounds)
        if let selection { shade.appendRect(selection) }
        shade.windingRule = .evenOdd; NSColor.black.withAlphaComponent(0.48).setFill(); shade.fill()
        if let selection {
            context.saveGState(); context.clip(to: selection)
            for annotation in history.items { drawAnnotation(annotation, context: context) }
            if let draft { drawAnnotation(draft, context: context) }
            context.restoreGState()
            NSColor.systemGreen.setStroke()
            let path = NSBezierPath(rect: selection.insetBy(dx: -0.5, dy: -0.5)); path.lineWidth = 1.5; path.stroke()
            for point in corners(selection) { NSColor.white.setFill(); NSBezierPath(rect: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)).fill() }
            let scale = CGFloat(image.width) / bounds.width
            let sizeText = "\(Int(selection.width * scale)) × \(Int(selection.height * scale)) px"
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white]
            let width = (sizeText as NSString).size(withAttributes: attrs).width + 16
            let labelRect = CGRect(x: min(selection.minX, bounds.maxX - width - 4), y: min(selection.maxY + 8, bounds.maxY - 30), width: width, height: 24)
            NSColor.black.withAlphaComponent(0.8).setFill(); NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5).fill()
            (sizeText as NSString).draw(at: CGPoint(x: labelRect.minX + 8, y: labelRect.minY + 5), withAttributes: attrs)
        } else {
            let tip = "拖动鼠标选择截图区域    ·    Esc 取消"
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: NSColor.white]
            let size = (tip as NSString).size(withAttributes: attrs)
            let rect = CGRect(x: (bounds.width - size.width) / 2 - 22, y: bounds.height * 0.67, width: size.width + 44, height: 50)
            NSColor.black.withAlphaComponent(0.7).setFill(); NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
            (tip as NSString).draw(at: CGPoint(x: rect.minX + 22, y: rect.minY + 14), withAttributes: attrs)
        }
    }

    func corners(_ r: CGRect) -> [CGPoint] { [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)] }
    func point(_ event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        return CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX), y: min(max(p.y, bounds.minY), bounds.maxY))
    }
    override func mouseDown(with event: NSEvent) {
        commitText(); window?.makeFirstResponder(self); anchor = point(event)
        if let selection {
            if let corner = corners(selection).first(where: { hypot($0.x - anchor.x, $0.y - anchor.y) < 10 }) {
                let opposite = CGPoint(x: abs(corner.x - selection.minX) < 1 ? selection.maxX : selection.minX, y: abs(corner.y - selection.minY) < 1 ? selection.maxY : selection.minY)
                mode = .resizing(opposite); controller?.toolbar?.orderOut(nil); return
            }
            if selection.contains(anchor) {
                if tool == .selection { priorRect = selection; mode = .moving; controller?.toolbar?.orderOut(nil); return }
                if tool == .text { beginText(at: anchor); return }
                if tool == .number {
                    var annotation = makeAnnotation(start: anchor)
                    annotation.number = (history.items.filter { $0.tool == .number }.map(\.number).max() ?? 0) + 1
                    history.append(annotation); needsDisplay = true; controller?.toolbar?.refresh(); return
                }
                if tool == .eraser { erase(at: anchor); return }
                draft = makeAnnotation(start: anchor); mode = .drawing; return
            }
        }
        history = AnnotationHistory(); selection = nil; controller?.toolbar?.orderOut(nil); mode = .selecting; needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        var p = point(event)
        if tool == .eraser, selection?.contains(p) == true { erase(at: p); return }
        switch mode {
        case .selecting: selection = CaptureGeometry.rect(from: anchor, to: p)
        case .resizing(let opposite): selection = CaptureGeometry.rect(from: opposite, to: p)
        case .moving:
            let x = min(max(priorRect.minX + p.x - anchor.x, 0), bounds.width - priorRect.width)
            let y = min(max(priorRect.minY + p.y - anchor.y, 0), bounds.height - priorRect.height)
            selection = CGRect(x: x, y: y, width: priorRect.width, height: priorRect.height)
        case .drawing:
            if let r = selection { p = CGPoint(x: min(max(p.x, r.minX), r.maxX), y: min(max(p.y, r.minY), r.maxY)) }
            draft?.end = p; if tool == .pen || tool == .highlighter { draft?.points.append(p) }
        case .none: break
        }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if case .drawing = mode, let draft, hypot(draft.end.x - draft.start.x, draft.end.y - draft.start.y) > 1 || draft.points.count > 2 { history.append(draft) }
        draft = nil; mode = .none
        if let selection, selection.width >= 3, selection.height >= 3 { controller?.selected(self) } else { selection = nil }
        needsDisplay = true
    }
    override func rightMouseDown(with event: NSEvent) { controller?.cancel() }
    override func keyDown(with event: NSEvent) {
        let command = event.modifierFlags.contains(.command), shift = event.modifierFlags.contains(.shift)
        switch event.keyCode {
        case 53: controller?.cancel()
        case 36, 76: if selection != nil { controller?.copy(self) }
        case 6 where command: if shift { redoAnnotation() } else { undoAnnotation() }
        case 8 where command: controller?.copy(self)
        case 1 where command: controller?.save(self)
        case 1 where !command: controller?.startScrolling(self)
        case 5 where !command: controller?.recognize(self, translate: true)
        case 51, 117: undoAnnotation()
        case 123 where !command, 124 where !command, 125 where !command, 126 where !command:
            if let selection {
                let step: CGFloat = shift ? 10 : 1
                let dx: CGFloat = event.keyCode == 123 ? -step : (event.keyCode == 124 ? step : 0)
                let dy: CGFloat = event.keyCode == 125 ? -step : (event.keyCode == 126 ? step : 0)
                self.selection = CGRect(x: min(max(selection.minX + dx, 0), bounds.width - selection.width), y: min(max(selection.minY + dy, 0), bounds.height - selection.height), width: selection.width, height: selection.height)
                needsDisplay = true; controller?.positionToolbar(self)
            }
        default:
            if !command, !event.modifierFlags.contains(.control), !event.modifierFlags.contains(.option) {
                let keys: [UInt16: Tool] = [9:.selection,15:.rectangle,31:.ellipse,0:.arrow,37:.line,35:.pen,4:.highlighter,17:.text,46:.mosaic,11:.blur,45:.number,14:.eraser]
                if let next = keys[event.keyCode] { setTool(next); return }
                if event.keyCode == 3 { selectAllScreen(); return }
            }
            super.keyDown(with: event)
        }
    }

    func beginText(at point: CGPoint) {
        guard let selection else { return }
        let height: CGFloat = min(100, max(42, selection.height))
        let y = min(max(point.y, selection.minY), max(selection.minY, selection.maxY - height))
        let width = min(max(80, selection.maxX - point.x), selection.width), x = min(point.x, selection.maxX - min(max(80, selection.maxX - point.x), selection.width))
        let field = NSTextField(frame: CGRect(x: x, y: y, width: width, height: height))
        field.font = .systemFont(ofSize: fontSize, weight: .semibold); field.textColor = ink
        field.backgroundColor = NSColor.white.withAlphaComponent(0.92); field.isBezeled = true; field.focusRingType = .none
        field.cell?.wraps = true; field.cell?.isScrollable = false; field.usesSingleLineMode = false
        field.placeholderString = "输入文字；Shift+Enter 换行，Enter 确认"; field.delegate = self
        textOrigin = CGPoint(x: x + 2, y: y + 2); textField = field; addSubview(field); window?.makeFirstResponder(field)
    }
    func commitText() {
        guard let field = textField else { return }
        textField = nil; window?.makeFirstResponder(self)
        if !field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let width = max(1, field.bounds.width - 4)
            let attributes: [NSAttributedString.Key: Any] = [.font: field.font ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold)]
            let measured = NSAttributedString(string: field.stringValue, attributes: attributes).boundingRect(with: NSSize(width: width, height: 100_000), options: [.usesLineFragmentOrigin, .usesFontLeading])
            let origin = CGPoint(x: field.frame.minX + 2, y: field.frame.maxY - ceil(measured.height) - 2)
            var annotation = Annotation(tool: .text, start: origin, end: .zero, color: field.textColor ?? ink, lineWidth: lineWidth, text: field.stringValue)
            annotation.fontSize = field.font?.pointSize ?? fontSize; annotation.textWidth = width
            history.append(annotation)
        }
        field.removeFromSuperview(); needsDisplay = true; controller?.toolbar?.refresh()
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { textView.insertNewlineIgnoringFieldEditor(nil) }
            else { commitText() }
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { textField?.removeFromSuperview(); textField = nil; window?.makeFirstResponder(self); return true }
        return false
    }
    func setTool(_ next: Tool) { commitText(); tool = next; controller?.toolbar?.refresh(); window?.makeFirstResponder(self); (next == .text ? NSCursor.iBeam : NSCursor.crosshair).set() }
    func undoAnnotation() { commitText(); history.undo(); needsDisplay = true; controller?.toolbar?.refresh() }
    func redoAnnotation() { commitText(); history.redo(); needsDisplay = true; controller?.toolbar?.refresh() }
    func makeAnnotation(start: CGPoint) -> Annotation {
        var annotation = Annotation(tool: tool, start: start, end: start, color: ink, lineWidth: lineWidth, points: [start])
        annotation.filled = filled; annotation.doubleArrow = doubleArrow; annotation.fontSize = fontSize; annotation.mosaicSize = mosaicSize
        return annotation
    }
    func drawAnnotation(_ annotation: Annotation, context: CGContext) {
        var pixels: CGImage?
        if annotation.tool == .mosaic {
            let block = max(4, Int(annotation.mosaicSize * CGFloat(image.width) / bounds.width))
            if mosaicCache[block] == nil { mosaicCache[block] = ScreenshotRenderer.pixelated(image: image, blockSize: block) }
            pixels = mosaicCache[block]
        }
        ScreenshotRenderer.draw(annotation, in: context, canvasSize: bounds.size, mosaic: pixels, blurred: annotation.tool == .blur ? blurred : nil)
    }
    func erase(at point: CGPoint) {
        let index = history.items.lastIndex { $0.hitTest(point) }
        if let index { history.remove(at: index); needsDisplay = true; controller?.toolbar?.refresh() }
    }
    func clearAnnotations() { commitText(); history.clear(); needsDisplay = true; controller?.toolbar?.refresh() }
    func selectAllScreen() { commitText(); selection = bounds; needsDisplay = true; controller?.selected(self) }
    @objc func copy(_ sender: Any?) { controller?.copy(self) }
    @objc func saveDocument(_ sender: Any?) { controller?.save(self) }
    @objc func undo(_ sender: Any?) { undoAnnotation() }
    @objc func redo(_ sender: Any?) { redoAnnotation() }
}
