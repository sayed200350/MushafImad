//
//  QuranDataCacheService.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//  Updated with LRU Cache implementation
//

import Foundation
import RealmSwift

/// Service to cache Quran data from Realm for quick access
/// Uses LRU (Least Recently Used) eviction policy with thread-safe operations
@MainActor
public final class QuranDataCacheService {
    public static let shared = QuranDataCacheService()
    
    // MARK: - LRU Caches
    private let versesCache: LRUCache<Int, [Verse]>
    private let pageHeadersCache: LRUCache<Int, PageHeaderInfo>
    private let chapterVersesCache: LRUCache<Int, [Verse]>
    
    private let realmService = RealmService.shared
    
    // Default cache capacities (configurable)
    public static let defaultVersesCacheCapacity = 50
    public static let defaultPageHeadersCacheCapacity = 50
    public static let defaultChapterVersesCacheCapacity = 30
    
    public init(
        versesCapacity: Int = defaultVersesCacheCapacity,
        pageHeadersCapacity: Int = defaultPageHeadersCacheCapacity,
        chapterVersesCapacity: Int = defaultChapterVersesCacheCapacity
    ) {
        self.versesCache = LRUCache(capacity: versesCapacity)
        self.pageHeadersCache = LRUCache(capacity: pageHeadersCapacity)
        self.chapterVersesCache = LRUCache(capacity: chapterVersesCapacity)
    }
    
    // MARK: - Cache Management
    
    /// Pre-fetch and cache data for a specific page
    public func cachePageData(_ pageNumber: Int) async {
        // Cache verses for this page
        if versesCache.get(pageNumber) == nil {
            let verses = realmService.getVersesForPage(pageNumber)
            if !verses.isEmpty {
                versesCache.set(pageNumber, value: verses)
            }
        }
        
        // Cache page header
        if pageHeadersCache.get(pageNumber) == nil {
            if let headerInfo = realmService.getPageHeaderInfo(for: pageNumber) {
                pageHeadersCache.set(pageNumber, value: headerInfo)
            }
        }
        
        // Cache chapter verses for chapters on this page
        let chapters = realmService.getChaptersOnPage(pageNumber)
        for chapter in chapters {
            if chapterVersesCache.get(chapter.number) == nil {
                let chapterVerses = realmService.getVersesForChapter(chapter.number)
                if !chapterVerses.isEmpty {
                    chapterVersesCache.set(chapter.number, value: chapterVerses)
                }
            }
        }
    }
    
    /// Pre-fetch and cache data for a range of pages (e.g., for a chapter)
    public func cachePageRange(_ pageRange: ClosedRange<Int>) async {
        for pageNumber in pageRange {
            await cachePageData(pageNumber)
        }
    }
    
    /// Pre-fetch and cache data for a specific chapter
    public func cacheChapterData(_ chapter: Chapter) async {
        // Cache chapter verses
        if chapterVersesCache.get(chapter.number) == nil {
            let verses = realmService.getVersesForChapter(chapter.number)
            if !verses.isEmpty {
                chapterVersesCache.set(chapter.number, value: verses)
            }
        }
        
        // Cache all pages in this chapter
        await cachePageRange(chapter.startPage...chapter.endPage)
    }
    
    // MARK: - Cache Retrieval
    
    /// Get cached verses for a page (returns nil if not cached)
    public func getCachedVerses(forPage pageNumber: Int) -> [Verse]? {
        return versesCache.get(pageNumber)
    }
    
    /// Get cached page header (returns nil if not cached)
    public func getCachedPageHeader(forPage pageNumber: Int) -> PageHeaderInfo? {
        return pageHeadersCache.get(pageNumber)
    }
    
    /// Get cached verses for a chapter (returns nil if not cached)
    public func getCachedChapterVerses(forChapter chapterNumber: Int) -> [Verse]? {
        return chapterVersesCache.get(chapterNumber)
    }
    
    /// Check if page data is cached
    public func isPageCached(_ pageNumber: Int) -> Bool {
        return versesCache.contains(pageNumber) && pageHeadersCache.contains(pageNumber)
    }
    
    /// Check if chapter data is fully cached
    public func isChapterCached(_ chapter: Chapter) -> Bool {
        guard chapterVersesCache.contains(chapter.number) else { return false }
        
        // Check if all pages are cached
        for pageNumber in chapter.startPage...chapter.endPage {
            if !isPageCached(pageNumber) {
                return false
            }
        }
        return true
    }
    
    // MARK: - Cache Management
    
    /// Clear cached data for a specific page
    public func clearPageCache(_ pageNumber: Int) {
        versesCache.remove(pageNumber)
        pageHeadersCache.remove(pageNumber)
    }
    
    /// Clear cached data for a chapter
    public func clearChapterCache(_ chapterNumber: Int) {
        chapterVersesCache.remove(chapterNumber)
    }
    
    /// Clear all cached data
    public func clearAllCache() {
        versesCache.removeAll()
        pageHeadersCache.removeAll()
        chapterVersesCache.removeAll()
    }
    
    // MARK: - Statistics
    
    /// Get detailed cache statistics including hit/miss rates
    public func getCacheStats() -> QuranCacheStats {
        let versesStats = versesCache.stats
        let headersStats = pageHeadersCache.stats
        let chapterStats = chapterVersesCache.stats
        
        // Aggregate totals
        let totalHits = versesStats.hits + headersStats.hits + chapterStats.hits
        let totalMisses = versesStats.misses + headersStats.misses + chapterStats.misses
        let totalRequests = versesStats.totalRequests + headersStats.totalRequests + chapterStats.totalRequests
        let totalEvictions = versesStats.evictions + headersStats.evictions + chapterStats.evictions
        
        let overallHitRate = totalRequests > 0 ? Double(totalHits) / Double(totalRequests) : 0.0
        
        return QuranCacheStats(
            cachedPagesCount: versesStats.currentSize,
            cachedChaptersCount: chapterStats.currentSize,
            totalVersesCached: 0, // Would require iterating through cached values
            totalHits: totalHits,
            totalMisses: totalMisses,
            totalRequests: totalRequests,
            overallHitRate: overallHitRate,
            versesCacheStats: versesStats,
            pageHeadersCacheStats: headersStats,
            chapterVersesCacheStats: chapterStats,
            totalEvictions: totalEvictions
        )
    }
    
    /// Get individual cache statistics for debugging
    public func getDetailedStats() -> (
        verses: CacheStatistics,
        pageHeaders: CacheStatistics,
        chapterVerses: CacheStatistics
    ) {
        return (
            verses: versesCache.stats,
            pageHeaders: pageHeadersCache.stats,
            chapterVerses: chapterVersesCache.stats
        )
    }
    
    /// Reset all cache statistics
    public func resetStatistics() {
        versesCache.resetStats()
        pageHeadersCache.resetStats()
        chapterVersesCache.resetStats()
    }
    
    /// Get quick summary of cache performance
    public var performanceSummary: String {
        let stats = getCacheStats()
        return String(
            format: "QuranCache: %.1f%% hit rate (%llu hits / %llu misses), %d pages, %d chapters cached, %llu evictions",
            stats.overallHitRate * 100,
            stats.totalHits,
            stats.totalMisses,
            stats.cachedPagesCount,
            stats.cachedChaptersCount,
            stats.totalEvictions
        )
    }
}

// MARK: - Supporting Types

/// Comprehensive cache statistics for QuranDataCacheService
public struct QuranCacheStats: CustomStringConvertible {
    // Basic counts
    public let cachedPagesCount: Int
    public let cachedChaptersCount: Int
    public let totalVersesCached: Int
    
    // Hit/Miss statistics
    public let totalHits: UInt64
    public let totalMisses: UInt64
    public let totalRequests: UInt64
    public let overallHitRate: Double
    
    // Individual cache statistics
    public let versesCacheStats: CacheStatistics
    public let pageHeadersCacheStats: CacheStatistics
    public let chapterVersesCacheStats: CacheStatistics
    
    // Eviction statistics
    public let totalEvictions: UInt64
    
    public var description: String {
        """
        QuranCacheStats:
          Hit Rate: \(String(format: "%.2f%%", overallHitRate * 100))
          Hits: \(totalHits), Misses: \(totalMisses), Total: \(totalRequests)
          Pages Cached: \(cachedPagesCount), Chapters Cached: \(cachedChaptersCount)
          Total Evictions: \(totalEvictions)
          
          Verses Cache: \(versesCacheStats)
          Headers Cache: \(pageHeadersCacheStats)
          Chapter Cache: \(chapterVersesCacheStats)
        """
    }
}

// Re-export CacheStatistics for backward compatibility
public typealias CacheStats = QuranCacheStats
