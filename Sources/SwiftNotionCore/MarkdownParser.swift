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
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        let richText = extractRichText(from: blockQuote)
        let id = pendingId ?? UUID().uuidString
        let isNew = (pendingId == nil)
        
        let block = Block(
            id: id,
            type: .quote,
            hasChildren: false,
            quote: QuoteBlock(richText: richText),
            isNew: isNew
        )
        blocks.append(block)
        pendingId = nil
    }
    
    mutating func visitCodeBlock(_ codeBlock: Markdown.CodeBlock) {
        let text = codeBlock.code
        let language = codeBlock.language ?? "plain text"
        let id = pendingId ?? UUID().uuidString
        let isNew = (pendingId == nil)
        
        let block = Block(
            id: id,
            type: .code,
            hasChildren: false,
            code: SwiftNotionCore.CodeBlock(richText: [RichText(type: "text", plainText: text, href: nil)], language: language),
            isNew: isNew
        )
        blocks.append(block)
        pendingId = nil
    }
    
    mutating func visitListItem(_ listItem: ListItem) {
        let richText = extractRichText(from: listItem)
        let id = pendingId ?? UUID().uuidString
        let isNew = (pendingId == nil)
        
        // Check if it's a To-Do item (hacky check on start of text? 
        // actually swift-markdown doesn't explicitly parse [ ] as a task list item unless GFM is fully enabled and we check the checkbox state)
        // BUT, swift-markdown ListItem has a `checkbox` property!
        
        var type: BlockType?
        var checked: Bool?
        
        if let checkbox = listItem.checkbox {
            type = .toDo
            checked = (checkbox == .checked)
        } else if listItem.parent is UnorderedList {
            type = .bulletedListItem
        } else {
            type = .numberedListItem
        }
        
        guard let finalType = type else { return }
        
        let block = Block(
            id: id,
            type: finalType,
            hasChildren: false,
            bulletedListItem: finalType == .bulletedListItem ? TextBlock(richText: richText) : nil,
            numberedListItem: finalType == .numberedListItem ? TextBlock(richText: richText) : nil,
            toDo: finalType == .toDo ? ToDoBlock(richText: richText, checked: checked ?? false) : nil,
            isNew: isNew
        )
        blocks.append(block)
        pendingId = nil
        
        // Do NOT descend into children
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
