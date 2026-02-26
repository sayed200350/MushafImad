//
//  TafseerCacheService.swift
//  MushafImad
//
//  Created by OpenClaw Bot on 26/02/2026.
//

import Foundation
import RealmSwift

/// Service responsible for caching and retrieving Tafseer data efficiently.
@MainActor
public final class TafseerCacheService {
    public static let shared = TafseerCacheService()
    
    // In-memory cache for frequently accessed Tafseer
    private var memoryCache: [String: VerseTafseer] = [:]
    private var tafseerInfoCache: [String: TafseerInfo] = [:]
    private let cacheLock = NSLock()
    
    // Cache configuration
    private let maxMemoryCacheSize = 1000  // Maximum number of verses to cache in memory
    private var accessOrder: [String] = []  // LRU tracking
    
    private init() {}
    
    // MARK: - Cache Configuration
    
    /// Configuration options for the Tafseer cache.
    public struct CacheConfiguration {
        public let maxMemoryCacheSize: Int
        public let enableDiskCache: Bool
        public let enableMemoryCache: Bool
        
        public init(maxMemoryCacheSize: Int = 1000, enableDiskCache: Bool = true, enableMemoryCache: Bool = true) {
            self.maxMemoryCacheSize = maxMemoryCacheSize
            self.enableDiskCache = enableDiskCache
            self.enableMemoryCache = enableMemoryCache
        }
        
        public static let `default` = CacheConfiguration()
        public static let aggressive = CacheConfiguration(maxMemoryCacheSize: 5000, enableDiskCache: true, enableMemoryCache: true)
        public static let minimal = CacheConfiguration(maxMemoryCacheSize: 100, enableDiskCache: true, enableMemoryCache: false)
    }
    
    private var configuration: CacheConfiguration = .default
    
    /// Configures the cache service with custom settings.
    public func configure(with config: CacheConfiguration) {
        self.configuration = config
        if !config.enableMemoryCache {
            clearMemoryCache()
        }
    }
    
    // MARK: - Retrieval Methods
    
    /// Retrieves Tafseer text for a specific verse from cache or database.
    /// - Parameters:
    ///   - tafseerId: The identifier of the Tafseer source.
    ///   - chapterNumber: The chapter (Surah) number.
    ///   - verseNumber: The verse (Ayah) number.
    ///   - preferShortText: If true, returns the short version if available.
    /// - Returns: The Tafseer text, or nil if not found.
    public func getTafseer(
        tafseerId: String,
        chapterNumber: Int,
        verseNumber: Int,
        preferShortText: Bool = false
    ) async -> String? {
        let identifier = VerseTafseer.makeIdentifier(tafseerId: tafseerId, chapterNumber: chapterNumber, verseNumber: verseNumber)
        
        // Check memory cache first
        if configuration.enableMemoryCache,
           let cached = getFromMemoryCache(identifier) {
            return preferShortText && !cached.shortText.isEmpty ? cached.shortText : cached.text
        }
        
        // Fetch from database
        guard let realmConfig = await RealmService.shared.configuration else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: realmConfig)
                        if let verseTafseer = realm.object(ofType: VerseTafseer.self, forPrimaryKey: identifier)?.freeze() {
                            // Add to memory cache
                            if self.configuration.enableMemoryCache {
                                self.addToMemoryCache(verseTafseer)
                            }
                            
                            let text = preferShortText && !verseTafseer.shortText.isEmpty
                                ? verseTafseer.shortText
                                : verseTafseer.text
                            continuation.resume(returning: text)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    /// Retrieves complete Tafseer information for a verse.
    public func getVerseTafseer(
        tafseerId: String,
        chapterNumber: Int,
        verseNumber: Int
    ) async -> VerseTafseer? {
        let identifier = VerseTafseer.makeIdentifier(tafseerId: tafseerId, chapterNumber: chapterNumber, verseNumber: verseNumber)
        
        // Check memory cache first
        if configuration.enableMemoryCache,
           let cached = getFromMemoryCache(identifier) {
            return cached
        }
        
        // Fetch from database
        guard let realmConfig = await RealmService.shared.configuration else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: realmConfig)
                        if let verseTafseer = realm.object(ofType: VerseTafseer.self, forPrimaryKey: identifier)?.freeze() {
                            if self.configuration.enableMemoryCache {
                                self.addToMemoryCache(verseTafseer)
                            }
                            continuation.resume(returning: verseTafseer)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    /// Retrieves all Tafseer entries for a specific chapter.
    public func getTafseerForChapter(tafseerId: String, chapterNumber: Int) async -> [VerseTafseer] {
        guard let realmConfig = await RealmService.shared.configuration else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: realmConfig)
                        let results = realm.objects(VerseTafseer.self)
                            .filter("tafseerId == %@ AND chapterNumber == %@", tafseerId, chapterNumber)
                            .sorted(byKeyPath: "verseNumber")
                        let frozen = Array(results.freeze())
                        
                        // Add to memory cache
                        if self.configuration.enableMemoryCache {
                            for verseTafseer in frozen {
                                self.addToMemoryCache(verseTafseer)
                            }
                        }
                        
                        continuation.resume(returning: frozen)
                    } catch {
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }
    
    /// Gets all available (downloaded) Tafseer sources.
    public func getAvailableTafseers() async -> [Tafseer] {
        guard let realmConfig = await RealmService.shared.configuration else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: realmConfig)
                        let results = realm.objects(Tafseer.self)
                            .filter("isDownloaded == true")
                            .sorted(byKeyPath: "name")
                        let frozen = Array(results.freeze())
                        continuation.resume(returning: frozen)
                    } catch {
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }
    
    /// Gets information about all available Tafseers (lightweight).
    public func getAvailableTafseerInfo() async -> [TafseerInfo] {
        let tafseers = await getAvailableTafseers()
        return tafseers.map { TafseerInfo(from: $0) }
    }
    
    /// Gets the currently active Tafseer.
    public func getActiveTafseer() async -> Tafseer? {
        guard let realmConfig = await RealmService.shared.configuration else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: realmConfig)
                        let tafseer = realm.objects(Tafseer.self)
                            .filter("isActive == true")
                            .first?
                            .freeze()
                        continuation.resume(returning: tafseer)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    /// Sets a Tafseer as the active one for viewing.
    public func setActiveTafseer(_ tafseerId: String) async throws {
        guard let realmConfig = await RealmService.shared.configuration else {
            throw TafseerCacheError.realmNotInitialized
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: realmConfig)
                        
                        try realm.write {
                            // Deactivate all Tafseers
                            let allTafseers = realm.objects(Tafseer.self)
                            for tafseer in allTafseers {
                                tafseer.isActive = false
                            }
                            
                            // Activate the selected one
                            if let tafseer = realm.object(ofType: Tafseer.self, forPrimaryKey: tafseerId) {
                                tafseer.isActive = true
                            }
                        }
                        
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Preloads Tafseer data for a specific chapter into memory cache.
    public func preloadChapter(tafseerId: String, chapterNumber: Int) async {
        let verses = await getTafseerForChapter(tafseerId: tafseerId, chapterNumber: chapterNumber)
        AppLogger.shared.info("Preloaded \(verses.count) verses for chapter \(chapterNumber)", category: .data)
    }
    
    /// Clears the in-memory cache.
    public func clearMemoryCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        memoryCache.removeAll()
        tafseerInfoCache.removeAll()
        accessOrder.removeAll()
        
        AppLogger.shared.info("Tafseer memory cache cleared", category: .data)
    }
    
    /// Clears all cached data including disk cache (deletes all Tafseer data).
    public func clearAllCache() async throws {
        clearMemoryCache()
        
        guard let realmConfig = await RealmService.shared.configuration else {
            throw TafseerCacheError.realmNotInitialized
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: realmConfig)
                        
                        try realm.write {
                            // Delete all VerseTafseer objects
                            let allVerseTafseers = realm.objects(VerseTafseer.self)
                            realm.delete(allVerseTafseers)
                            
                            // Reset Tafseer metadata
                            let allTafseers = realm.objects(Tafseer.self)
                            for tafseer in allTafseers {
                                tafseer.isDownloaded = false
                                tafseer.downloadDate = nil
                                tafseer.isActive = false
                            }
                        }
                        
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        AppLogger.shared.info("All Tafseer cache cleared", category: .data)
    }
    
    /// Gets cache statistics for debugging/monitoring.
    public func getCacheStats() -> CacheStats {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        return CacheStats(
            memoryCacheCount: memoryCache.count,
            maxMemoryCacheSize: maxMemoryCacheSize,
            memoryUsageEstimate: estimateMemoryUsage()
        )
    }
    
    // MARK: - Private Helpers
    
    private func getFromMemoryCache(_ identifier: String) -> VerseTafseer? {
        guard configuration.enableMemoryCache else { return nil }
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let cached = memoryCache[identifier] {
            // Update access order (LRU)
            if let index = accessOrder.firstIndex(of: identifier) {
                accessOrder.remove(at: index)
                accessOrder.append(identifier)
            }
            return cached
        }
        return nil
    }
    
    private func addToMemoryCache(_ verseTafseer: VerseTafseer) {
        guard configuration.enableMemoryCache else { return }
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let identifier = verseTafseer.identifier
        
        // If already in cache, update access order
        if memoryCache[identifier] != nil {
            if let index = accessOrder.firstIndex(of: identifier) {
                accessOrder.remove(at: index)
            }
        } else {
            // Evict oldest entries if cache is full
            while memoryCache.count >= maxMemoryCacheSize && !accessOrder.isEmpty {
                let oldest = accessOrder.removeFirst()
                memoryCache.removeValue(forKey: oldest)
            }
        }
        
        memoryCache[identifier] = verseTafseer
        accessOrder.append(identifier)
    }
    
    private func estimateMemoryUsage() -> Int {
        // Rough estimate: ~100 bytes overhead + text size
        var total = 0
        for verse in memoryCache.values {
            total += 100 + verse.text.utf8.count + verse.shortText.utf8.count
        }
        return total
    }
}

// MARK: - Supporting Types

/// Statistics about the current cache state.
public struct CacheStats: Sendable {
    public let memoryCacheCount: Int
    public let maxMemoryCacheSize: Int
    public let memoryUsageEstimate: Int  // In bytes
    
    public var utilizationPercentage: Double {
        guard maxMemoryCacheSize > 0 else { return 0 }
        return Double(memoryCacheCount) / Double(maxMemoryCacheSize) * 100
    }
    
    public var formattedMemoryUsage: String {
        let kb = Double(memoryUsageEstimate) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        } else {
            return String(format: "%.2f MB", kb / 1024.0)
        }
    }
}

public enum TafseerCacheError: Error, LocalizedError {
    case realmNotInitialized
    
    public var errorDescription: String? {
        switch self {
        case .realmNotInitialized:
            return "Realm database is not initialized. Call RealmService.shared.initialize() first."
        }
    }
}
