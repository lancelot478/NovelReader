import Foundation
import SwiftData

@Model
final class Bookmark {
    var bookFileName: String
    var volumeFileName: String?
    var pageIndex: Int
    var chapterTitle: String
    var createdDate: Date

    init(bookFileName: String, volumeFileName: String? = nil, pageIndex: Int, chapterTitle: String) {
        self.bookFileName = bookFileName
        self.volumeFileName = volumeFileName
        self.pageIndex = pageIndex
        self.chapterTitle = chapterTitle
        self.createdDate = Date()
    }
}
