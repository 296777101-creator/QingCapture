import AppKit
public enum CaptureGeometry {
    public static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
    public static func pixelRect(selection: CGRect, canvasSize: CGSize, imageSize: CGSize) -> CGRect? {
        guard canvasSize.width > 0, canvasSize.height > 0, imageSize.width > 0, imageSize.height > 0 else { return nil }
        let rect = selection.standardized.intersection(CGRect(origin: .zero, size: canvasSize))
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }
        let sx = imageSize.width / canvasSize.width, sy = imageSize.height / canvasSize.height
        let pixels = CGRect(x: rect.minX * sx, y: (canvasSize.height - rect.maxY) * sy, width: rect.width * sx, height: rect.height * sy).integral
        return pixels.intersection(CGRect(origin: .zero, size: imageSize))
    }
}
