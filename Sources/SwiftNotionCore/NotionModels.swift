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
    public let bulletedListItem: TextBlock?
    public let numberedListItem: TextBlock?
    public let quote: QuoteBlock?
    public let code: CodeBlock?
    public let toDo: ToDoBlock?
    
    // Local-only property to track if this block needs to be created or updated.
    // Not encoded to/from JSON (we ignore it in CodingKeys)
    public var isNew: Bool = false
    
    public init(id: String, type: BlockType, hasChildren: Bool, paragraph: TextBlock? = nil, heading1: TextBlock? = nil, heading2: TextBlock? = nil, heading3: TextBlock? = nil, bulletedListItem: TextBlock? = nil, numberedListItem: TextBlock? = nil, quote: QuoteBlock? = nil, code: CodeBlock? = nil, toDo: ToDoBlock? = nil, isNew: Bool = false) {
        self.id = id
        self.type = type
        self.hasChildren = hasChildren
        self.paragraph = paragraph
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.bulletedListItem = bulletedListItem
        self.numberedListItem = numberedListItem
        self.quote = quote
        self.code = code
        self.toDo = toDo
        self.isNew = isNew
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, paragraph, quote, code
        case hasChildren = "has_children"
        case heading1 = "heading_1"
        case heading2 = "heading_2"
        case heading3 = "heading_3"
        case bulletedListItem = "bulleted_list_item"
        case numberedListItem = "numbered_list_item"
        case toDo = "to_do"
    }
}

public enum BlockType: String, Codable {
    case paragraph
    case heading1 = "heading_1"
    case heading2 = "heading_2"
    case heading3 = "heading_3"
    case bulletedListItem = "bulleted_list_item"
    case numberedListItem = "numbered_list_item"
    case quote
    case code
    case toDo = "to_do"
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

public struct CodeBlock: Codable {
    public let richText: [RichText]
    public let language: String
    
    public init(richText: [RichText], language: String = "plain text") {
        self.richText = richText
        self.language = language
    }
    
    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case language
    }
}

public struct ToDoBlock: Codable {
    public let richText: [RichText]
    public let checked: Bool?
    
    public init(richText: [RichText], checked: Bool = false) {
        self.richText = richText
        self.checked = checked
    }
    
    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case checked
    }
}

public struct QuoteBlock: Codable {
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
    public let annotations: Annotations?
    
    public init(type: String, plainText: String, href: String?, annotations: Annotations? = nil) {
        self.type = type
        self.plainText = plainText
        self.href = href
        self.annotations = annotations
    }
    
    enum CodingKeys: String, CodingKey {
        case type, href, annotations
        case plainText = "plain_text"
    }
}

public struct Annotations: Codable {
    public var bold: Bool
    public var italic: Bool
    public var strikethrough: Bool
    public var underline: Bool
    public var code: Bool
    public var color: String
    
    public init(bold: Bool = false, italic: Bool = false, strikethrough: Bool = false, underline: Bool = false, code: Bool = false, color: String = "default") {
        self.bold = bold
        self.italic = italic
        self.strikethrough = strikethrough
        self.underline = underline
        self.code = code
        self.color = color
    }
}

// MARK: - Page
public struct Page: Codable, Identifiable {
    public let id: String
    public let url: String
}
