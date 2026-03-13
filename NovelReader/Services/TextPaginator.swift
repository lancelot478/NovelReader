import UIKit
import CoreText

enum TextPaginator {

    static func paginate(
        _ text: String,
        fontSize: CGFloat,
        lineSpacing: CGFloat,
        pageSize: CGSize
    ) -> [String] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              pageSize.width > 0, pageSize.height > 0 else {
            return [text]
        }

        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = lineSpacing

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paraStyle,
        ]

        let nsAttrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(nsAttrStr)
        let nsString = text as NSString
        let totalLength = nsString.length

        var pages: [String] = []
        var currentIndex = 0

        while currentIndex < totalLength {
            let path = CGPath(rect: CGRect(origin: .zero, size: pageSize), transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter, CFRangeMake(currentIndex, 0), path, nil
            )
            let range = CTFrameGetVisibleStringRange(frame)
            guard range.length > 0 else { break }

            let pageText = nsString.substring(
                with: NSRange(location: range.location, length: range.length)
            )
            pages.append(pageText)
            currentIndex += range.length
        }

        return pages.isEmpty ? [text] : pages
    }
}
