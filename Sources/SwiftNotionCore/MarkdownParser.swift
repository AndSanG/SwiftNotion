import Foundation
import Markdown
import NotionSwift

public class MarkdownParser {
    
    public init() {}
    
    public func parse(markdown: String) -> [ParsedBlock] {
        let document = Document(parsing: markdown)
        var blocks: [ParsedBlock] = []
        var pendingId: String? = nil
        
        let nodes = flattenNodes(document.children)
        
        for node in nodes {
            if let html = node as? HTMLBlock {
                if let id = extractId(from: html.rawHTML) {
                    pendingId = id
                }
                continue
            }
            
            if let block = visit(node, id: pendingId) {
                blocks.append(block)
                pendingId = nil
            }
        }
        
        return blocks
    }
    
    private func flattenNodes(_ children: Markdown.MarkupChildren) -> [Markup] {
        var result: [Markup] = []
        for child in children {
            if let uList = child as? UnorderedList {
                result.append(contentsOf: flattenNodes(uList.children))
            } else if let oList = child as? OrderedList {
                result.append(contentsOf: flattenNodes(oList.children))
            } else if let listItem = child as? ListItem {
                result.append(listItem)
            } else {
                result.append(child)
            }
        }
        return result
    }
    
    private func extractId(from text: String) -> String? {
        let key = "<!-- notion-id: "
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(key) {
             let start = text.range(of: key)?.upperBound
             let end = text.range(of: " -->", options: .backwards)?.lowerBound
             if let s = start, let e = end, s < e {
                 return String(text[s..<e])
             }
        }
        return nil
    }
    
    private func visit(_ node: Markup, id: String?) -> ParsedBlock? {
        let finalId = id ?? UUID().uuidString
        let isNew = (id == nil)
        var type: BlockType?
        
        let rt = extractRichText(from: node)
        
        if let heading = node as? Heading {
            switch heading.level {
            case 1: type = .heading1(BlockType.HeadingBlockValue(richText: rt, color: .default, isToggleable: false))
            case 2: type = .heading2(BlockType.HeadingBlockValue(richText: rt, color: .default, isToggleable: false))
            case 3: type = .heading3(BlockType.HeadingBlockValue(richText: rt, color: .default, isToggleable: false))
            default: type = .paragraph(BlockType.TextAndChildrenBlockValue(richText: rt, color: .default))
            }
        } else if let _ = node as? Paragraph {
            type = .paragraph(BlockType.TextAndChildrenBlockValue(richText: rt, color: .default))
        } else if let _ = node as? BlockQuote {
            type = .quote(BlockType.QuoteBlockValue(richText: rt, color: .default))
        } else if let codeBlock = node as? CodeBlock {
            // NotionSwift CodeBlockValue init requires richText array and language
            let codeText = [RichText(string: codeBlock.code)]
            type = .code(BlockType.CodeBlockValue(richText: codeText, language: codeBlock.language))
        } else if let listItem = node as? ListItem {
            let checked = (listItem.checkbox == .checked)
            let itemRT = extractRichText(from: listItem)
            
            if listItem.checkbox != nil {
                type = .toDo(BlockType.ToDoBlockValue(richText: itemRT, checked: checked, color: .default))
            } else {
                type = .bulletedListItem(BlockType.TextAndChildrenBlockValue(richText: itemRT, color: .default))
            }
        }
        
        if let t = type {
            return ParsedBlock(id: finalId, type: t, isNew: isNew)
        }
        
        return nil
    }

    private func extractRichText(from node: Markup) -> [RichText] {
        var results: [RichText] = []
        
        func walk(_ markup: Markup) {
            for child in markup.children {
                if let text = child as? Text {
                    results.append(RichText(string: text.string))
                } else if let code = child as? InlineCode {
                    results.append(RichText(string: code.code, annotations: .code))
                } else if let strong = child as? Strong {
                    let plain = child.children.compactMap { ($0 as? Text)?.string }.joined()
                     results.append(RichText(string: plain, annotations: .bold))
                } else if let emphasis = child as? Emphasis {
                    let plain = child.children.compactMap { ($0 as? Text)?.string }.joined()
                    results.append(RichText(string: plain, annotations: .italic))
                } else {
                   if child.childCount > 0 {
                       walk(child)
                   }
                }
            }
        }
        
        walk(node)
        return results
    }
}
