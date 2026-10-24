import AppKit
public enum Tool: String, CaseIterable {
    case selection, rectangle, ellipse, arrow, pen, text, mosaic, line, highlighter, blur, number, eraser
}
public struct Annotation {
    public var tool: Tool
    public var start: CGPoint
    public var end: CGPoint
    public var color: NSColor
    public var lineWidth: CGFloat
    public var text: String
    public var points: [CGPoint]
    public var filled = false
    public var doubleArrow = false
    public var fontSize: CGFloat = 24
    public var textWidth: CGFloat = 0
    public var mosaicSize: CGFloat = 12
    public var number = 1
    public func hitTest(_ point: CGPoint, tolerance: CGFloat = 8) -> Bool {
        let rect = CaptureGeometry.rect(from: start, to: end)
        let path = CGMutablePath()
        switch tool {
        case .rectangle: path.addRect(rect)
        case .ellipse: path.addEllipse(in: rect)
        case .mosaic, .blur: return rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .number: return hypot(point.x - start.x, point.y - start.y) <= max(13, lineWidth * 3 + 5) + tolerance
        case .text:
            let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .semibold)])
            let size = textWidth > 0 ? attributed.boundingRect(with: NSSize(width: textWidth, height: 100_000), options: [.usesLineFragmentOrigin, .usesFontLeading]).size : attributed.size()
            return CGRect(origin: start, size: size).insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .pen, .highlighter:
            let samples = points.isEmpty ? [start, end] : points
            if let first = samples.first { path.move(to: first); for p in samples.dropFirst() { path.addLine(to: p) } }
        case .arrow, .line: path.move(to: start); path.addLine(to: end)
        case .selection, .eraser: return false
        }
        if filled && (tool == .rectangle || tool == .ellipse) { return path.contains(point) }
        let width = tool == .highlighter ? max(14, lineWidth * 5) : lineWidth
        return path.copy(strokingWithWidth: width + 2 * tolerance, lineCap: .round, lineJoin: .round, miterLimit: 10).contains(point)
    }
    public init(tool: Tool, start: CGPoint, end: CGPoint, color: NSColor = .systemRed, lineWidth: CGFloat = 3, text: String = "", points: [CGPoint] = []) {
        self.tool = tool; self.start = start; self.end = end; self.color = color
        self.lineWidth = lineWidth; self.text = text; self.points = points
    }
}
public struct AnnotationHistory {
    public private(set) var items: [Annotation] = []
    private var past: [[Annotation]] = []
    private var future: [[Annotation]] = []
    public var canRedo: Bool { !future.isEmpty }
    public var canUndo: Bool { !past.isEmpty }
    public init() {}
    private mutating func checkpoint() { past.append(items); future.removeAll() }
    public mutating func append(_ item: Annotation) { checkpoint(); items.append(item) }
    public mutating func remove(at index: Int) { guard items.indices.contains(index) else { return }; checkpoint(); items.remove(at: index) }
    public mutating func clear() { guard !items.isEmpty else { return }; checkpoint(); items.removeAll() }
    public mutating func undo() { guard let previous = past.popLast() else { return }; future.append(items); items = previous }
    public mutating func redo() { guard let next = future.popLast() else { return }; past.append(items); items = next }
}
