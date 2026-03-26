import Foundation

/// Token bucket bandwidth limiter.
/// Tokens = bytes. Refilled at `bytesPerSecond` rate every 100ms.
actor BandwidthLimiter {
    private var tokens: Int64
    private var capacity: Int64
    private var refillRate: Int64 // bytes per refill interval
    private var lastRefill: ContinuousClock.Instant
    private let refillInterval: Duration = .milliseconds(100)

    /// 0 = unlimited
    var bytesPerSecond: Int64 {
        didSet {
            if bytesPerSecond <= 0 {
                capacity = .max
                tokens = .max
                refillRate = .max
            } else {
                capacity = bytesPerSecond
                refillRate = bytesPerSecond / 10 // refill every 100ms
                tokens = min(tokens, capacity)
            }
        }
    }

    init(bytesPerSecond: Int64 = 0) {
        self.bytesPerSecond = bytesPerSecond
        self.lastRefill = .now
        if bytesPerSecond <= 0 {
            self.capacity = .max
            self.tokens = .max
            self.refillRate = .max
        } else {
            self.capacity = bytesPerSecond
            self.tokens = bytesPerSecond
            self.refillRate = bytesPerSecond / 10
        }
    }

    /// Request `count` bytes. Suspends until tokens are available.
    /// Returns the number of bytes actually granted (may be less than requested).
    func acquire(_ count: Int64) async -> Int64 {
        guard bytesPerSecond > 0 else { return count }

        refill()

        if tokens >= count {
            tokens -= count
            return count
        }

        // Grant what we have now
        if tokens > 0 {
            let granted = tokens
            tokens = 0
            return granted
        }

        // Wait for next refill
        try? await Task.sleep(for: refillInterval)
        refill()

        let granted = min(count, tokens)
        tokens -= granted
        return granted
    }

    private func refill() {
        let now = ContinuousClock.Instant.now
        let elapsed = now - lastRefill
        if elapsed >= refillInterval {
            let intervals = Int64(elapsed / refillInterval)
            tokens = min(capacity, tokens + intervals * refillRate)
            lastRefill = now
        }
    }
}
