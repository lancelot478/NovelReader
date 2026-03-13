import UIKit

struct Chapter: Equatable {
    let title: String
    let content: String
}

enum MarkdownParser {

    static func parseChapters(from content: String) -> [Chapter] {
        let raw = splitByHeadings(content)
        return consolidateChapters(raw)
    }

    static func renderMarkdown(_ text: String) -> AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            var result = try AttributedString(markdown: text, options: options)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 5
            result.mergeAttributes(
                AttributeContainer([.paragraphStyle: paragraphStyle])
            )
            return result
        } catch {
            return AttributedString(text)
        }
    }

    // MARK: - Parsing

    private static func splitByHeadings(_ content: String) -> [Chapter] {
        let lines = content.components(separatedBy: "\n")
        var chapters: [Chapter] = []
        var currentTitle = ""
        var currentLines: [String] = []
        var foundFirstHeading = false

        for line in lines {
            if let heading = extractHeading(from: line) {
                if foundFirstHeading {
                    let text = currentLines.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty || !currentTitle.isEmpty {
                        chapters.append(Chapter(
                            title: currentTitle.isEmpty ? "序言" : currentTitle,
                            content: text
                        ))
                    }
                } else {
                    let text = currentLines.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        chapters.append(Chapter(title: "序言", content: text))
                    }
                    foundFirstHeading = true
                }
                currentTitle = heading
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        let lastText = currentLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastText.isEmpty || (!currentTitle.isEmpty && foundFirstHeading) {
            chapters.append(Chapter(
                title: currentTitle.isEmpty ? "正文" : currentTitle,
                content: lastText
            ))
        }

        if chapters.isEmpty {
            chapters.append(Chapter(
                title: "正文",
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        return chapters
    }

    /// Merges chapters whose content is trivially empty (only `---` or whitespace)
    /// into the next chapter, preserving the title as bold header in content.
    private static func consolidateChapters(_ chapters: [Chapter]) -> [Chapter] {
        var result: [Chapter] = []
        var pendingTitles: [String] = []

        for chapter in chapters {
            let meaningful = chapter.content
                .replacingOccurrences(of: "---", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if meaningful.isEmpty {
                pendingTitles.append(chapter.title)
            } else {
                var content = chapter.content
                if !pendingTitles.isEmpty {
                    let header = pendingTitles.map { "**\($0)**" }.joined(separator: "\n")
                    content = header + "\n\n" + content
                    pendingTitles.removeAll()
                }
                result.append(Chapter(title: chapter.title, content: content))
            }
        }

        if !pendingTitles.isEmpty {
            let title = pendingTitles.last ?? "正文"
            result.append(Chapter(title: title, content: ""))
        }

        return result
    }

    /// Comparable sort key for filenames containing Chinese or Arabic numbers.
    static func fileSortKey(_ name: String) -> (Int, String) {
        let chineseMap: [(String, Int)] = [
            ("二十", 20), ("十九", 19), ("十八", 18), ("十七", 17), ("十六", 16),
            ("十五", 15), ("十四", 14), ("十三", 13), ("十二", 12), ("十一", 11),
            ("十", 10), ("九", 9), ("八", 8), ("七", 7), ("六", 6),
            ("五", 5), ("四", 4), ("三", 3), ("二", 2), ("一", 1),
        ]
        for (cn, val) in chineseMap {
            if name.contains("第\(cn)") { return (val, name) }
        }
        var digits = ""
        for char in name {
            if char.isNumber { digits.append(char) }
            else if !digits.isEmpty { break }
        }
        if let num = Int(digits) { return (num, name) }
        return (0, name)
    }

    private static func extractHeading(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .init(charactersIn: " "))
        guard trimmed.hasPrefix("#") else { return nil }

        var level = 0
        for char in trimmed {
            if char == "#" { level += 1 }
            else { break }
        }
        guard level >= 1, level <= 6 else { return nil }

        let rest = String(trimmed.dropFirst(level))
        if !rest.isEmpty, !rest.hasPrefix(" ") { return nil }
        let title = rest.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }
}
