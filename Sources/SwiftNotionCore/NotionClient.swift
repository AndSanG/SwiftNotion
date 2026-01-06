import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum NotionError: Error {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed(Error)
    case encodingFailed(Error)
}

public class NotionClient {
    private let apiKey: String
    private let session: URLSession
    private let baseURL = URL(string: "https://api.notion.com/v1")!
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }
    
    private func createRequest(path: String, method: String) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    // MARK: - Public API
    
    public func getBlockChildren(blockId: String) async throws -> [Block] {
        let request = createRequest(path: "/blocks/\(blockId)/children", method: "GET")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionError.requestFailed(statusCode: -1)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorText = String(data: data, encoding: .utf8) {
                print("Notion API Error: \(errorText)")
            }
            throw NotionError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        do {
            let list = try JSONDecoder().decode(NotionList<Block>.self, from: data)
            return list.results
        } catch {
            throw NotionError.decodingFailed(error)
        }
    }
    
    public func appendBlocks(blockId: String, blocks: [Block]) async throws {
        var request = createRequest(path: "/blocks/\(blockId)/children", method: "PATCH")
        
        let childrenJSON = blocks.map { block -> [String: Any] in
            var blockJSON: [String: Any] = [
                "object": "block",
                "type": block.type.rawValue
            ]
            
            // Construct the specific block content
            // Note: This matches the structure expected by Notion API
            if let paragraph = block.paragraph {
                blockJSON["paragraph"] = [
                    "rich_text": paragraph.richText.map { ["type": $0.type, "text": ["content": $0.plainText]] }
                ]
            } else if let h1 = block.heading1 {
                blockJSON["heading_1"] = [
                    "rich_text": h1.richText.map { ["type": $0.type, "text": ["content": $0.plainText]] }
                ]
            } else if let h2 = block.heading2 {
                blockJSON["heading_2"] = [
                    "rich_text": h2.richText.map { ["type": $0.type, "text": ["content": $0.plainText]] }
                ]
            } else if let h3 = block.heading3 {
                blockJSON["heading_3"] = [
                    "rich_text": h3.richText.map { ["type": $0.type, "text": ["content": $0.plainText]] }
                ]
            }
            
            return blockJSON
        }
        
        let json: [String: Any] = ["children": childrenJSON]
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
             if let errorText = String(data: data, encoding: .utf8) {
                print("Notion API Error: \(errorText)")
            }
            throw NotionError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    public func updateBlock(blockId: String, type: BlockType, text: String) async throws {
        var request = createRequest(path: "/blocks/\(blockId)", method: "PATCH")
        
        var blockJSON: [String: Any] = [
             "object": "block",
             "type": type.rawValue
         ]
         
         let richText = [["type": "text", "text": ["content": text]]]
         
         if type == .paragraph {
             blockJSON["paragraph"] = ["rich_text": richText]
         } else if type == .heading1 {
             blockJSON["heading_1"] = ["rich_text": richText]
         } else if type == .heading2 {
             blockJSON["heading_2"] = ["rich_text": richText]
         } else if type == .heading3 {
             blockJSON["heading_3"] = ["rich_text": richText]
         }
         
         request.httpBody = try JSONSerialization.data(withJSONObject: blockJSON)
         
         let (data, response) = try await session.data(for: request)
         
         guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
              if let errorText = String(data: data, encoding: .utf8) {
                 print("Notion API Error: \(errorText)")
             }
             throw NotionError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
         }
    }
}
