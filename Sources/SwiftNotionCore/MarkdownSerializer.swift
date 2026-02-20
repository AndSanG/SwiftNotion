import Foundation
import NotionSwift

public class MarkdownSerializer {
    
    public init() {}
    
    public func serialize(blocks: [ParsedBlock]) -> String {
        var output = ""
        for block in blocks {
            output += "<!-- notion-id: \(block.id) -->\n"
            
            let type = block.type
            let text: String
            
            if case .code(let value) = type {
                let lang = value.language ?? ""
                let codeContent = value.richText.compactMap { $0.plainText }.joined()
                output += "```\(lang)\n\(codeContent)\n```\n"
                continue
            }
            
            let richText = getRichText(from: type)
            text = serializeRichTextToMarkdown(richText)
            
            let prefix: String
            switch type {
            case .heading1: prefix = "# "
            case .heading2: prefix = "## "
            case .heading3: prefix = "### "
            case .bulletedListItem: prefix = "- "
            case .numberedListItem: prefix = "1. "
            case .quote: prefix = "> "
            case .toDo(let v):
                 let checked = v.checked ?? false
                 prefix = checked ? "- [x] " : "- [ ] "
            default: prefix = ""
            }
            
            output += "\(prefix)\(text)\n"
        }
        return output
    }
    
    private func getRichText(from type: BlockType) -> [RichText] {
        switch type {
        case .paragraph(let value): return value.richText
        case .heading1(let value): return value.richText
        case .heading2(let value): return value.richText
        case .heading3(let value): return value.richText
        case .bulletedListItem(let value): return value.richText
        case .numberedListItem(let value): return value.richText
        case .toDo(let value): return value.richText
        case .quote(let value): return value.richText
        case .code(let value): return value.richText
        default: return []
        }
    }
    
    private func serializeRichTextToMarkdown(_ richText: [RichText]) -> String {
        return richText.map { rt in
            var text = rt.plainText ?? ""
            let ann = rt.annotations
            if ann.code { text = "`\(text)`" }
            if ann.italic { text = "*\(text)*" }
            if ann.bold { text = "**\(text)**" }
            return text
        }.joined()
    }
}
