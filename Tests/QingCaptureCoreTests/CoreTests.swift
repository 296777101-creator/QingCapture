import AppKit

final class CoreTests {
    func testReverseDrag() {
        expectEqual(CaptureGeometry.rect(from: CGPoint(x: 100, y: 80), to: CGPoint(x: 20, y: 10)), CGRect(x: 20, y: 10, width: 80, height: 70))
    }
    func testRetinaCropUsesTopOrigin() {
        expectEqual(CaptureGeometry.pixelRect(selection: CGRect(x: 10, y: 20, width: 30, height: 40), canvasSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 200, height: 200)), CGRect(x: 20, y: 80, width: 60, height: 80))
    }
    func testCropClampsBoundsAndRejectsEmpty() {
        expectEqual(CaptureGeometry.pixelRect(selection: CGRect(x: -5, y: -5, width: 20, height: 20), canvasSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 200, height: 200)), CGRect(x: 0, y: 170, width: 30, height: 30))
        expectNil(CaptureGeometry.pixelRect(selection: .zero, canvasSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 200, height: 200)))
        expectNil(CaptureGeometry.pixelRect(selection: CGRect(x: 0, y: 0, width: 10, height: 10), canvasSize: .zero, imageSize: CGSize(width: 200, height: 200)))
    }
    func testUndoRedoAndBranch() {
        var history = AnnotationHistory()
        history.append(Annotation(tool: .rectangle, start: .zero, end: CGPoint(x: 10, y: 10)))
        history.undo()
        expectTrue(history.items.isEmpty)
        expectTrue(history.canRedo)
        history.redo()
        expectEqual(history.items.count, 1)
        history.undo()
        history.append(Annotation(tool: .ellipse, start: .zero, end: CGPoint(x: 20, y: 20)))
        expectFalse(history.canRedo)
    }
    func image() -> CGImage {
        let context = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.white.cgColor); context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        context.setFillColor(NSColor.blue.cgColor); context.fill(CGRect(x: 0, y: 100, width: 200, height: 100))
        return context.makeImage()!
    }
    func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return Array(bytes[offset..<(offset + 4)])
    }
    func testRenderPreservesRetinaAndOrientation() throws {
        let cropped = try unwrap(ScreenshotRenderer.render(image: image(), canvasSize: CGSize(width: 100, height: 100), selection: CGRect(x: 10, y: 60, width: 40, height: 30), annotations: []))
        expectEqual(cropped.width, 80); expectEqual(cropped.height, 60)
        let p = pixel(cropped, x: 20, y: 20)
        expectGreater(p[2], 240); expectLess(p[0], 10)
    }
    func testRectangleDrawnAndClippedToSelection() throws {
        let annotation = Annotation(tool: .rectangle, start: CGPoint(x: 10, y: 10), end: CGPoint(x: 40, y: 40), color: .red, lineWidth: 3)
        let result = try unwrap(ScreenshotRenderer.render(image: image(), canvasSize: CGSize(width: 100, height: 100), selection: CGRect(x: 0, y: 0, width: 50, height: 50), annotations: [annotation]))
        let p = pixel(result, x: 20, y: 60)
        expectGreater(p[0], 230); expectLess(p[1], 20)
        expectEqual(result.width, 100)
    }
    func testMosaicChangesPixelsAndKeepsOutside() throws {
        let context = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for x in 0..<200 {
            context.setFillColor((x % 2 == 0 ? NSColor.black : NSColor.white).cgColor)
            context.fill(CGRect(x: x, y: 0, width: 1, height: 200))
        }
        let original = context.makeImage()!
        let result = try unwrap(ScreenshotRenderer.render(image: original, canvasSize: CGSize(width: 100, height: 100), selection: CGRect(x: 0, y: 0, width: 100, height: 100), annotations: [Annotation(tool: .mosaic, start: CGPoint(x: 20, y: 20), end: CGPoint(x: 80, y: 80))]))
        expectEqual(pixel(result, x: 4, y: 4), pixel(original, x: 4, y: 4))
        expectEqual(pixel(result, x: 61, y: 100), pixel(result, x: 62, y: 100))
        expectNotEqual(pixel(result, x: 61, y: 100), pixel(original, x: 61, y: 100))
    }
    func testTextCreatesVisiblePixels() throws {
        let result = try unwrap(ScreenshotRenderer.render(image: image(), canvasSize: CGSize(width: 100, height: 100), selection: CGRect(x: 0, y: 0, width: 100, height: 50), annotations: [Annotation(tool: .text, start: CGPoint(x: 5, y: 5), end: .zero, color: .red, text: "测试 AI")]))
        let original = try unwrap(image().cropping(to: CGRect(x: 0, y: 100, width: 200, height: 100)))
        expectNotEqual(NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:]), NSBitmapImageRep(cgImage: original).representation(using: .png, properties: [:]))
    }
}
