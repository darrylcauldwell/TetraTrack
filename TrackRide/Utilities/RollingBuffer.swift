//
//  RollingBuffer.swift
//  TrackRide
//
//  Generic fixed-size rolling buffer for sensor data analysis

import Foundation

/// A fixed-size buffer that automatically removes oldest items when capacity is exceeded
struct RollingBuffer<T> {
    private var storage: [T] = []
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }
    var isFull: Bool { storage.count >= capacity }

    /// Add an item, removing the oldest if at capacity
    mutating func append(_ item: T) {
        storage.append(item)
        if storage.count > capacity {
            storage.removeFirst()
        }
    }

    /// Remove all items
    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
    }

    /// Access all items
    var items: [T] { storage }

    /// Access item at index
    subscript(index: Int) -> T {
        storage[index]
    }
}

// MARK: - Numeric Statistics

extension RollingBuffer where T: BinaryFloatingPoint {
    /// Calculate mean of all values
    var mean: T {
        guard !isEmpty else { return 0 }
        return storage.reduce(0, +) / T(storage.count)
    }

    /// Calculate sum of all values
    var sum: T {
        storage.reduce(0, +)
    }

    /// Calculate variance
    var variance: T {
        guard count >= 2 else { return 0 }
        let avg = mean
        return storage.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / T(count)
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

/// A rolling buffer that stores timestamped values
struct TimestampedRollingBuffer<T> {
    private var storage: [(timestamp: Date, value: T)] = []
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    mutating func append(_ value: T, at timestamp: Date = Date()) {
        storage.append((timestamp, value))
        if storage.count > capacity {
            storage.removeFirst()
        }
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
    }

    /// Remove items older than cutoff date
    mutating func removeOlderThan(_ cutoff: Date) {
        storage.removeAll { $0.timestamp < cutoff }
    }

    var items: [(timestamp: Date, value: T)] { storage }
    var values: [T] { storage.map(\.value) }

    subscript(index: Int) -> (timestamp: Date, value: T) {
        storage[index]
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
