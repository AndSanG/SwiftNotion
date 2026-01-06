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
    
    private func serializeRichText(_ richText: [RichText]) -> [[String: Any]] {
        return richText.map { text in
            var dict: [String: Any] = [
                "type": text.type,
                "text": ["content": text.plainText]
            ]
            
            if let annotations = text.annotations {
                dict["annotations"] = [
                    "bold": annotations.bold,
                    "italic": annotations.italic,
                    "strikethrough": annotations.strikethrough,
                    "underline": annotations.underline,
                    "code": annotations.code,
                    "color": annotations.color
                ]
            }
            
            return dict
        }
    }

    public func appendBlocks(blockId: String, blocks: [Block]) async throws -> [Block] {
        var request = createRequest(path: "/blocks/\(blockId)/children", method: "PATCH")
        
        let childrenJSON = blocks.map { block -> [String: Any] in
            var blockJSON: [String: Any] = [
                "object": "block",
                "type": block.type.rawValue
            ]
            
            if let paragraph = block.paragraph {
                blockJSON["paragraph"] = ["rich_text": serializeRichText(paragraph.richText)]
            } else if let h1 = block.heading1 {
                blockJSON["heading_1"] = ["rich_text": serializeRichText(h1.richText)]
            } else if let h2 = block.heading2 {
                blockJSON["heading_2"] = ["rich_text": serializeRichText(h2.richText)]
            } else if let h3 = block.heading3 {
                blockJSON["heading_3"] = ["rich_text": serializeRichText(h3.richText)]
            } else if let bullet = block.bulletedListItem {
                blockJSON["bulleted_list_item"] = ["rich_text": serializeRichText(bullet.richText)]
            } else if let numbered = block.numberedListItem {
                blockJSON["numbered_list_item"] = ["rich_text": serializeRichText(numbered.richText)]
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
        
        do {
            let list = try JSONDecoder().decode(NotionList<Block>.self, from: data)
            return list.results
        } catch {
            throw NotionError.decodingFailed(error)
        }
    }

    public func updateBlock(blockId: String, type: BlockType, text: String) async throws {
        // NOTE: text argument is deprecated in favor of Rich Text parsing, 
        // but for now we will wrap it in a basic RichText object.
        // Ideally we should pass [RichText] to updateBlock.
        // I'll overload or update this method.
        // For backwards compatibility let's parse basic text.
        // Actually, main.swift needs to pass RichText now.
        // Let's assume text is plain text for now, or update main later.
        
        // Wait, markdown parser produces [RichText].
        // So updateBlock should accept [RichText], not String.
        // Let's update the signature.
       fatalError("Use updated updateBlock(blockId:type:richText:) instead")
    }

    public func updateBlock(blockId: String, type: BlockType, richText: [RichText]) async throws {
        var request = createRequest(path: "/blocks/\(blockId)", method: "PATCH")
        
        var blockJSON: [String: Any] = [
             "object": "block",
             "type": type.rawValue
         ]
         
         let serializedText = serializeRichText(richText)
         
         if type == .paragraph {
             blockJSON["paragraph"] = ["rich_text": serializedText]
         } else if type == .heading1 {
             blockJSON["heading_1"] = ["rich_text": serializedText]
         } else if type == .heading2 {
             blockJSON["heading_2"] = ["rich_text": serializedText]
         } else if type == .heading3 {
             blockJSON["heading_3"] = ["rich_text": serializedText]
         } else if type == .bulletedListItem {
             blockJSON["bulleted_list_item"] = ["rich_text": serializedText]
         } else if type == .numberedListItem {
             blockJSON["numbered_list_item"] = ["rich_text": serializedText]
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
