import Foundation
import ArgumentParser
import SwiftNotionCore
@preconcurrency import NotionSwift

struct DotEnv {
    static func load(path: String = ".env") {
        let url = URL(fileURLWithPath: path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                setenv(key, value, 1)
            }
        }
    }
}

@main
struct SwiftNotion: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A utility to sync files with Notion.",
        subcommands: [Pull.self, Push.self, Sync.self, Delete.self, Test.self]
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
    
    func pageCreate(request: PageCreateRequest) async throws -> Page {
        return try await withCheckedThrowingContinuation { continuation in
            self.pageCreate(request: request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func pageUpdate(pageId: Page.Identifier, request: PageUpdateRequest) async throws -> Page {
        return try await withCheckedThrowingContinuation { continuation in
            self.pageUpdate(pageId: pageId, request: request) { result in
                 continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Commands

struct Pull: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Pull Notion page into Git repository (Read).")
    
    @Argument(help: "The Page ID to pull.")
    var pageId: String
    
    @Argument(help: "The local file path to save to.")
    var filePath: String
    
    func run() async throws {
        DotEnv.load()
        guard let apiKey = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            print("Error: NOTION_KEY not set.")
            return
        }
        
        let client = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey: apiKey))
        let fileURL = URL(fileURLWithPath: filePath)
        
        print("Pulling page \(pageId) to \(filePath)...")
        
        do {
            let fetched = try await client.blockChildren(blockId: Block.Identifier(pageId))
            let parsedBlocks = fetched.results.map { ParsedBlock(id: $0.id.rawValue, type: $0.type, isNew: false) }
            
            let serializer = MarkdownSerializer()
            let content = serializer.serialize(blocks: parsedBlocks)
            try content.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            print("Successfully pulled!")
        } catch {
            print("Error pulling page: \(error)")
        }
    }
}

struct Push: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create Notion page from Git repository (Create).")
    
    @Argument(help: "Path to the local Markdown file.")
    var filePath: String
    
    @Argument(help: "The Parent Page/Database ID.")
    var parentId: String
    
    func run() async throws {
        DotEnv.load()
        guard let apiKey = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            print("Error: NOTION_KEY not set.")
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        let content = try String(contentsOf: fileURL, encoding: String.Encoding.utf8)
        
        let parser = MarkdownParser()
        let blocks = parser.parse(markdown: content)
        
        let client = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey: apiKey))
        
        // Extract title from first H1 or filename
        var title = fileURL.deletingPathExtension().lastPathComponent
        if case .heading1(let value) = blocks.first?.type {
             title = value.richText.compactMap { $0.plainText }.joined()
        }
        
        print("Creating new page '\(title)' in parent \(parentId)...")
        
        let writeBlocks = blocks.map { WriteBlock(type: $0.type) }
        
        let request = PageCreateRequest(
            parent: .page(Page.Identifier(parentId)),
            properties: ["title": WritePageProperty(type: .title([RichText(string: title)]))],
            children: writeBlocks
        )
        
        do {
            let newPage = try await client.pageCreate(request: request)
            
            print("Successfully created page: \(newPage.id.rawValue)")
            
            // Re-fetch blocks to get their IDs and write back to file
            let fetched = try await client.blockChildren(blockId: Block.Identifier(newPage.id.rawValue))
            let finalBlocks = fetched.results.map { ParsedBlock(id: $0.id.rawValue, type: $0.type, isNew: false) }
            
            let serializer = MarkdownSerializer()
            let newContent = serializer.serialize(blocks: finalBlocks)
            try newContent.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            print("Updated local file with Notion IDs.")
        } catch {
            print("Error creating page: \(error)")
        }
    }
}

struct Sync: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Update Notion page from Git repository (Update).")
    
    @Argument(help: "Path to the local Markdown file.")
    var filePath: String
    
    @Argument(help: "The Page ID to update.")
    var pageId: String
    
    func run() async throws {
        DotEnv.load()
        guard let apiKey = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            print("Error: NOTION_KEY not set.")
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        let content = try String(contentsOf: fileURL, encoding: String.Encoding.utf8)
        
        let parser = MarkdownParser()
        let blocks = parser.parse(markdown: content)
        
        let client = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey: apiKey))
        print("Syncing updates to Notion page \(pageId)...")
        
        var finalOrderedBlocks: [ParsedBlock] = []
        var newBlocksBuffer: [WriteBlock] = []
        
        do {
            for block in blocks {
                if block.isNew {
                    newBlocksBuffer.append(WriteBlock(type: block.type))
                } else {
                    if !newBlocksBuffer.isEmpty {
                        let createdList = try await client.blockAppend(blockId: Block.Identifier(pageId), children: newBlocksBuffer)
                        finalOrderedBlocks.append(contentsOf: createdList.results.map { ParsedBlock(id: $0.id.rawValue, type: $0.type) })
                        newBlocksBuffer.removeAll()
                    }
                    
                    _ = try await client.blockUpdate(blockId: Block.Identifier(block.id), value: UpdateBlock(type: block.type))
                    finalOrderedBlocks.append(block)
                }
            }
            
            if !newBlocksBuffer.isEmpty {
                let createdList = try await client.blockAppend(blockId: Block.Identifier(pageId), children: newBlocksBuffer)
                finalOrderedBlocks.append(contentsOf: createdList.results.map { ParsedBlock(id: $0.id.rawValue, type: $0.type) })
            }
            
            let serializer = MarkdownSerializer()
            let updatedContent = serializer.serialize(blocks: finalOrderedBlocks)
            try updatedContent.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            print("Successfully synced updates!")
        } catch {
            print("Error syncing: \(error)")
        }
    }
}

struct Delete: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Delete Notion page from Git repository (Delete).")
    
    @Argument(help: "The Page ID to archive.")
    var pageId: String
    
    func run() async throws {
        DotEnv.load()
        guard let apiKey = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            print("Error: NOTION_KEY not set.")
            return
        }
        
        let client = NotionClient(accessKeyProvider: StringAccessKeyProvider(accessKey: apiKey))
        print("Archiving page \(pageId)...")
        
        do {
            let request = PageUpdateRequest(archived: true)
            _ = try await client.pageUpdate(pageId: Page.Identifier(pageId), request: request)
            print("Page archived successfully.")
        } catch {
            print("Error archiving page: \(error)")
        }
    }
}

struct Test: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Test parser output.")
    
    @Argument(help: "Path to file.")
    var filePath: String
    
    func run() async throws {
        let fileURL = URL(fileURLWithPath: filePath)
        let content = try String(contentsOf: fileURL, encoding: String.Encoding.utf8)
        let parser = MarkdownParser()
        let blocks = parser.parse(markdown: content)
        
        print("Parsed \(blocks.count) blocks.")
        for b in blocks {
            print(b.id, b.type)
        }
    }
}
