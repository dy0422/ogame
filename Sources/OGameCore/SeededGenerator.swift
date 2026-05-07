import Foundation

public struct SeededGenerator: RandomNumberGenerator, Codable, Equatable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed &+ 0xA0761D6478BD642F
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15

        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let lower = Int64(range.lowerBound)
        let upper = Int64(range.upperBound)
        let span = UInt64(bitPattern: upper &- lower) &+ 1
        let offset = span == 0 ? next() : next() % span
        let result = UInt64(bitPattern: lower) &+ offset

        return Int(Int64(bitPattern: result))
    }
}
