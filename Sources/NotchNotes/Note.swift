import Foundation
import SwiftData

@Model
final class Note {
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    @Attribute(.externalStorage) var imageDatas: [Data] = []

    init(body: String, imageDatas: [Data] = [], createdAt: Date = .now, updatedAt: Date = .now) {
        self.body = body
        self.imageDatas = imageDatas
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = HashtagExtractor.tags(in: body)
    }

    func updateBody(_ newBody: String) {
        body = newBody
        updatedAt = .now
        tags = HashtagExtractor.tags(in: newBody)
    }
}
