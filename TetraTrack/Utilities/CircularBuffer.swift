//
//  CircularBuffer.swift
//  TetraTrack
//

/// Circular buffer for O(1) append and automatic size limiting
struct CircularBuffer<T> {
    private var storage: [T?]
    private var writeIndex: Int = 0
    private var count_: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { count_ }
    var isEmpty: Bool { count_ == 0 }

    mutating func append(_ element: T) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count_ < capacity {
            count_ += 1
        }
    }

    mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count_ = 0
    }

    /// Returns elements in chronological order (oldest first)
    var elements: [T] {
        guard count_ > 0 else { return [] }
        if count_ < capacity {
            return storage[0..<count_].compactMap { $0 }
        }
        // Buffer is full - return from writeIndex (oldest) to end, then start to writeIndex
        let tail = storage[writeIndex..<capacity].compactMap { $0 }
        let head = storage[0..<writeIndex].compactMap { $0 }
        return tail + head
    }
}
