package com.cliprplus.clipr.util

private const val TTL_MS   = 60 * 60 * 1_000L  // 60 minutes
private const val MAX_SIZE = 200

/**
 * In-memory cache of SHA-256 hex strings with TTL eviction.
 *
 * Used for clipboard loop prevention: before sending a copied text to the
 * network, the caller checks [isKnown] to skip content that was already sent
 * (or received) recently. Entries expire after 60 minutes.
 *
 * Backed by [LinkedHashMap] in insertion order — oldest entry is always at
 * the head, enabling O(N_expired) eviction without a sorted structure.
 *
 * All methods are @Synchronized — called from both Main and IO threads.
 */
class RecentHashCache {

    // LinkedHashMap(initialCapacity, loadFactor, accessOrder=false) → insertion order
    private val cache = LinkedHashMap<String, Long>()

    /**
     * Returns true if [hash] was recorded within the last 60 minutes.
     * Expired entries are lazily removed on lookup.
     */
    @Synchronized
    fun isKnown(hash: String): Boolean {
        val recordedAt = cache[hash] ?: return false
        if (System.currentTimeMillis() - recordedAt > TTL_MS) {
            cache.remove(hash)
            return false
        }
        return true
    }

    /**
     * Record [hash] as recently seen. Evicts expired entries first, then
     * drops the oldest entry if the cache has reached [MAX_SIZE].
     */
    @Synchronized
    fun record(hash: String) {
        evictExpired()
        if (cache.size >= MAX_SIZE) {
            // Remove oldest entry (first in insertion order)
            val iter = cache.iterator()
            if (iter.hasNext()) { iter.next(); iter.remove() }
        }
        cache[hash] = System.currentTimeMillis()
    }

    /** Remove all entries. Call on session reset to avoid cross-account leakage. */
    @Synchronized
    fun clear() {
        cache.clear()
    }

    /** Evict all entries older than [TTL_MS]. Stops at the first non-expired entry. */
    private fun evictExpired() {
        val cutoff = System.currentTimeMillis() - TTL_MS
        val iter = cache.iterator()
        while (iter.hasNext()) {
            if (iter.next().value < cutoff) iter.remove() else break
        }
    }
}
