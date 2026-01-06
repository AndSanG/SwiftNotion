import Foundation

public struct MarkdownParser {
    public init() {}
    
    public func parse(markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: .newlines)
        return lines.map { parseLine($0) }.compactMap { $0 }
    }
    
    private func parseLine(_ line: String) -> Block? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let id = UUID().uuidString
        
        if trimmedLine.hasPrefix("# ") {
            let text = String(trimmedLine.dropFirst(2))
            return Block(
                id: id,
                type: .heading1,
                hasChildren: false,
                paragraph: nil,
                heading1: TextBlock(richText: [RichText(type: "text", plainText: text, href: nil)]),
                heading2: nil,
                heading3: nil
            )
        } else if trimmedLine.hasPrefix("## ") {
            let text = String(trimmedLine.dropFirst(3))
            return Block(
                id: id,
                type: .heading2,
                hasChildren: false,
                paragraph: nil,
                heading1: nil,
                heading2: TextBlock(richText: [RichText(type: "text", plainText: text, href: nil)]),
                heading3: nil
            )
        } else if trimmedLine.hasPrefix("### ") {
            let text = String(trimmedLine.dropFirst(4))
            return Block(
                id: id,
                type: .heading3,
                hasChildren: false,
                paragraph: nil,
                heading1: nil,
                heading2: nil,
                heading3: TextBlock(richText: [RichText(type: "text", plainText: text, href: nil)])
            )
        } else if !trimmedLine.isEmpty {
            return Block(
                id: id,
                type: .paragraph,
                hasChildren: false,
                paragraph: TextBlock(richText: [RichText(type: "text", plainText: trimmedLine, href: nil)]),
                heading1: nil,
                heading2: nil,
                heading3: nil
            )
        }
        
        return nil
    }
}
