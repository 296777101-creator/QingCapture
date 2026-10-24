import AppKit
import CoreImage
public enum ScreenshotRenderer {
    public static func render(image: CGImage, canvasSize: CGSize, selection: CGRect, annotations: [Annotation]) -> CGImage? {
        let imageSize = CGSize(width: image.width, height: image.height)
        guard let crop = CaptureGeometry.pixelRect(selection: selection, canvasSize: canvasSize, imageSize: imageSize),
              let base = image.cropping(to: crop), let context = makeContext(width: base.width, height: base.height) else { return nil }
        context.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))
        let sx = imageSize.width / canvasSize.width, sy = imageSize.height / canvasSize.height
        context.scaleBy(x: sx, y: sy)
        context.translateBy(x: -crop.minX / sx, y: -(canvasSize.height - crop.maxY / sy))
        let mosaic = annotations.contains(where: { $0.tool == .mosaic }) ? pixelated(image: image, blockSize: max(8, Int(12 * sx))) : nil
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for annotation in annotations {
            let pixels = annotation.tool == .mosaic ? pixelated(image: image, blockSize: max(4, Int(annotation.mosaicSize * sx))) : mosaic
            draw(annotation, in: context, canvasSize: canvasSize, mosaic: pixels, blurred: annotation.tool == .blur ? blurred(image: image) : nil)
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    public static func makeContext(width: Int, height: Int) -> CGContext? {
        guard width > 0, height > 0 else { return nil }
        return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    public static func pixelated(image: CGImage, blockSize: Int) -> CGImage? {
        let width = max(1, image.width / max(2, blockSize)), height = max(1, image.height / max(2, blockSize))
        guard let small = makeContext(width: width, height: height), let large = makeContext(width: image.width, height: image.height) else { return nil }
        small.interpolationQuality = .high
        small.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let thumbnail = small.makeImage() else { return nil }
        large.interpolationQuality = .none
        large.draw(thumbnail, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return large.makeImage()
    }

    public static func blurred(image: CGImage) -> CGImage? {
        let original = CIImage(cgImage: image)
        let output = original.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 18]).cropped(to: original.extent)
        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: original.extent)
    }

    public static func draw(_ annotation: Annotation, in context: CGContext, canvasSize: CGSize, mosaic: CGImage?, blurred: CGImage? = nil) {
        context.saveGState()
        defer { context.restoreGState() }
        let rect = CaptureGeometry.rect(from: annotation.start, to: annotation.end)
        context.setStrokeColor(annotation.color.usingColorSpace(.deviceRGB)!.cgColor)
        context.setFillColor(annotation.color.usingColorSpace(.deviceRGB)!.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.setLineCap(.round); context.setLineJoin(.round)
        switch annotation.tool {
        case .rectangle: if annotation.filled { context.fill(rect) } else { context.stroke(rect) }
        case .ellipse: if annotation.filled { context.fillEllipse(in: rect) } else { context.strokeEllipse(in: rect) }
        case .arrow:
            let a = annotation.start, b = annotation.end
            context.move(to: a); context.addLine(to: b); context.strokePath()
            let angle = atan2(b.y - a.y, b.x - a.x), length = max(12, annotation.lineWidth * 4)
            context.move(to: b)
            context.addLine(to: CGPoint(x: b.x - length * cos(angle - .pi / 6), y: b.y - length * sin(angle - .pi / 6)))
            context.addLine(to: CGPoint(x: b.x - length * cos(angle + .pi / 6), y: b.y - length * sin(angle + .pi / 6)))
            context.closePath(); context.fillPath()
            if annotation.doubleArrow {
                context.move(to: a)
                context.addLine(to: CGPoint(x: a.x + length * cos(angle - .pi / 6), y: a.y + length * sin(angle - .pi / 6)))
                context.addLine(to: CGPoint(x: a.x + length * cos(angle + .pi / 6), y: a.y + length * sin(angle + .pi / 6)))
                context.closePath(); context.fillPath()
            }
        case .line:
            context.move(to: annotation.start); context.addLine(to: annotation.end); context.strokePath()
        case .pen, .highlighter:
            if annotation.tool == .highlighter { context.setAlpha(0.34); context.setLineWidth(max(14, annotation.lineWidth * 5)); context.setLineCap(.butt) }
            let points = annotation.points.isEmpty ? [annotation.start, annotation.end] : annotation.points
            guard let first = points.first else { return }
            context.move(to: first)
            for point in points.dropFirst() { context.addLine(to: point) }
            context.strokePath()
        case .text:
            let font = NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold)
            let text = NSAttributedString(string: annotation.text, attributes: [.font: font, .foregroundColor: annotation.color])
            let width = max(1, min(canvasSize.width - annotation.start.x, annotation.textWidth > 0 ? annotation.textWidth : canvasSize.width - annotation.start.x))
            let measured = text.boundingRect(with: NSSize(width: width, height: 100_000), options: [.usesLineFragmentOrigin, .usesFontLeading])
            text.draw(with: CGRect(x: annotation.start.x, y: annotation.start.y, width: width, height: ceil(measured.height) + 2), options: [.usesLineFragmentOrigin, .usesFontLeading])
        case .mosaic:
            if let mosaic { context.clip(to: rect); context.interpolationQuality = .none; context.draw(mosaic, in: CGRect(origin: .zero, size: canvasSize)) }
        case .blur:
            if let blurred { context.clip(to: rect); context.draw(blurred, in: CGRect(origin: .zero, size: canvasSize)) }
        case .number:
            let radius: CGFloat = max(13, annotation.lineWidth * 3 + 5)
            context.fillEllipse(in: CGRect(x: annotation.start.x - radius, y: annotation.start.y - radius, width: radius * 2, height: radius * 2))
            let text = NSAttributedString(string: String(annotation.number), attributes: [.font: NSFont.systemFont(ofSize: radius * 1.25, weight: .bold), .foregroundColor: NSColor.white])
            text.draw(at: CGPoint(x: annotation.start.x - text.size().width / 2, y: annotation.start.y - text.size().height / 2))
        case .selection, .eraser: break
        }
    }
}
