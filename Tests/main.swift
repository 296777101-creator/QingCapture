import AppKit
var failures = 0
func fail(_ message: String, file: StaticString = #filePath, line: UInt = #line) { failures += 1; print("FAIL \(file):\(line): \(message)") }
func expectEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { if a != b { fail("\(a) != \(b)", file: file, line: line) } }
func expectNotEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { if a == b { fail("values unexpectedly equal", file: file, line: line) } }
func expectGreater<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { if a <= b { fail("\(a) is not > \(b)", file: file, line: line) } }
func expectLess<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { if a >= b { fail("\(a) is not < \(b)", file: file, line: line) } }
func expectTrue(_ a: Bool, file: StaticString = #filePath, line: UInt = #line) { if !a { fail("expected true", file: file, line: line) } }
func expectFalse(_ a: Bool, file: StaticString = #filePath, line: UInt = #line) { expectTrue(!a, file: file, line: line) }
func expectNil<T>(_ a: T?, file: StaticString = #filePath, line: UInt = #line) { if a != nil { fail("expected nil", file: file, line: line) } }
enum TestError: Error { case unexpectedNil }
func unwrap<T>(_ a: T?) throws -> T { guard let a else { throw TestError.unexpectedNil }; return a }
let suite = CoreTests()
let upgrades = UpgradeTests()
let scroll = ScrollTests()
let tests: [(String, () throws -> Void)] = [
    ("translation chunk preservation", scroll.testTranslationChunksPreserveUnicodeAndParagraphs),
    ("scroll precise stitching", scroll.testPreciseOverlapAndPixels),
    ("scroll duplicate reverse and gap", scroll.testDuplicateReverseAndNoOverlap),
    ("scroll sticky header and footer", scroll.testStickyTopAndBottomAppearOnce),
    ("scroll solid footer", scroll.testSolidFooterIsNotDuplicated),
    ("scroll changing blank tail", scroll.testChangingBlankTailPreservesDocumentPixels),
    ("scroll bounds", scroll.testBoundsAndIncompatibleSize),
    ("shortcut validation and persistence", upgrades.testShortcutPersistence),
    ("single instance exclusion", upgrades.testSingleInstance),
    ("eraser and clear undo", upgrades.testRemoveClearUndo),
    ("filled shape", upgrades.testFilledShape),
    ("highlighter opacity", upgrades.testHighlighter),
    ("number marker", upgrades.testNumber),
    ("local OCR", upgrades.testOCR),
    ("text wrap width", upgrades.testTextWrapRespectsChosenWidth),
    ("eraser shape hit test", upgrades.testEraserFollowsEllipseOutline),
    ("reverse drag", suite.testReverseDrag),
    ("Retina crop", suite.testRetinaCropUsesTopOrigin),
    ("bounds and empty", suite.testCropClampsBoundsAndRejectsEmpty),
    ("undo redo branch", suite.testUndoRedoAndBranch),
    ("render orientation", suite.testRenderPreservesRetinaAndOrientation),
    ("rectangle", suite.testRectangleDrawnAndClippedToSelection),
    ("mosaic", suite.testMosaicChangesPixelsAndKeepsOutside),
    ("Chinese text", suite.testTextCreatesVisiblePixels)
]
for (name, test) in tests {
    let before = failures
    do { try test() } catch { fail("\(name): \(error)") }
    print("\(failures == before ? "PASS" : "FAIL") \(name)")
}
print("\(tests.count) tests, \(failures) assertion failures")
exit(failures == 0 ? 0 : 1)
