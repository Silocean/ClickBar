import Foundation

public struct DayStats: Equatable, Sendable {
    public private(set) var left: Int
    public private(set) var right: Int
    public private(set) var other: Int
    public private(set) var doubleClicks: Int
    public private(set) var hourlyLeft: [Int]
    public private(set) var hourlyRight: [Int]
    public private(set) var hourlyOther: [Int]

    public init(
        left: Int = 0,
        right: Int = 0,
        other: Int = 0,
        doubleClicks: Int = 0,
        hourlyLeft: [Int]? = nil,
        hourlyRight: [Int]? = nil,
        hourlyOther: [Int]? = nil
    ) {
        self.left = max(0, left)
        self.right = max(0, right)
        self.other = max(0, other)
        self.doubleClicks = max(0, doubleClicks)
        self.hourlyLeft = Self.normalize(hourlyLeft)
        self.hourlyRight = Self.normalize(hourlyRight)
        self.hourlyOther = Self.normalize(hourlyOther)
    }

    public var total: Int {
        left + right + other
    }

    public func hourlyTotal(_ hour: Int) -> Int {
        guard (0..<24).contains(hour),
              hourlyLeft.indices.contains(hour),
              hourlyRight.indices.contains(hour),
              hourlyOther.indices.contains(hour)
        else {
            return 0
        }
        return hourlyLeft[hour] + hourlyRight[hour] + hourlyOther[hour]
    }

    public var peakHour: (hour: Int, count: Int)? {
        var bestHour = 0
        var bestCount = 0
        for hour in 0..<24 {
            let count = hourlyTotal(hour)
            if count > bestCount {
                bestCount = count
                bestHour = hour
            }
        }
        guard bestCount > 0 else { return nil }
        return (bestHour, bestCount)
    }

    public mutating func add(button: MouseButton, hour: Int, isDoubleClick: Bool) {
        guard (0..<24).contains(hour) else { return }
        switch button {
        case .left:
            left += 1
            hourlyLeft[hour] += 1
        case .right:
            right += 1
            hourlyRight[hour] += 1
        case .other:
            other += 1
            hourlyOther[hour] += 1
        }
        if isDoubleClick {
            doubleClicks += 1
        }
    }

    static func normalize(_ values: [Int]?) -> [Int] {
        var result = Array(repeating: 0, count: 24)
        guard let values else { return result }
        for (index, value) in values.prefix(24).enumerated() where value > 0 {
            result[index] = value
        }
        return result
    }
}

extension DayStats: Codable {
    enum CodingKeys: String, CodingKey {
        case left
        case right
        case other
        case doubleClicks
        case hourlyLeft
        case hourlyRight
        case hourlyOther
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            left: try container.decodeIfPresent(Int.self, forKey: .left) ?? 0,
            right: try container.decodeIfPresent(Int.self, forKey: .right) ?? 0,
            other: try container.decodeIfPresent(Int.self, forKey: .other) ?? 0,
            doubleClicks: try container.decodeIfPresent(Int.self, forKey: .doubleClicks) ?? 0,
            hourlyLeft: try container.decodeIfPresent([Int].self, forKey: .hourlyLeft),
            hourlyRight: try container.decodeIfPresent([Int].self, forKey: .hourlyRight),
            hourlyOther: try container.decodeIfPresent([Int].self, forKey: .hourlyOther)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(left, forKey: .left)
        try container.encode(right, forKey: .right)
        try container.encode(other, forKey: .other)
        try container.encode(doubleClicks, forKey: .doubleClicks)
        try container.encode(hourlyLeft, forKey: .hourlyLeft)
        try container.encode(hourlyRight, forKey: .hourlyRight)
        try container.encode(hourlyOther, forKey: .hourlyOther)
    }
}
