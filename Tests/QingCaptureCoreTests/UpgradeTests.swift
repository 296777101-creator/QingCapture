import AppKit
final class UpgradeTests {
    func testShortcutPersistence() {
        expectTrue(ScreenshotShortcut.standard.isValid)
        expectFalse(ScreenshotShortcut(keyCode: 0, modifiers: 0).isValid)
        expectFalse(ScreenshotShortcut(keyCode: 0, modifiers: NSEvent.ModifierFlags.shift.rawValue).isValid)
        expectFalse(ScreenshotShortcut(keyCode: 53, modifiers: NSEvent.ModifierFlags.command.rawValue).isValid)
        let custom = ScreenshotShortcut(keyCode: 1, modifiers: NSEvent.ModifierFlags([.control, .shift]).rawValue)
        expectEqual(custom.display, "⌃⇧S")
        expectEqual(custom.carbonModifiers, UInt32(4608))
        let name = "local.qingcapture.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        ShortcutStore.save(custom, to: defaults)
        expectEqual(ShortcutStore.load(from: defaults), custom)
    }
    func testSingleInstance() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".lock")
        let first = SingleInstanceLock(), second = SingleInstanceLock()
        defer { first.release(); second.release(); try? FileManager.default.removeItem(at: url) }
        expectTrue(first.acquire(at: url)); expectFalse(second.acquire(at: url))
        first.release(); expectTrue(second.acquire(at: url))
    }
    func testRemoveClearUndo() {
        var history = AnnotationHistory()
        history.append(Annotation(tool: .rectangle, start: .zero, end: CGPoint(x: 20, y: 20)))
        history.append(Annotation(tool: .arrow, start: .zero, end: CGPoint(x: 20, y: 20)))
        history.remove(at: 0); expectEqual(history.items.count, 1); expectEqual(history.items.first?.tool, .arrow)
        history.undo(); expectEqual(history.items.count, 2)
        history.clear(); expectTrue(history.items.isEmpty)
        history.undo(); expectEqual(history.items.count, 2)
        history.redo(); expectTrue(history.items.isEmpty)
    }
    func result(_ annotation: Annotation) throws -> CGImage {
        let image = ScreenshotRenderer.makeContext(width: 200, height: 200)!
        image.setFillColor(NSColor.white.cgColor); image.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        return try unwrap(ScreenshotRenderer.render(image: image.makeImage()!, canvasSize: CGSize(width: 100, height: 100), selection: CGRect(x: 0, y: 0, width: 100, height: 100), annotations: [annotation]))
    }
    func testFilledShape() throws {
        var a = Annotation(tool: .rectangle, start: CGPoint(x: 10, y: 10), end: CGPoint(x: 90, y: 90), color: .red)
        a.filled = true
        let p = CoreTests().pixel(try result(a), x: 100, y: 100)
        expectLess(p[1], 10); expectGreater(p[0], 245)
    }
    func testHighlighter() throws {
        let a = Annotation(tool: .highlighter, start: CGPoint(x: 10, y: 50), end: CGPoint(x: 90, y: 50), color: .red, lineWidth: 12)
        let p = CoreTests().pixel(try result(a), x: 100, y: 100)
        expectGreater(p[1], 100); expectLess(p[1], 240); expectGreater(p[0], 245)
    }
    func testNumber() throws {
        let a = Annotation(tool: .number, start: CGPoint(x: 50, y: 50), end: .zero, color: .red)
        let p = CoreTests().pixel(try result(a), x: 118, y: 100)
        expectLess(p[1], 50)
    }
    func testEraserFollowsEllipseOutline() {
        let circle = Annotation(tool: .ellipse, start: .zero, end: CGPoint(x: 100, y: 100))
        expectTrue(circle.hitTest(CGPoint(x: 14.64, y: 14.64)))
        expectFalse(circle.hitTest(CGPoint(x: 50, y: 50)))
        let line = Annotation(tool: .line, start: .zero, end: CGPoint(x: 100, y: 100))
        expectTrue(line.hitTest(CGPoint(x: 40, y: 42)))
        expectFalse(line.hitTest(CGPoint(x: 30, y: 80)))
    }
    func testTextWrapRespectsChosenWidth() throws {
        var annotation = Annotation(tool: .text, start: CGPoint(x: 10, y: 10), end: .zero, color: .red, text: "one two three four five")
        annotation.fontSize = 16; annotation.textWidth = 30
        let output = try result(annotation)
        var redOutside = 0
        let suite = CoreTests()
        for x in stride(from: 92, to: 195, by: 4) {
            for y in stride(from: 8, to: 195, by: 4) {
                let p = suite.pixel(output, x: x, y: y)
                if p[0] > 200 && p[1] < 100 { redOutside += 1 }
            }
        }
        expectEqual(redOutside, 0)
    }
    func testOCR() throws {
        let context = ScreenshotRenderer.makeContext(width: 800, height: 180)!
        context.setFillColor(NSColor.white.cgColor); context.fill(CGRect(x: 0, y: 0, width: 800, height: 180))
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        ("HELLO 2468" as NSString).draw(at: CGPoint(x: 25, y: 55), withAttributes: [.font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black])
        NSGraphicsContext.restoreGraphicsState()
        let text = try TextRecognition.recognize(image: context.makeImage()!)
        expectTrue(text.contains("HELLO")); expectTrue(text.contains("2468"))
    }
}
