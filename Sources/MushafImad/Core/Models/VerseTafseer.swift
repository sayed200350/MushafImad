//
//  VerseTafseer.swift
//  MushafImad
//
//  Created by OpenClaw Bot on 26/02/2026.
//

import Foundation
import RealmSwift

/// Represents the Tafseer (commentary) text for a specific verse.
public final class VerseTafseer: Object, Identifiable {
    @Persisted public var identifier: String = ""  // Composite key: "tafseerId_chapter_verse"
    @Persisted public var tafseerId: String = ""  // Reference to Tafseer.identifier
    @Persisted public var chapterNumber: Int = 0
    @Persisted public var verseNumber: Int = 0
    @Persisted public var humanReadableID: String = ""  // e.g. "2_255"
    @Persisted public var text: String = ""  // The actual Tafseer text
    @Persisted public var shortText: String = ""  // Abridged version if available
    @Persisted public var lastUpdated: Date?
    
    // Relationship
    @Persisted public var tafseer: Tafseer?
    
    public var id: String { identifier }
    
    @objc nonisolated override public class func primaryKey() -> String? {
        return "identifier"
    }
    
    @objc nonisolated override public class func indexedProperties() -> [String] {
        return ["tafseerId", "chapterNumber", "verseNumber", "humanReadableID"]
    }
    
    /// Creates a composite identifier from components.
    public static func makeIdentifier(tafseerId: String, chapterNumber: Int, verseNumber: Int) -> String {
        return "\(tafseerId)_\(chapterNumber)_\(verseNumber)"
    }
}

// MARK: - Supporting Types

/// DTO for importing Tafseer data from JSON.
public struct TafseerImportDTO: Codable, Sendable {
    public let tafseerId: String
    public let chapterNumber: Int
    public let verseNumber: Int
    public let text: String
    public let shortText: String?
    
    public init(tafseerId: String, chapterNumber: Int, verseNumber: Int, text: String, shortText: String? = nil) {
        self.tafseerId = tafseerId
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.text = text
        self.shortText = shortText
    }
}

/// Represents a complete Tafseer data file structure.
public struct TafseerDataFile: Codable, Sendable {
    public let tafseerId: String
    public let name: String
    public let nameEnglish: String
    public let authorName: String
    public let authorNameEnglish: String
    public let language: String
    public let verses: [TafseerImportDTO]
    
    public init(tafseerId: String, name: String, nameEnglish: String, authorName: String, authorNameEnglish: String, language: String, verses: [TafseerImportDTO]) {
        self.tafseerId = tafseerId
        self.name = name
        self.nameEnglish = nameEnglish
        self.authorName = authorName
        self.authorNameEnglish = authorNameEnglish
        self.language = language
        self.verses = verses
    }
}

/// Metadata for a cached Tafseer entry.
public struct VerseTafseerInfo: Identifiable, Sendable {
    public let id: String
    public let tafseerId: String
    public let chapterNumber: Int
    public let verseNumber: Int
    public let hasFullText: Bool
    public let hasShortText: Bool
    
    public init(from verseTafseer: VerseTafseer) {
        self.id = verseTafseer.identifier
        self.tafseerId = verseTafseer.tafseerId
        self.chapterNumber = verseTafseer.chapterNumber
        self.verseNumber = verseTafseer.verseNumber
        self.hasFullText = !verseTafseer.text.isEmpty
        self.hasShortText = !verseTafseer.shortText.isEmpty
    }
}
