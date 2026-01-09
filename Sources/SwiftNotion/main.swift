import Foundation
import ArgumentParser
import SwiftNotionCore
@preconcurrency import NotionSwift

@main
struct SwiftNotion: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A utility to sync files with Notion.",
        subcommands: [Read.self, Write.self, Sync.self, Test.self]
    )
}

// MARK: - Async Wrappers
extension NotionClient {
    func blockChildren(blockId: Block.Identifier) async throws -> ListResponse<ReadBlock> {
        return try await withCheckedThrowingContinuation { continuation in
            self.blockChildren(blockId: blockId, params: .init()) { result in
                continuation.resume(with: result)
            }
        }
    }

    func blockAppend(blockId: Block.Identifier, children: [WriteBlock]) async throws -> ListResponse<ReadBlock> {
        return try await withCheckedThrowingContinuation { continuation in
            self.blockAppend(blockId: blockId, children: children) { result in
                continuation.resume(with: result)
            }
        }
    }

    func blockUpdate(blockId: Block.Identifier, value: UpdateBlock) async throws -> ReadBlock {
        return try await withCheckedThrowingContinuation { continuation in
            self.blockUpdate(blockId: blockId, value: value) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// Helper to print plain text from blocks
func getPlainText(from type: BlockType) -> String {
    let richText: [RichText]
    switch type {
    case .paragraph(let value): richText = value.richText
    case .heading1(let value): richText = value.richText
    case .heading2(let value): richText = value.richText
    case .heading3(let value): richText = value.richText
    case .bulletedListItem(let value): richText = value.richText
    case .numberedListItem(let value): richText = value.richText
    case .toDo(let value): richText = value.richText
    case .quote(let value): richText = value.richText
    case .code(let value): richText = value.richText
    default: return ""
    }
    
    return richText.compactMap { $0.plainText }.joined()
}

func getRichText(from type: BlockType) -> [RichText] {
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

struct Read: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read content from a Notion page.")
    
    @Argument(help: "The Block/Page ID to read from.")
    var pageId: String
    
    func run() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            print("Error: NOTION_KEY environment variable not set.")
            return
        }
        
        let client = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey: apiKey))
        print("Fetching blocks for page: \(pageId)...")
        
        do {
            let blocks = try await client.blockChildren(blockId: Block.Identifier(pageId))
            for block in blocks.results {
                printBlock(block)
            }
        } catch {
            print("Error fetching blocks: \(error)")
        }
    }
    
    func printBlock(_ block: ReadBlock) {
        let prefix: String
        let text = getPlainText(from: block.type)
        
        switch block.type {
        case .heading1: prefix = "# "
        case .heading2: prefix = "## "
        case .heading3: prefix = "### "
        case .paragraph: prefix = ""
        case .bulletedListItem: prefix = "- "
        case .numberedListItem: prefix = "1. "
        case .quote: prefix = "> "
        case .toDo(let value):
            let checked = value.checked ?? false
            prefix = checked ? "- [x] " : "- [ ] "
        case .code: prefix = ""
        default: return
        }
        
        if case .code(let value) = block.type {
             let lang = value.language ?? ""
             print("[\(block.id)] ```\(lang)")
             print("\(text)")
             print("```")
        } else if !text.isEmpty {
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
        
        let client = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey: apiKey))
        print("Appending to page: \(pageId)...")
        
        let blockType = BlockType.paragraph(BlockType.TextAndChildrenBlockValue(richText: [RichText(string: text)], color: .default))
        let writeBlock = WriteBlock(type: blockType)
        
        do {
            _ = try await client.blockAppend(blockId: Block.Identifier(pageId), children: [writeBlock])
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
        
        // 1. Check if file exists
        let fileURL = URL(fileURLWithPath: filePath)
        let fileExists = FileManager.default.fileExists(atPath: filePath)
        let client = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey: apiKey))
        
        if !fileExists {
            print("File not found at \(filePath). Fetching content from Notion page \(pageId)...")
            do {
                let fetched = try await client.blockChildren(blockId: Block.Identifier(pageId))
                let parsedBlocks = fetched.results.map { ParsedBlock(id: $0.id.rawValue, type: $0.type, isNew: false) }
                
                if parsedBlocks.isEmpty {
                    print("Notion page is empty. Creating empty file.")
                    try "".write(to: fileURL, atomically: true, encoding: .utf8)
                } else {
                    print("Fetched \(parsedBlocks.count) blocks. Writing to \(fileURL.lastPathComponent)...")
                    let content = serialize(blocks: parsedBlocks)
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                }
                print("Successfully created local file!")
                return
            } catch {
                print("Error fetching content to create file: \(error)")
                return
            }
        }
        
        // 2. File exists, proceed with Sync (Read -> Parse -> Push)
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
        
        print("Syncing to Notion page \(pageId)...")
        
        var newBlocksBuffer: [WriteBlock] = []
        var finalOrderedBlocks: [ParsedBlock] = []
        
        for block in blocks {
            if block.isNew {
                newBlocksBuffer.append(WriteBlock(type: block.type))
            } else {
                if !newBlocksBuffer.isEmpty {
                    print("Appending \(newBlocksBuffer.count) new blocks...")
                    let createdList = try await client.blockAppend(blockId: Block.Identifier(pageId), children: newBlocksBuffer)
                    let createdParsed = createdList.results.map { ParsedBlock(id: $0.id.rawValue, type: $0.type, isNew: false) }
                    finalOrderedBlocks.append(contentsOf: createdParsed)
                    newBlocksBuffer.removeAll()
                }
                
                print("Updating block \(block.id)...")
                _ = try await client.blockUpdate(blockId: Block.Identifier(block.id), value: UpdateBlock(type: block.type))
                finalOrderedBlocks.append(block)
            }
        }
        
        if !newBlocksBuffer.isEmpty {
             print("Appending \(newBlocksBuffer.count) new blocks...")
             let createdList = try await client.blockAppend(blockId: Block.Identifier(pageId), children: newBlocksBuffer)
             let createdParsed = createdList.results.map { ParsedBlock(id: $0.id.rawValue, type: $0.type, isNew: false) }
             finalOrderedBlocks.append(contentsOf: createdParsed)
        }
        
        print("Successfully synced! Writing back IDs to \(filePath)...")
        let newContent = serialize(blocks: finalOrderedBlocks)
        try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func serialize(blocks: [ParsedBlock]) -> String {
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
    
    func serializeRichTextToMarkdown(_ richText: [RichText]) -> String {
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

struct Test: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Test parser output.")
    
    @Argument(help: "Path to file.")
    var filePath: String
    
    func run() async throws {
        let fileURL = URL(fileURLWithPath: filePath)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let parser = MarkdownParser()
        let blocks = parser.parse(markdown: content)
        
        print("Parsed \(blocks.count) blocks.")
        for b in blocks {
            print(b.id, b.type)
        }
    }
}
