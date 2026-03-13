import Foundation
import SwiftData

@Model
final class Book {
    var title: String
    var fileName: String
    var lastReadChapterIndex: Int
    var addedDate: Date
    var totalChapters: Int
    var colorHue: Double
    var isBundled: Bool = false

    init(title: String, fileName: String, isBundled: Bool = false) {
        self.title = title
        self.fileName = fileName
        self.lastReadChapterIndex = 0
        self.addedDate = Date()
        self.totalChapters = 0
        self.colorHue = Double.random(in: 0...1)
        self.isBundled = isBundled
    }
}
