import AppKit
final class ScrollTests {
    func document(width: Int = 180, height: Int = 720) -> CGImage {
        let context = ScreenshotRenderer.makeContext(width: width, height: height)!
        for y in 0..<height {
            for x in stride(from: 0, to: width, by: 9) {
                let value = CGFloat((y * 37 + x * 19 + ((y / 13) * (x / 9) * 17)) % 210 + 20) / 255
                context.setFillColor(NSColor(srgbRed: value, green: value * 0.8, blue: value * 0.65, alpha: 1).cgColor)
                context.fill(CGRect(x: x, y: y, width: 9, height: 1))
            }
        }
        return context.makeImage()!
    }
    func crop(_ image: CGImage, offset: Int, height: Int = 160) -> CGImage { image.cropping(to: CGRect(x: 0, y: offset, width: image.width, height: height))! }
    func equal(_ a: CGImage, _ b: CGImage) {
        expectEqual(a.width, b.width); expectEqual(a.height, b.height)
        let helper = CoreTests()
        for y in stride(from: 0, to: min(a.height, b.height), by: 13) {
            for x in stride(from: 0, to: min(a.width, b.width), by: 23) {
                expectEqual(helper.pixel(a, x: x, y: y), helper.pixel(b, x: x, y: y))
            }
        }
    }
    func testPreciseOverlapAndPixels() throws {
        let doc = document(), stitcher = VerticalStitcher()
        expectEqual(stitcher.append(crop(doc, offset: 0)), .started)
        expectEqual(stitcher.append(crop(doc, offset: 47)), .appended(47))
        expectEqual(stitcher.append(crop(doc, offset: 105)), .appended(58))
        expectEqual(stitcher.outputHeight, 265); expectEqual(stitcher.frameCount, 3)
        equal(try unwrap(stitcher.image()), crop(doc, offset: 0, height: 265))
    }
    func testDuplicateReverseAndNoOverlap() {
        let doc = document(), stitcher = VerticalStitcher()
        _ = stitcher.append(crop(doc, offset: 0))
        expectEqual(stitcher.append(crop(doc, offset: 0)), .unchanged)
        _ = stitcher.append(crop(doc, offset: 60))
        let height = stitcher.outputHeight
        expectEqual(stitcher.append(crop(doc, offset: 20)), .insufficientOverlap)
        expectEqual(stitcher.append(crop(doc, offset: 500)), .insufficientOverlap)
        expectEqual(stitcher.outputHeight, height)
    }
    func sticky(_ document: CGImage, offset: Int, solid: Bool = false) -> CGImage {
        let context = ScreenshotRenderer.makeContext(width: document.width, height: 160)!
        context.setFillColor(NSColor.systemBlue.cgColor); context.fill(CGRect(x: 0, y: 150, width: document.width, height: 10))
        context.draw(crop(document, offset: offset, height: 132), in: CGRect(x: 0, y: 18, width: document.width, height: 132))
        for x in stride(from: 0, to: document.width, by: 9) {
            context.setFillColor((solid || x % 18 == 0 ? NSColor.black : NSColor.white).cgColor)
            context.fill(CGRect(x: x, y: 0, width: 9, height: 18))
        }
        return context.makeImage()!
    }
    func testStickyTopAndBottomAppearOnce() throws {
        let doc = document(), stitcher = VerticalStitcher()
        _ = stitcher.append(sticky(doc, offset: 0))
        expectEqual(stitcher.append(sticky(doc, offset: 47)), .appended(47))
        let expected = ScreenshotRenderer.makeContext(width: doc.width, height: 207)!
        let first = sticky(doc, offset: 0)
        expected.draw(first.cropping(to: CGRect(x: 0, y: 0, width: doc.width, height: 142))!, in: CGRect(x: 0, y: 65, width: doc.width, height: 142))
        expected.draw(crop(doc, offset: 132, height: 47), in: CGRect(x: 0, y: 18, width: doc.width, height: 47))
        expected.draw(first.cropping(to: CGRect(x: 0, y: 142, width: doc.width, height: 18))!, in: CGRect(x: 0, y: 0, width: doc.width, height: 18))
        equal(try unwrap(stitcher.image()), expected.makeImage()!)
    }
    func testSolidFooterIsNotDuplicated() throws {
        let doc = document(), stitcher = VerticalStitcher()
        _ = stitcher.append(sticky(doc, offset: 0, solid: true))
        expectEqual(stitcher.append(sticky(doc, offset: 47, solid: true)), .appended(47))
        let expected = ScreenshotRenderer.makeContext(width: doc.width, height: 207)!
        let first = sticky(doc, offset: 0, solid: true)
        expected.draw(first.cropping(to: CGRect(x: 0, y: 0, width: doc.width, height: 142))!, in: CGRect(x: 0, y: 65, width: doc.width, height: 142))
        expected.draw(crop(doc, offset: 132, height: 47), in: CGRect(x: 0, y: 18, width: doc.width, height: 47))
        expected.setFillColor(NSColor.black.cgColor); expected.fill(CGRect(x: 0, y: 0, width: doc.width, height: 18))
        equal(try unwrap(stitcher.image()), expected.makeImage()!)
    }
    func testChangingBlankTailPreservesDocumentPixels() throws {
        let source = document(), context = ScreenshotRenderer.makeContext(width: 180, height: 720)!
        context.draw(source, in: CGRect(x: 0, y: 0, width: 180, height: 720))
        context.setFillColor(NSColor.white.cgColor)
        for (start, end) in [(148,160),(204,207),(255,265),(296,311)] { context.fill(CGRect(x: 0, y: 720-end, width: 180, height: end-start)) }
        let doc = context.makeImage()!, stitcher = VerticalStitcher()
        _ = stitcher.append(crop(doc, offset: 0))
        var previous = 0
        for offset in [47,105,151,209] {
            expectEqual(stitcher.append(crop(doc, offset: offset)), .appended(offset-previous)); previous = offset
        }
        equal(try unwrap(stitcher.image()), crop(doc, offset: 0, height: 369))
    }
    func testTranslationChunksPreserveUnicodeAndParagraphs() {
        let text = String(repeating: "你好🌿 café。\n", count: 45)
        let chunks = TranslationChunks.split(text, limit: 31)
        expectEqual(chunks.joined(), text)
        expectTrue(chunks.count > 1)
        expectTrue(chunks.allSatisfy { !$0.isEmpty && $0.count <= 31 })
        expectTrue(TranslationChunks.split("  \n").isEmpty)
    }
    func testBoundsAndIncompatibleSize() {
        let doc = document(), stitcher = VerticalStitcher(maxPixels: 32_000)
        expectEqual(stitcher.append(crop(doc, offset: 0)), .started)
        expectEqual(stitcher.append(crop(doc, offset: 47)), .limitReached)
        expectEqual(stitcher.outputHeight, 160)
        expectEqual(stitcher.append(doc.cropping(to: CGRect(x: 0, y: 0, width: 90, height: 160))!), .incompatibleSize)
    }
}
