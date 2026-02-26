//
//  Tafseer.swift
//  MushafImad
//
//  Created by OpenClaw Bot on 26/02/2026.
//

import Foundation
import RealmSwift

/// Represents a Tafseer book/commentary with metadata about the author and source.
public final class Tafseer: Object, Identifiable {
    @Persisted public var identifier: String = ""  // Unique ID (e.g., "ibn-kathir", "al-jalalayn")
    @Persisted public var name: String = ""  // Display name in Arabic
    @Persisted public var nameEnglish: String = ""  // Display name in English
    @Persisted public var authorName: String = ""
    @Persisted public var authorNameEnglish: String = ""
    @Persisted public var language: String = ""  // "ar", "en", etc.
    @Persisted public var source: String = ""  // URL or identifier of the source
    @Persisted public var isDownloaded: Bool = false
    @Persisted public var downloadDate: Date?
    @Persisted public var lastUpdated: Date?
    @Persisted public var isActive: Bool = false  // Currently selected for viewing
    
    public var id: String { identifier }
    
    @objc nonisolated override public class func primaryKey() -> String? {
        return "identifier"
    }
    
    @objc nonisolated override public class func indexedProperties() -> [String] {
        return ["name", "language", "isActive"]
    }
}

// MARK: - Supporting Types

/// Information about a Tafseer suitable for display in lists.
public struct TafseerInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let nameEnglish: String
    public let authorName: String
    public let authorNameEnglish: String
    public let language: String
    public let isDownloaded: Bool
    public let isActive: Bool
    
    public init(from tafseer: Tafseer) {
        self.id = tafseer.identifier
        self.name = tafseer.name
        self.nameEnglish = tafseer.nameEnglish
        self.authorName = tafseer.authorName
        self.authorNameEnglish = tafseer.authorNameEnglish
        self.language = tafseer.language
        self.isDownloaded = tafseer.isDownloaded
        self.isActive = tafseer.isActive
    }
}

/// Available Tafseer types/languages for import.
public enum TafseerLanguage: String, CaseIterable, Sendable {
    case arabic = "ar"
    case english = "en"
    case urdu = "ur"
    case indonesian = "id"
    case turkish = "tr"
    
    public var displayName: String {
        switch self {
        case .arabic: return "العربية"
        case .english: return "English"
        case .urdu: return "اردو"
        case .indonesian: return "Bahasa Indonesia"
        case .turkish: return "Türkçe"
        }
    }
}

/// Predefined Tafseer sources available for import.
public enum TafseerSource: String, CaseIterable, Sendable {
    case ibnKathir = "ibn-kathir"
    case alJalalayn = "al-jalalayn"
    case alSaadi = "al-saadi"
    case alTabari = "al-tabari"
    case alBaghawi = "al-baghawi"
    case alQurtubi = "al-qurtubi"
    
    public var identifier: String { rawValue }
    
    public var name: String {
        switch self {
        case .ibnKathir: return "تفسير ابن كثير"
        case .alJalalayn: return "تفسير الجلالين"
        case .alSaadi: return "تفسير السعدي"
        case .alTabari: return "تفسير الطبري"
        case .alBaghawi: return "تفسير البغوي"
        case .alQurtubi: return "تفسير القرطبي"
        }
    }
    
    public var nameEnglish: String {
        switch self {
        case .ibnKathir: return "Tafsir Ibn Kathir"
        case .alJalalayn: return "Tafsir Al-Jalalayn"
        case .alSaadi: return "Tafsir As-Saadi"
        case .alTabari: return "Tafsir At-Tabari"
        case .alBaghawi: return "Tafsir Al-Baghawi"
        case .alQurtubi: return "Tafsir Al-Qurtubi"
        }
    }
    
    public var authorName: String {
        switch self {
        case .ibnKathir: return "الحافظ ابن كثير"
        case .alJalalayn: return "الإمامان الجلالان"
        case .alSaadi: return "الشيخ السعدي"
        case .alTabari: return "الإمام الطبري"
        case .alBaghawi: return "الإمام البغوي"
        case .alQurtubi: return "الإمام القرطبي"
        }
    }
    
    public var authorNameEnglish: String {
        switch self {
        case .ibnKathir: return "Hafiz Ibn Kathir"
        case .alJalalayn: return "Imams Al-Mahalli & As-Suyuti"
        case .alSaadi: return "Sheikh As-Saadi"
        case .alTabari: return "Imam At-Tabari"
        case .alBaghawi: return "Imam Al-Baghawi"
        case .alQurtubi: return "Imam Al-Qurtubi"
        }
    }
    
    public var language: TafseerLanguage {
        return .arabic
    }
    
    /// The API endpoint path for this Tafseer.
    public var apiPath: String {
        return "/tafseer/\(rawValue)"
    }
}
