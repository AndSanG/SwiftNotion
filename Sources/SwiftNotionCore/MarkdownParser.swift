import Foundation
import Markdown

public class MarkdownParser {
    public init() {}
    
    public func parse(markdown: String) -> [Block] {
        let document = Document(parsing: markdown)
        var walker = NotionBlockWalker()
        walker.visit(document)
        return walker.blocks
    }
}

private struct NotionBlockWalker: MarkupWalker {
    var blocks: [Block] = []
    var pendingId: String? = nil
    
    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        let text = html.rawHTML.trimmingCharacters(in: .whitespacesAndNewlines)
        // Expecting <!-- notion-id: ... -->
        if text.hasPrefix("<!-- notion-id:") && text.hasSuffix("-->") {
            let idPart = text.dropFirst("<!-- notion-id:".count).dropLast("-->".count)
            pendingId = idPart.trimmingCharacters(in: .whitespaces)
        }
    }
    
    mutating func visitHeading(_ heading: Heading) {
        let richText = extractRichText(from: heading)
        let id = pendingId ?? UUID().uuidString
        let isNew = (pendingId == nil)
        
        let type: BlockType
        if heading.level == 1 { type = .heading1 }
        else if heading.level == 2 { type = .heading2 }
        else { type = .heading3 }
        
        let block = Block(
            id: id,
            type: type,
            hasChildren: false,
            heading1: type == .heading1 ? TextBlock(richText: richText) : nil,
            heading2: type == .heading2 ? TextBlock(richText: richText) : nil,
            heading3: type == .heading3 ? TextBlock(richText: richText) : nil,
            isNew: isNew
        )
        blocks.append(block)
        pendingId = nil
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) {
        // Skip paragraphs that are children of ListItems (handled in visitListItem)
        if paragraph.parent is ListItem { return }
        
        let richText = extractRichText(from: paragraph)
        let id = pendingId ?? UUID().uuidString
        let isNew = (pendingId == nil)
        
        let block = Block(
            id: id,
            type: .paragraph,
            hasChildren: false,
            paragraph: TextBlock(richText: richText),
            isNew: isNew
        )
        blocks.append(block)
        pendingId = nil
    }
    
    mutating func visitListItem(_ listItem: ListItem) {
        let richText = extractRichText(from: listItem)
        let id = pendingId ?? UUID().uuidString
        let isNew = (pendingId == nil)
        
        let type: BlockType
        if listItem.parent is UnorderedList {
            type = .bulletedListItem
        } else {
            type = .numberedListItem
        }
        
        let block = Block(
            id: id,
            type: type,
            hasChildren: false,
            bulletedListItem: type == .bulletedListItem ? TextBlock(richText: richText) : nil,
            numberedListItem: type == .numberedListItem ? TextBlock(richText: richText) : nil,
            isNew: isNew
        )
        blocks.append(block)
        pendingId = nil
        
        // Do NOT descend into children, as we've already extracted the text
        // and mapped the ListItem to a Block.
    }
}

// Helper to extract RichText from a Markup node (recursively)
private func extractRichText(from markup: Markup) -> [RichText] {
    var results: [RichText] = []
    
    func visit(_ node: Markup, currentAnnotations: Annotations) {
        for child in node.children {
            if let text = child as? Text {
                results.append(RichText(type: "text", plainText: text.string, href: nil, annotations: currentAnnotations))
            } else if let code = child as? InlineCode {
                var ann = currentAnnotations
                ann.code = true
                // InlineCode doesn't have children, captures text in .code
                results.append(RichText(type: "text", plainText: code.code, href: nil, annotations: ann))
            } else if let strong = child as? Strong {
                var ann = currentAnnotations
                ann.bold = true
                visit(strong, currentAnnotations: ann)
            } else if let emphasis = child as? Emphasis {
                var ann = currentAnnotations
                ann.italic = true
                visit(emphasis, currentAnnotations: ann)
            } else {
                visit(child, currentAnnotations: currentAnnotations)
            }
        }
    }
    
    visit(markup, currentAnnotations: Annotations())
    return results
}
