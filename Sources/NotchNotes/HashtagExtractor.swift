import Foundation

package enum HashtagExtractor {
    private static let expression = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_#-])#([A-Za-z0-9_-]+)"#
    )

    package static func tags(in text: String) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var orderedTags: [String] = []
        var seen = Set<String>()

        expression.enumerateMatches(in: text, range: range) { match, _, _ in
            guard
                let match,
                let tagRange = Range(match.range(at: 1), in: text)
            else {
                return
            }

            let tag = String(text[tagRange]).lowercased()
            guard !tag.isEmpty, seen.insert(tag).inserted else {
                return
            }

            orderedTags.append(tag)
        }

        return orderedTags
    }

    /// Full ranges of each hashtag occurrence (including the leading `#`),
    /// in order, for syntax highlighting.
    package static func hashtagRanges(in text: String) -> [NSRange] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var ranges: [NSRange] = []
        expression.enumerateMatches(in: text, range: range) { match, _, _ in
            if let match {
                ranges.append(match.range)
            }
        }
        return ranges
    }
}
