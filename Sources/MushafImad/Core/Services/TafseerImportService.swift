//
//  TafseerImportService.swift
//  MushafImad
//
//  Created by OpenClaw Bot on 26/02/2026.
//

import Foundation
import RealmSwift

/// Service responsible for importing Tafseer data from JSON sources.
@MainActor
public final class TafseerImportService {
    public static let shared = TafseerImportService()
    
    private init() {}
    
    // MARK: - Import Methods
    
    /// Imports Tafseer data from a JSON file URL.
    /// - Parameters:
    ///   - url: The URL to the JSON file containing Tafseer data.
    ///   - progressHandler: Optional callback for tracking import progress (0.0 to 1.0).
    /// - Returns: The number of verses imported.
    /// - Throws: Import errors if the file cannot be read or parsed.
    public func importTafseer(from url: URL, progressHandler: ((Double) -> Void)? = nil) async throws -> Int {
        let data = try Data(contentsOf: url)
        return try await importTafseer(from: data, progressHandler: progressHandler)
    }
    
    /// Imports Tafseer data from JSON data.
    /// - Parameters:
    ///   - data: The JSON data containing Tafseer information.
    ///   - progressHandler: Optional callback for tracking import progress.
    /// - Returns: The number of verses imported.
    /// - Throws: Import errors if parsing fails.
    public func importTafseer(from data: Data, progressHandler: ((Double) -> Void)? = nil) async throws -> Int {
        let decoder = JSONDecoder()
        let tafseerData = try decoder.decode(TafseerDataFile.self, from: data)
        return try await importTafseer(tafseerData, progressHandler: progressHandler)
    }
    
    /// Imports Tafseer data from a decoded structure.
    /// - Parameters:
    ///   - tafseerData: The Tafseer data structure to import.
    ///   - progressHandler: Optional callback for tracking import progress.
    /// - Returns: The number of verses imported.
    /// - Throws: Realm errors if database operations fail.
    public func importTafseer(_ tafseerData: TafseerDataFile, progressHandler: ((Double) -> Void)? = nil) async throws -> Int {
        guard let configuration = await RealmService.shared.configuration else {
            throw TafseerImportError.realmNotInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        
                        // Create or update the Tafseer metadata
                        let tafseer = self.createOrUpdateTafseer(from: tafseerData, in: realm)
                        
                        // Import verse Tafseer entries
                        let totalVerses = tafseerData.verses.count
                        var importedCount = 0
                        
                        try realm.write {
                            for (index, verseDTO) in tafseerData.verses.enumerated() {
                                let verseTafseer = self.createVerseTafseer(from: verseDTO, tafseer: tafseer, in: realm)
                                realm.add(verseTafseer, update: .modified)
                                
                                importedCount += 1
                                
                                // Report progress every 50 verses or at the end
                                if index % 50 == 0 || index == totalVerses - 1 {
                                    let progress = Double(index + 1) / Double(totalVerses)
                                    DispatchQueue.main.async {
                                        progressHandler?(progress)
                                    }
                                }
                            }
                            
                            // Update the Tafseer metadata
                            tafseer.isDownloaded = true
                            tafseer.downloadDate = Date()
                            tafseer.lastUpdated = Date()
                            realm.add(tafseer, update: .modified)
                        }
                        
                        continuation.resume(returning: importedCount)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Imports Tafseer data from a remote URL.
    /// - Parameters:
    ///   - remoteURL: The remote URL to download the Tafseer JSON from.
    ///   - progressHandler: Optional callback for tracking import progress.
    /// - Returns: The number of verses imported.
    /// - Throws: Network or import errors.
    public func importTafseerFromRemote(_ remoteURL: URL, progressHandler: ((Double) -> Void)? = nil) async throws -> Int {
        let (data, _) = try await URLSession.shared.data(from: remoteURL)
        return try await importTafseer(from: data, progressHandler: progressHandler)
    }
    
    /// Imports multiple Tafseer sources from bundled JSON files.
    /// - Parameter bundle: The bundle to load files from (defaults to main bundle).
    /// - Returns: The total number of verses imported across all files.
    /// - Throws: Import errors.
    public func importBundledTafseer(from bundle: Bundle = .mushafResources) async throws -> Int {
        var totalImported = 0
        
        // Look for tafseer JSON files in the Resources/Res/tafseer directory
        guard let tafseerURLs = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Res/tafseer") else {
            return 0
        }
        
        for url in tafseerURLs {
            let count = try await importTafseer(from: url)
            totalImported += count
        }
        
        return totalImported
    }
    
    // MARK: - Private Helpers
    
    private func createOrUpdateTafseer(from data: TafseerDataFile, in realm: Realm) -> Tafseer {
        let tafseer = realm.object(ofType: Tafseer.self, forPrimaryKey: data.tafseerId) ?? Tafseer()
        tafseer.identifier = data.tafseerId
        tafseer.name = data.name
        tafseer.nameEnglish = data.nameEnglish
        tafseer.authorName = data.authorName
        tafseer.authorNameEnglish = data.authorNameEnglish
        tafseer.language = data.language
        tafseer.source = "imported"
        return tafseer
    }
    
    private func createVerseTafseer(from dto: TafseerImportDTO, tafseer: Tafseer, in realm: Realm) -> VerseTafseer {
        let identifier = VerseTafseer.makeIdentifier(
            tafseerId: dto.tafseerId,
            chapterNumber: dto.chapterNumber,
            verseNumber: dto.verseNumber
        )
        
        let verseTafseer = realm.object(ofType: VerseTafseer.self, forPrimaryKey: identifier) ?? VerseTafseer()
        verseTafseer.identifier = identifier
        verseTafseer.tafseerId = dto.tafseerId
        verseTafseer.chapterNumber = dto.chapterNumber
        verseTafseer.verseNumber = dto.verseNumber
        verseTafseer.humanReadableID = "\(dto.chapterNumber)_\(dto.verseNumber)"
        verseTafseer.text = dto.text
        verseTafseer.shortText = dto.shortText ?? ""
        verseTafseer.tafseer = tafseer
        verseTafseer.lastUpdated = Date()
        return verseTafseer
    }
}

// MARK: - Errors

public enum TafseerImportError: Error, LocalizedError {
    case realmNotInitialized
    case invalidJSON
    case networkError(Error)
    case fileNotFound
    
    public var errorDescription: String? {
        switch self {
        case .realmNotInitialized:
            return "Realm database is not initialized. Call RealmService.shared.initialize() first."
        case .invalidJSON:
            return "The provided JSON data is invalid or malformed."
        case .networkError(let error):
            return "Network error occurred: \(error.localizedDescription)"
        case .fileNotFound:
            return "The specified file was not found."
        }
    }
}

// MARK: - JSON Schema Documentation

/*
 Expected JSON Schema for Tafseer Import:
 
 {
   "tafseerId": "ibn-kathir",
   "name": "تفسير ابن كثير",
   "nameEnglish": "Tafsir Ibn Kathir",
   "authorName": "الحافظ ابن كثير",
   "authorNameEnglish": "Hafiz Ibn Kathir",
   "language": "ar",
   "verses": [
     {
       "tafseerId": "ibn-kathir",
       "chapterNumber": 1,
       "verseNumber": 1,
       "text": "Full tafseer text for this verse...",
       "shortText": "Brief summary (optional)"
     },
     ...
   ]
 }
 */
