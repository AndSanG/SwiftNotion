import Foundation
import NotionSwift

public typealias NotionBlock = NotionSwift.Block // The read-only block from API
public typealias BlockType = NotionSwift.BlockType
public typealias RichText = NotionSwift.RichText

// Wrapper for local operations
public struct ParsedBlock: Identifiable {
    public let id: String
    public let type: BlockType
    public var isNew: Bool
    
    public init(id: String, type: BlockType, isNew: Bool = false) {
        self.id = id
        self.type = type
        self.isNew = isNew
    }
}

// Attempt to uncover Annotations and RichText init
// public typealias Annotations = NotionSwift.RichText.Annotations // Trying this
// If RichText is a struct, maybe accessing Annotations inside it work?

