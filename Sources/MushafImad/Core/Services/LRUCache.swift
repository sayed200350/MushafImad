//
//  LRUCache.swift
//  MushafImad
//
//  Thread-safe LRU Cache implementation with hit/miss tracking
//

import Foundation

/// A thread-safe LRU (Least Recently Used) cache with statistics tracking
@MainActor
public final class LRUCache<Key: Hashable, Value> {
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    private var cache: [Key: Node] = [:]
    private let head = Node(key: 0 as! Key, value: 0 as! Value)
    private let tail = Node(key: 0 as! Key, value: 0 as! Value)
    
    private let capacity: Int
    private let lock = NSLock()
    
    // MARK: - Statistics
    private(set) var hits: UInt64 = 0
    private(set) var misses: UInt64 = 0
    private(set) var evictions: UInt64 = 0
    private(set) var totalRequests: UInt64 = 0
    
    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        head.next = tail
        tail.prev = head
    }
    
    // MARK: - Core Operations
    
    /// Get a value from the cache. Returns nil if not found.
    /// Updates the access order (moves to front as most recently used).
    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        totalRequests += 1
        
        guard let node = cache[key] else {
            misses += 1
            return nil
        }
        
        // Move to front (most recently used)
        removeNode(node)
        addToFront(node)
        
        hits += 1
        return node.value
    }
    
    /// Set a value in the cache.
    /// If key exists, updates value and moves to front.
    /// If key doesn't exist, adds new entry and evicts LRU if at capacity.
    public func set(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }
        
        if let node = cache[key] {
            // Update existing
            node.value = value
            removeNode(node)
            addToFront(node)
        } else {
            // Add new
            let newNode = Node(key: key, value: value)
            cache[key] = newNode
            addToFront(newNode)
            
            // Evict if over capacity
            if cache.count > capacity {
                if let lruNode = tail.prev, lruNode !== head {
                    removeNode(lruNode)
                    cache.removeValue(forKey: lruNode.key)
                    evictions += 1
                }
            }
        }
    }
    
    /// Remove a specific key from the cache
    public func remove(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let node = cache[key] else { return }
        removeNode(node)
        cache.removeValue(forKey: key)
    }
    
    /// Clear all entries from the cache
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        head.next = tail
        tail.prev = head
    }
    
    /// Check if a key exists in the cache (without updating access order)
    public func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cache[key] != nil
    }
    
    /// Get current count of cached items
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
    
    /// Get all keys (for debugging)
    public var keys: [Key] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cache.keys)
    }
    
    // MARK: - Statistics
    
    /// Get current cache statistics
    public var stats: CacheStatistics {
        lock.lock()
        defer { lock.unlock() }
        return CacheStatistics(
            hits: hits,
            misses: misses,
            evictions: evictions,
            totalRequests: totalRequests,
            currentSize: cache.count,
            hitRate: totalRequests > 0 ? Double(hits) / Double(totalRequests) : 0.0
        )
    }
    
    /// Reset statistics counters
    public func resetStats() {
        lock.lock()
        defer { lock.unlock() }
        hits = 0
        misses = 0
        evictions = 0
        totalRequests = 0
    }
    
    // MARK: - Private Helpers
    
    private func addToFront(_ node: Node) {
        node.next = head.next
        node.prev = head
        head.next?.prev = node
        head.next = node
    }
    
    private func removeNode(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        node.prev = nil
        node.next = nil
    }
}

// MARK: - Supporting Types

/// Cache statistics for monitoring performance
public struct CacheStatistics: CustomStringConvertible, Sendable {
    public let hits: UInt64
    public let misses: UInt64
    public let evictions: UInt64
    public let totalRequests: UInt64
    public let currentSize: Int
    public let hitRate: Double
    
    public var description: String {
        String(
            format: "CacheStats(hits: %llu, misses: %llu, hitRate: %.2f%%, size: %d, evictions: %llu)",
            hits, misses, hitRate * 100, currentSize, evictions
        )
    }
}
