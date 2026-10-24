import Foundation
public enum TranslationChunks {
    /// Preserves every character, including paragraph boundaries and composed Unicode glyphs.
    public static func split(_ text: String, limit: Int = 4_000) -> [String] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let maximum = max(1, limit)
        var remaining = text[...], chunks: [String] = []
        while !remaining.isEmpty {
            var end = remaining.index(remaining.startIndex, offsetBy: maximum, limitedBy: remaining.endIndex) ?? remaining.endIndex
            if end != remaining.endIndex {
                let prefix = remaining[..<end]
                if let split = prefix.lastIndex(where: { $0.isWhitespace }), prefix.distance(from: prefix.startIndex, to: split) >= maximum / 2 { end = remaining.index(after: split) }
            }
            chunks.append(String(remaining[..<end])); remaining = remaining[end...]
        }
        return chunks
    }
}
