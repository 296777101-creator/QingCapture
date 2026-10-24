import AppKit

public enum StitchUpdate: Equatable {
    case started, appended(Int), unchanged, insufficientOverlap, incompatibleSize, limitReached
}

/// A downward-only compositor. Uncertain or non-overlapping frames never mutate the result.
public final class VerticalStitcher {
    public private(set) var frameCount = 0
    public private(set) var outputHeight = 0
    public private(set) var width = 0
    private let maxPixels: Int
    private let maxHeight: Int
    private var chunks: [CGImage] = []
    private var footer: CGImage?
    private var footerHeight: Int?
    private var previous: GrayFrame?
    private var viewportHeight = 0

    public init(maxPixels: Int = 32_000_000, maxHeight: Int = 30_000) {
        self.maxPixels = max(1, maxPixels); self.maxHeight = max(1, maxHeight)
    }

    public func append(_ image: CGImage) -> StitchUpdate {
        if frameCount == 0 {
            guard image.height <= maxHeight, image.width <= maxPixels / image.height,
                  let owned = copy(image), let gray = GrayFrame(owned) else { return .limitReached }
            width = image.width; viewportHeight = image.height; outputHeight = image.height
            chunks = [owned]; previous = gray; frameCount = 1; return .started
        }
        guard image.width == width, image.height == viewportHeight else { return .incompatibleSize }
        guard let old = previous, let next = GrayFrame(image) else { return .insufficientOverlap }
        let header = fixedRows(old, next, fromBottom: false)
        let proposedFooter = fixedRows(old, next, fromBottom: true)
        let bottom = max(2, proposedFooter), top = max(2, header)
        if error(old, next, shift: 0, top: top, bottom: bottom, smooth: false, allowBlank: true) < 0.6 { return .unchanged }
        let minOverlap = max(24, viewportHeight / 5)
        let maxShift = min(viewportHeight * 3 / 4, viewportHeight - top - bottom - minOverlap)
        guard maxShift > 0 else { return .insufficientOverlap }
        var coarse: [(Int, Float)] = []
        for offset in stride(from: 4, through: max(4, maxShift), by: 4) where offset <= maxShift {
            coarse.append((offset, error(old, next, shift: offset, top: top, bottom: bottom, smooth: true)))
        }
        if coarse.isEmpty { coarse = [(1, 0)] }
        coarse.sort { $0.1 < $1.1 }
        var seeds: [Int] = []
        for candidate in coarse where candidate.1.isFinite {
            if seeds.allSatisfy({ abs($0 - candidate.0) > 8 }) { seeds.append(candidate.0) }
            if seeds.count == 3 { break }
        }
        var refined: [(Int, Float)] = []
        for seed in seeds {
            for offset in max(1, seed - 5)...min(maxShift, seed + 5) {
                refined.append((offset, error(old, next, shift: offset, top: top, bottom: bottom, smooth: false)))
            }
        }
        refined.sort { $0.1 < $1.1 }
        guard let best = refined.first, best.1 < 5 else { return .insufficientOverlap }
        if let alternative = refined.first(where: { abs($0.0 - best.0) > 8 }), alternative.1 <= best.1 + 0.12 { return .insufficientOverlap }
        let shift = best.0
        guard outputHeight + shift <= maxHeight, outputHeight + shift <= maxPixels / width else { return .limitReached }
        let stripRect = CGRect(x: 0, y: viewportHeight - proposedFooter - shift, width: width, height: shift)
        guard let strip = image.cropping(to: stripRect).flatMap({ copy($0) }) else { return .insufficientOverlap }
        let nextFooter: CGImage?
        if proposedFooter > 0 {
            guard let copied = image.cropping(to: CGRect(x: 0, y: viewportHeight - proposedFooter, width: width, height: proposedFooter)).flatMap({ copy($0) }) else { return .insufficientOverlap }
            nextFooter = copied
        } else { nextFooter = nil }
        let previousFooter = footerHeight ?? 0
        var adjusted = chunks
        if proposedFooter > previousFooter {
            var remove = proposedFooter - previousFooter
            while remove > 0 {
                guard let last = adjusted.popLast() else { return .insufficientOverlap }
                if last.height <= remove { remove -= last.height }
                else {
                    guard let clipped = last.cropping(to: CGRect(x: 0, y: 0, width: width, height: last.height - remove)).flatMap({ copy($0) }) else { return .insufficientOverlap }
                    adjusted.append(clipped); remove = 0
                }
            }
        } else if previousFooter > proposedFooter {
            guard let recovered = footer?.cropping(to: CGRect(x: 0, y: 0, width: width, height: previousFooter - proposedFooter)).flatMap({ copy($0) }) else { return .insufficientOverlap }
            adjusted.append(recovered)
        }
        adjusted.append(strip)
        chunks = adjusted; footer = nextFooter; footerHeight = proposedFooter
        previous = next; outputHeight += shift; frameCount += 1
        return .appended(shift)
    }

    public func image() -> CGImage? {
        guard width > 0, outputHeight > 0, let context = ScreenshotRenderer.makeContext(width: width, height: outputHeight) else { return nil }
        var offset = 0
        for chunk in chunks + (footer.map { [$0] } ?? []) {
            context.draw(chunk, in: CGRect(x: 0, y: outputHeight - offset - chunk.height, width: width, height: chunk.height)); offset += chunk.height
        }
        guard offset == outputHeight else { return nil }
        return context.makeImage()
    }

    private func copy(_ image: CGImage) -> CGImage? {
        guard let context = ScreenshotRenderer.makeContext(width: image.width, height: image.height) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)); return context.makeImage()
    }

    private func fixedRows(_ a: GrayFrame, _ b: GrayFrame, fromBottom: Bool) -> Int {
        var count = 0
        for index in 0..<min(viewportHeight / 4, viewportHeight - 1) {
            let row = fromBottom ? viewportHeight - 1 - index : index
            var difference: Float = 0
            for x in 0..<a.columns { difference += abs(a.raw[row * a.columns + x] - b.raw[row * a.columns + x]) }
            if difference / Float(a.columns) > 0.8 { break }
            count += 1
        }
        return count
    }

    private func error(_ a: GrayFrame, _ b: GrayFrame, shift: Int, top: Int, bottom: Int, smooth: Bool, allowBlank: Bool = false) -> Float {
        let end = viewportHeight - bottom - shift
        guard end > top else { return .infinity }
        let lhs = smooth ? a.smoothed : a.raw, rhs = smooth ? b.smoothed : b.raw
        var errors: [Float] = []
        for y in stride(from: top, to: end, by: smooth ? 4 : 2) {
            var total: Float = 0, minimum: Float = 255
            for x in 0..<a.columns {
                let av = lhs[(y + shift) * a.columns + x], bv = rhs[y * a.columns + x]
                total += abs(av - bv); minimum = min(minimum, av, bv)
            }
            if minimum < 246 { errors.append(total / Float(a.columns)) }
        }
        guard errors.count >= 6 else { return allowBlank && errors.isEmpty ? 0 : .infinity }
        errors.sort(); let count = max(1, errors.count - errors.count / 10)
        return errors.prefix(count).reduce(0, +) / Float(count)
    }

    private struct GrayFrame {
        let columns: Int
        let raw: [Float]
        let smoothed: [Float]
        init?(_ image: CGImage) {
            columns = min(48, image.width)
            var bytes = [UInt8](repeating: 0, count: columns * image.height)
            guard let context = CGContext(data: &bytes, width: columns, height: image.height, bitsPerComponent: 8, bytesPerRow: columns, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: image.height))
            raw = bytes.map(Float.init)
            var blurred = raw
            for y in 0..<image.height {
                let start = max(0, y - 3), end = min(image.height - 1, y + 3)
                for x in 0..<columns {
                    var value: Float = 0
                    for row in start...end { value += raw[row * columns + x] }
                    blurred[y * columns + x] = value / Float(end - start + 1)
                }
            }
            smoothed = blurred
        }
    }
}
