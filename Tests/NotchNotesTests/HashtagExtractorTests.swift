import XCTest
@testable import NotchNotes

final class HashtagExtractorTests: XCTestCase {
    func testExtractsNormalizedUniqueTagsInFirstSeenOrder() {
        let text = "Capture #Work and #Project-1, then #todo_item and #work again."

        XCTAssertEqual(
            HashtagExtractor.tags(in: text),
            ["work", "project-1", "todo_item"]
        )
    }

    func testIgnoresEmbeddedHashesAndEmptyTags() {
        let text = "email a#bad # good ##also_bad but keep #valid"

        XCTAssertEqual(HashtagExtractor.tags(in: text), ["valid"])
    }
}
