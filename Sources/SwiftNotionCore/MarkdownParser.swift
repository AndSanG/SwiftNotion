import Foundation

public struct MarkdownParser {
    public init() {}
    
    public func parse(markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [Block] = []
        var pendingId: String? = nil
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for ID comment: <!-- notion-id: ... -->
            if trimmed.hasPrefix("<!-- notion-id:") && trimmed.hasSuffix("-->") {
                let idPart = trimmed.dropFirst("<!-- notion-id:".count).dropLast("-->".count)
                pendingId = idPart.trimmingCharacters(in: .whitespaces)
                continue
            }
            
            if let block = parseLine(line, forceId: pendingId) {
                blocks.append(block)
                pendingId = nil // Consumed the ID
            }
        }
        
        return blocks
    }
    
    private func parseLine(_ line: String, forceId: String?) -> Block? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        let id = forceId ?? UUID().uuidString
        let isNew = (forceId == nil)
        
        if trimmedLine.hasPrefix("# ") {
            let text = String(trimmedLine.dropFirst(2))
            return Block(
                id: id,
                type: .heading1,
                hasChildren: false,
                paragraph: nil,
                heading1: TextBlock(richText: [RichText(type: "text", plainText: text, href: nil)]),
                heading2: nil,
                heading3: nil,
                isNew: isNew
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
                heading3: nil,
                isNew: isNew
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
                heading3: TextBlock(richText: [RichText(type: "text", plainText: text, href: nil)]),
                isNew: isNew
            )
        } else if !trimmedLine.isEmpty {
            return Block(
                id: id,
                type: .paragraph,
                hasChildren: false,
                paragraph: TextBlock(richText: [RichText(type: "text", plainText: trimmedLine, href: nil)]),
                heading1: nil,
                heading2: nil,
                heading3: nil,
                isNew: isNew
            )
        }
        
        return nil
    }
}
