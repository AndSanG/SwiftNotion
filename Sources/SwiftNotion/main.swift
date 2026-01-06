import Foundation
import ArgumentParser
import SwiftNotionCore

@main
struct SwiftNotion: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A utility to sync files with Notion.",
        subcommands: [Read.self, Write.self, Sync.self]
    )
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
        let text: String
        
        switch block.type {
        case .heading1:
            prefix = "# "
            text = block.heading1?.richText.first?.plainText ?? ""
        case .heading2:
            prefix = "## "
            text = block.heading2?.richText.first?.plainText ?? ""
        case .heading3:
            prefix = "### "
            text = block.heading3?.richText.first?.plainText ?? ""
        case .paragraph:
            prefix = ""
            text = block.paragraph?.richText.first?.plainText ?? ""
        default:
            return // Skip unsupported for now
        }
        
        if !text.isEmpty {
            print("\(prefix)\(text)")
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
        
        // Convert single text to a simple paragraph block
        let block = Block(
            id: UUID().uuidString,
            type: .paragraph,
            hasChildren: false,
            paragraph: TextBlock(richText: [RichText(type: "text", plainText: text, href: nil)]),
            heading1: nil, heading2: nil, heading3: nil
        )
        
        do {
            try await client.appendBlocks(blockId: pageId, blocks: [block])
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
        
        // 1. Read Local File
        let fileURL = URL(fileURLWithPath: filePath)
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            print("Error: Could not read file at \(filePath)")
            return
        }
        
        print("Read \(content.count) bytes from \(fileURL.lastPathComponent)")
        
        // 2. Parse Markdown
        let parser = MarkdownParser()
        let blocks = parser.parse(markdown: content)
        print("Parsed \(blocks.count) blocks.")
        
        if blocks.isEmpty {
            print("No blocks found to sync.")
            return
        }
        
        // 3. Send to Notion
        let client = NotionClient(apiKey: apiKey)
        print("Syncing to Notion page \(pageId)...")
        
        do {
            try await client.appendBlocks(blockId: pageId, blocks: blocks)
            print("Successfully synced!")
        } catch {
            print("Error syncing blocks: \(error)")
        }
    }
}
