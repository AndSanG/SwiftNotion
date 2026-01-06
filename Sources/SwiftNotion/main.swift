import Foundation
import ArgumentParser
import SwiftNotionCore

@main
struct SwiftNotion: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A utility to sync files with Notion.",
        subcommands: [Read.self, Write.self]
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
        
        do {
            try await client.appendBlock(blockId: pageId, text: text)
            print("Successfully appended block!")
        } catch {
            print("Error appending block: \(error)")
        }
    }
}
