import Foundation

/// LRU (Least Recently Used) Cache implementation for QuranDataCacheService
/// Addresses issue #9: Implement LRU Cache for QuranDataCacheService
actor LRUCache<Key: Hashable, Value> {
    private let maxSize: Int
    private var cache: [Key: Value] = [:]
    private var usageOrder: [Key] = []
    
    /// Statistics for cache performance monitoring
    private(set) var hits: UInt64 = 0
    private(set) var misses: UInt64 = 0
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    /// Get value from cache
    func get(_ key: Key) -> Value? {
        guard let value = cache[key] else {
            misses += 1
            return nil
        }
        
        // Move to front (most recently used)
        usageOrder.removeAll { $0 == key }
        usageOrder.append(key)
        hits += 1
        return value
    }
    
    /// Set value in cache
    func set(_ key: Key, _ value: Value) {
        // If key exists, update and move to front
        if cache[key] != nil {
            cache[key] = value
            usageOrder.removeAll { $0 == key }
            usageOrder.append(key)
            return
        }
        
        // Evict least recently used if at capacity
        if cache.count >= maxSize, let leastUsed = usageOrder.first {
            cache.removeValue(forKey: leastUsed)
            usageOrder.removeFirst()
        }
        
        // Add new item
        cache[key] = value
        usageOrder.append(key)
    }
    
    /// Remove specific key
    func remove(_ key: Key) {
        cache.removeValue(forKey: key)
        usageOrder.removeAll { $0 == key }
    }
    
    /// Clear entire cache
    func clear() {
        cache.removeAll()
        usageOrder.removeAll()
    }
    
    /// Get cache statistics
    var statistics: CacheStatistics {
        let total = hits + misses
        let hitRate = total > 0 ? Double(hits) / Double(total) : 0.0
        return CacheStatistics(
            hits: hits,
            misses: misses,
            hitRate: hitRate,
            size: cache.count,
            maxSize: maxSize
        )
    }
}

/// Cache statistics structure
struct CacheStatistics {
    let hits: UInt64
    let misses: UInt64
    let hitRate: Double
    let size: Int
    let maxSize: Int
    
    var description: String {
        String(format: "Cache: %d/%d items, %.1f%% hit rate (%llu hits, %llu misses)",
               size, maxSize, hitRate * 100, hits, misses)
    }
}

/// Quran Data Cache Service with LRU caching
class QuranDataCacheService {
    static let shared = QuranDataCacheService()
    
    private let verseCache: LRUCache<String, VerseData>
    private let pageCache: LRUCache<Int, PageData>
    private let tafseerCache: LRUCache<String, TafseerData>
    
    private init() {
        // Configure cache sizes based on memory constraints
        verseCache = LRUCache(maxSize: 1000)  // ~1000 verses
        pageCache = LRUCache(maxSize: 100)     // ~100 pages
        tafseerCache = LRUCache(maxSize: 500)  // ~500 tafseer entries
    }
    
    // MARK: - Verse Cache
    
    func getVerse(surah: Int, ayah: Int) async -> VerseData? {
        let key = "\(surah):\(ayah)"
        return await verseCache.get(key)
    }
    
    func setVerse(_ verse: VerseData, surah: Int, ayah: Int) async {
        let key = "\(surah):\(ayah)"
        await verseCache.set(key, verse)
    }
    
    // MARK: - Page Cache
    
    func getPage(_ page: Int) async -> PageData? {
        await pageCache.get(page)
    }
    
    func setPage(_ data: PageData, page: Int) async {
        await pageCache.set(page, data)
    }
    
    // MARK: - Tafseer Cache
    
    func getTafseer(surah: Int, ayah: Int) async -> TafseerData? {
        let key = "\(surah):\(ayah)"
        return await tafseerCache.get(key)
    }
    
    func setTafseer(_ tafseer: TafseerData, surah: Int, ayah: Int) async {
        let key = "\(surah):\(ayah)"
        await tafseerCache.set(key, tafseer)
    }
    
    // MARK: - Statistics
    
    func getStatistics() async -> (verses: CacheStatistics, pages: CacheStatistics, tafseer: CacheStatistics) {
        async let verseStats = verseCache.statistics
        async let pageStats = pageCache.statistics
        async let tafseerStats = tafseerCache.statistics
        
        return await (verses: verseStats, pages: pageStats, tafseer: tafseerStats)
    }
    
    // MARK: - Clear Cache
    
    func clearAllCaches() async {
        await verseCache.clear()
        await pageCache.clear()
        await tafseerCache.clear()
    }
}

// MARK: - Placeholder Types

struct VerseData {
    let text: String
    let translation: String?
}

struct PageData {
    let verses: [VerseData]
    let imageData: Data?
}

struct TafseerData {
    let text: String
    let source: String
}
