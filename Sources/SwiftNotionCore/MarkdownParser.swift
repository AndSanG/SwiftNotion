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
                id: id, type: .heading1, hasChildren: false,
                heading1: TextBlock(richText: parseRichText(text)),
                isNew: isNew
            )
        } else if trimmedLine.hasPrefix("## ") {
            let text = String(trimmedLine.dropFirst(3))
            return Block(
                id: id, type: .heading2, hasChildren: false,
                heading2: TextBlock(richText: parseRichText(text)),
                isNew: isNew
            )
        } else if trimmedLine.hasPrefix("### ") {
            let text = String(trimmedLine.dropFirst(4))
            return Block(
                id: id, type: .heading3, hasChildren: false,
                heading3: TextBlock(richText: parseRichText(text)),
                isNew: isNew
            )
        } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") {
             let text = String(trimmedLine.dropFirst(2))
             return Block(
                 id: id, type: .bulletedListItem, hasChildren: false,
                 bulletedListItem: TextBlock(richText: parseRichText(text)),
                 isNew: isNew
             )
        } else if trimmedLine.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
            // Find end of number prefix
            let components = trimmedLine.components(separatedBy: ".")
             // Simple hack: drop until first space
             // Ideally regex match range, but let's assume "1. "
             let parts = trimmedLine.split(separator: " ", maxSplits: 1)
             let text = parts.count > 1 ? String(parts[1]) : ""
             
             return Block(
                 id: id, type: .numberedListItem, hasChildren: false,
                 numberedListItem: TextBlock(richText: parseRichText(text)),
                 isNew: isNew
             )
         } else if !trimmedLine.isEmpty {
            return Block(
                id: id, type: .paragraph, hasChildren: false,
                paragraph: TextBlock(richText: parseRichText(trimmedLine)),
                isNew: isNew
            )
        }
        
        return nil
    }
    
    // Very basic markdown inline parser
    // Supports **bold**, *italic*, `code`
    private func parseRichText(_ text: String) -> [RichText] {
        var results: [RichText] = []
        var currentText = ""
        var i = text.startIndex
        
        var isBold = false
        var isItalic = false
        var isCode = false
        
        while i < text.endIndex {
            let char = text[i]
            let nextIndex = text.index(after: i)
            let nextChar = (nextIndex < text.endIndex) ? text[nextIndex] : "\0"
            
            // Bold (** or __) - Simplified to **
            if !isCode && char == "*" && nextChar == "*" {
                if !currentText.isEmpty {
                    results.append(RichText(type: "text", plainText: currentText, href: nil, annotations: Annotations(bold: isBold, italic: isItalic, code: isCode)))
                    currentText = ""
                }
                isBold.toggle()
                i = text.index(i, offsetBy: 2)
                continue
            }
            
            // Italic (*) - Simplified
            if !isCode && char == "*" {
                if !currentText.isEmpty {
                    results.append(RichText(type: "text", plainText: currentText, href: nil, annotations: Annotations(bold: isBold, italic: isItalic, code: isCode)))
                    currentText = ""
                }
                isItalic.toggle()
                i = nextIndex
                continue
            }
            
            // Code (`)
            if char == "`" {
                if !currentText.isEmpty {
                    results.append(RichText(type: "text", plainText: currentText, href: nil, annotations: Annotations(bold: isBold, italic: isItalic, code: isCode)))
                    currentText = ""
                }
                isCode.toggle()
                i = nextIndex
                continue
            }
            
            currentText.append(char)
            i = nextIndex
        }
        
        if !currentText.isEmpty {
            results.append(RichText(type: "text", plainText: currentText, href: nil, annotations: Annotations(bold: isBold, italic: isItalic, code: isCode)))
        }
        
        return results
    }
}
