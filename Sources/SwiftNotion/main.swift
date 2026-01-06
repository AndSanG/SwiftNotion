import Foundation
import ArgumentParser
import SwiftNotionCore

@main
struct SwiftNotion: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A utility to sync files with Notion.",
        subcommands: [Read.self, Write.self, Sync.self, Test.self]
    )
}

// Helper to print plain text from blocks
func getPlainText(from block: Block) -> String {
    let richText: [RichText]
    if let p = block.paragraph { richText = p.richText }
    else if let h1 = block.heading1 { richText = h1.richText }
    else if let h2 = block.heading2 { richText = h2.richText }
    else if let h3 = block.heading3 { richText = h3.richText }
    else if let b = block.bulletedListItem { richText = b.richText }
    else if let n = block.numberedListItem { richText = n.richText }
    else { return "" }
    
    return richText.map { $0.plainText }.joined()
}

func getRichText(from block: Block) -> [RichText] {
    if let p = block.paragraph { return p.richText }
    else if let h1 = block.heading1 { return h1.richText }
    else if let h2 = block.heading2 { return h2.richText }
    else if let h3 = block.heading3 { return h3.richText }
    else if let b = block.bulletedListItem { return b.richText }
    else if let n = block.numberedListItem { return n.richText }
    return []
}

struct Read: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read content from a Notion page.")
    
    @Argument(help: "The Block/Page ID to read from.")
    var pageId: String
    
    func run() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            print("Error: NOTION_KEY environment variable not set.")
            return
        }
        
        let client = NotionClient(apiKey: apiKey)
        print("Fetching blocks for page: \(pageId)...")
        
        do {
            let blocks = try await client.getBlockChildren(blockId: pageId)
            for block in blocks {
                printBlock(block)
            }
        } catch {
            print("Error fetching blocks: \(error)")
        }
    }
    
    func printBlock(_ block: Block) {
        let prefix: String
        let text = getPlainText(from: block)
        
        switch block.type {
        case .heading1: prefix = "# "
        case .heading2: prefix = "## "
        case .heading3: prefix = "### "
        case .paragraph: prefix = ""
        case .bulletedListItem: prefix = "- "
        case .numberedListItem: prefix = "1. "
        default: return
        }
        
        if !text.isEmpty {
            print("[\(block.id)] \(prefix)\(text)")
        }
    }
}

struct Write: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Append a paragraph to a Notion page.")
    
    @Argument(help: "The Block/Page ID to write to.")
    var pageId: String
    
    @Argument(help: "The text content to append.")
    var text: String
    
    func run() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            print("Error: NOTION_KEY environment variable not set.")
            return
        }
        
        let client = NotionClient(apiKey: apiKey)
        print("Appending to page: \(pageId)...")
        
        let block = Block(
            id: UUID().uuidString,
            type: .paragraph,
            hasChildren: false,
            paragraph: TextBlock(richText: [RichText(type: "text", plainText: text, href: nil)]),
            isNew: true
        )
        
        do {
            _ = try await client.appendBlocks(blockId: pageId, blocks: [block])
            print("Successfully appended block!")
        } catch {
            print("Error appending block: \(error)")
        }
    }
}

struct Sync: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Parse a local Markdown file and append it to Notion.")
    
    @Argument(help: "Path to the local Markdown file.")
    var filePath: String
    
    @Argument(help: "The Block/Page ID to append to.")
    var pageId: String
    
    func run() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            print("Error: NOTION_KEY environment variable not set.")
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            print("Error: Could not read file at \(filePath)")
            return
        }
        
        print("Read \(content.count) bytes from \(fileURL.lastPathComponent)")
        
        let parser = MarkdownParser()
        let blocks = parser.parse(markdown: content)
        print("Parsed \(blocks.count) blocks.")
        
        if blocks.isEmpty {
            print("No blocks found to sync.")
            return
        }
        
        let client = NotionClient(apiKey: apiKey)
        print("Syncing to Notion page \(pageId)...")
        
        var newBlocksBuffer: [Block] = []
        var finalOrderedBlocks: [Block] = []
        
        for block in blocks {
            if block.isNew {
                newBlocksBuffer.append(block)
            } else {
                if !newBlocksBuffer.isEmpty {
                    print("Appending \(newBlocksBuffer.count) new blocks...")
                    let created = try await client.appendBlocks(blockId: pageId, blocks: newBlocksBuffer)
                    finalOrderedBlocks.append(contentsOf: created)
                    newBlocksBuffer.removeAll()
                }
                
                print("Updating block \(block.id)...")
                let richText = getRichText(from: block)
                try await client.updateBlock(blockId: block.id, type: block.type, richText: richText)
                finalOrderedBlocks.append(block)
            }
        }
        
        if !newBlocksBuffer.isEmpty {
             print("Appending \(newBlocksBuffer.count) new blocks...")
             let created = try await client.appendBlocks(blockId: pageId, blocks: newBlocksBuffer)
             finalOrderedBlocks.append(contentsOf: created)
        }
        
        print("Successfully synced! Writing back IDs to \(filePath)...")
        let newContent = serialize(blocks: finalOrderedBlocks)
        try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func serialize(blocks: [Block]) -> String {
        var output = ""
        for block in blocks {
            output += "<!-- notion-id: \(block.id) -->\n"
            
            let text = getPlainText(from: block)
            let prefix: String
            switch block.type {
            case .heading1: prefix = "# "
            case .heading2: prefix = "## "
            case .heading3: prefix = "### "
            case .bulletedListItem: prefix = "- "
            case .numberedListItem: prefix = "1. "
            default: prefix = ""
            }
            
            output += "\(prefix)\(text)\n"
        }
        return output
    }
}

struct Test: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Test parser output.")
    
    @Argument(help: "Path to file.")
    var filePath: String
    
    func run() async throws {
        let fileURL = URL(fileURLWithPath: filePath)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let parser = MarkdownParser()
        let blocks = parser.parse(markdown: content)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(blocks)
        print(String(data: data, encoding: .utf8)!)
    }
}
