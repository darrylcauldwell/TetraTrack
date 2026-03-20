//
//  RollingBuffer.swift
//  TetraTrack
//
//  Generic fixed-size rolling buffer for sensor data analysis.
//  Uses circular buffer internally for O(1) append at high sample rates.

import Foundation

/// A fixed-size buffer that automatically removes oldest items when capacity is exceeded.
/// Uses a circular buffer internally so append is always O(1).
struct RollingBuffer<T> {
    private var storage: [T?]
    private var head: Int = 0  // next write position
    private var _count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }
    var isFull: Bool { _count >= capacity }

    /// Add an item, overwriting the oldest if at capacity. O(1).
    mutating func append(_ item: T) {
        storage[head] = item
        head = (head + 1) % capacity
        if _count < capacity {
            _count += 1
        }
    }

    /// Remove all items
    mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        head = 0
        _count = 0
    }

    /// Access all items in chronological order (oldest first)
    var items: [T] {
        guard _count > 0 else { return [] }
        var result = [T]()
        result.reserveCapacity(_count)
        let start = isFull ? head : 0
        for i in 0..<_count {
            let index = (start + i) % capacity
            result.append(storage[index]!)
        }
        return result
    }

    /// Access item at logical index (0 = oldest)
    subscript(index: Int) -> T {
        let start = isFull ? head : 0
        let actualIndex = (start + index) % capacity
        return storage[actualIndex]!
    }
}

// MARK: - Numeric Statistics

extension RollingBuffer where T: BinaryFloatingPoint {
    /// Calculate mean of all values
    var mean: T {
        guard !isEmpty else { return 0 }
        var total: T = 0
        let start = isFull ? head : 0
        for i in 0..<_count {
            let index = (start + i) % capacity
            total += storage[index]!
        }
        return total / T(_count)
    }

    /// Calculate sum of all values
    var sum: T {
        var total: T = 0
        let start = isFull ? head : 0
        for i in 0..<_count {
            let index = (start + i) % capacity
            total += storage[index]!
        }
        return total
    }

    /// Calculate variance
    var variance: T {
        guard count >= 2 else { return 0 }
        let avg = mean
        var total: T = 0
        let start = isFull ? head : 0
        for i in 0..<_count {
            let index = (start + i) % capacity
            let diff = storage[index]! - avg
            total += diff * diff
        }
        return total / T(count)
    }

    /// Calculate standard deviation
    var standardDeviation: T {
        T(sqrt(Double(variance)))
    }

    /// Calculate coefficient of variation (stdDev / mean)
    var coefficientOfVariation: T {
        let avg = mean
        guard avg != 0 else { return 0 }
        return standardDeviation / avg
    }
}

// MARK: - Timestamped Buffer

/// A rolling buffer that stores timestamped values.
/// Uses a circular buffer internally so append is always O(1).
struct TimestampedRollingBuffer<T> {
    private var storage: [(timestamp: Date, value: T)?]
    private var head: Int = 0
    private var _count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }

    /// Append a timestamped value. O(1).
    mutating func append(_ value: T, at timestamp: Date = Date()) {
        storage[head] = (timestamp, value)
        head = (head + 1) % capacity
        if _count < capacity {
            _count += 1
        }
    }

    mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        head = 0
        _count = 0
    }

    /// Remove items older than cutoff date
    mutating func removeOlderThan(_ cutoff: Date) {
        // Rebuild buffer keeping only items >= cutoff
        let kept = items.filter { $0.timestamp >= cutoff }
        removeAll()
        for item in kept {
            append(item.value, at: item.timestamp)
        }
    }

    /// All items in chronological order (oldest first)
    var items: [(timestamp: Date, value: T)] {
        guard _count > 0 else { return [] }
        var result = [(timestamp: Date, value: T)]()
        result.reserveCapacity(_count)
        let start = (_count < capacity) ? 0 : head
        for i in 0..<_count {
            let index = (start + i) % capacity
            result.append(storage[index]!)
        }
        return result
    }

    var values: [T] { items.map(\.value) }

    subscript(index: Int) -> (timestamp: Date, value: T) {
        let start = (_count < capacity) ? 0 : head
        let actualIndex = (start + index) % capacity
        return storage[actualIndex]!
    }
}

extension TimestampedRollingBuffer where T: BinaryFloatingPoint {
    var mean: T {
        guard !isEmpty else { return 0 }
        return values.reduce(0, +) / T(count)
    }

    var sum: T {
        values.reduce(0, +)
    }
}
