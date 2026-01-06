import Foundation

// MARK: - API Response Wrapper
public struct NotionList<T: Codable>: Codable {
    public let object: String
    public let results: [T]
}

// MARK: - Block
public struct Block: Codable, Identifiable {
    public let id: String
    public let type: BlockType
    public let hasChildren: Bool
    
    // We only decode specific block content based on type
    public let paragraph: TextBlock?
    public let heading1: TextBlock?
    public let heading2: TextBlock?
    public let heading3: TextBlock?
    
    enum CodingKeys: String, CodingKey {
        case id, type, paragraph
        case hasChildren = "has_children"
        case heading1 = "heading_1"
        case heading2 = "heading_2"
        case heading3 = "heading_3"
    }
}

public enum BlockType: String, Codable {
    case paragraph
    case heading1 = "heading_1"
    case heading2 = "heading_2"
    case heading3 = "heading_3"
    case unsupported
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = BlockType(rawValue: rawValue) ?? .unsupported
    }
}

// MARK: - Text Content
public struct TextBlock: Codable {
    public let richText: [RichText]
    
    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
    }
}

public struct RichText: Codable {
    public let type: String
    public let plainText: String
    public let href: String?
    
    enum CodingKeys: String, CodingKey {
        case type, href
        case plainText = "plain_text"
    }
}

// MARK: - Page
public struct Page: Codable, Identifiable {
    public let id: String
    public let url: String
}
