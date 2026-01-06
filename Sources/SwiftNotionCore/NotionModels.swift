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
    
    public let paragraph: TextBlock?
    public let heading1: TextBlock?
    public let heading2: TextBlock?
    public let heading3: TextBlock?
    
    public init(id: String, type: BlockType, hasChildren: Bool, paragraph: TextBlock? = nil, heading1: TextBlock? = nil, heading2: TextBlock? = nil, heading3: TextBlock? = nil) {
        self.id = id
        self.type = type
        self.hasChildren = hasChildren
        self.paragraph = paragraph
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
    }
    
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
    
    public init(richText: [RichText]) {
        self.richText = richText
    }
    
    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
    }
}

public struct RichText: Codable {
    public let type: String
    public let plainText: String
    public let href: String?
    
    public init(type: String, plainText: String, href: String?) {
        self.type = type
        self.plainText = plainText
        self.href = href
    }
    
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
