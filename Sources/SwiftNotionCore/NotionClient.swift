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
    
    public func appendBlock(blockId: String, text: String) async throws {
        var request = createRequest(path: "/blocks/\(blockId)/children", method: "PATCH")
        
        // Construct simple paragraph block JSON
        let json: [String: Any] = [
            "children": [
                [
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": [
                        "rich_text": [
                            [
                                "type": "text",
                                "text": [
                                    "content": text
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
             if let errorText = String(data: data, encoding: .utf8) {
                print("Notion API Error: \(errorText)")
            }
            throw NotionError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}
