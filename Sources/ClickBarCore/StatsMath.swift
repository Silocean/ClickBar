import Foundation

public struct RangeTotals: Equatable, Sendable {
    public var left: Int
    public var right: Int
    public var other: Int
    public var doubleClicks: Int
    public var activeDays: Int
    public var busiestKey: String?
    public var busiestTotal: Int

    public var total: Int {
        left + right + other
    }

    public var dailyAverage: Double {
        guard activeDays > 0 else { return 0 }
        return Double(total) / Double(activeDays)
    }

    public static let empty = RangeTotals(
        left: 0,
        right: 0,
        other: 0,
        doubleClicks: 0,
        activeDays: 0,
        busiestKey: nil,
        busiestTotal: 0
    )
}

public enum StatsMath {
    public static func totals(in days: [String: DayStats], keys: [String]) -> RangeTotals {
        var result = RangeTotals.empty
        for key in keys {
            guard let day = days[key], day.total > 0 else { continue }
            result.left += day.left
            result.right += day.right
            result.other += day.other
            result.doubleClicks += day.doubleClicks
            result.activeDays += 1
            if day.total > result.busiestTotal {
                result.busiestTotal = day.total
                result.busiestKey = key
            }
        }
        return result
    }

    /// Oldest first, including days with no clicks. `dayCount` includes `date`.
    public static func recentKeys(endingAt date: Date, dayCount: Int, calendar: Calendar) -> [String] {
        guard dayCount > 0 else { return [] }
        let end = calendar.startOfDay(for: date)
        var keys: [String] = []
        keys.reserveCapacity(dayCount)
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { continue }
            keys.append(DayKey.make(day, calendar: calendar))
        }
        return keys
    }

    public static func sortedKeys(_ days: [String: DayStats]) -> [String] {
        days.keys.sorted()
    }

    /// Consecutive active days ending today. A still-empty today does not break yesterday's streak.
    public static func currentStreak(days: [String: DayStats], today: Date, calendar: Calendar) -> Int {
        var cursor = calendar.startOfDay(for: today)
        if (days[DayKey.make(cursor, calendar: calendar)]?.total ?? 0) == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while streak < 5_000 {
            let key = DayKey.make(cursor, calendar: calendar)
            if (days[key]?.total ?? 0) == 0 {
                break
            }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    public static func longestStreak(days: [String: DayStats], calendar: Calendar) -> Int {
        let active = days
            .filter { $0.value.total > 0 }
            .keys
            .sorted()
        guard let first = active.first else { return 0 }

        var longest = 1
        var current = 1
        var previousDate = DayKey.date(from: first, calendar: calendar)
        for key in active.dropFirst() {
            guard
                let previous = previousDate,
                let next = DayKey.date(from: key, calendar: calendar),
                let expected = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: previous)),
                calendar.isDate(expected, inSameDayAs: next)
            else {
                current = 1
                previousDate = DayKey.date(from: key, calendar: calendar)
                continue
            }
            current += 1
            longest = max(longest, current)
            previousDate = next
        }
        return longest
    }

    /// Ties keep the earlier hour.
    public static func busiestHour(days: [String: DayStats]) -> (hour: Int, count: Int)? {
        var buckets = Array(repeating: 0, count: 24)
        for day in days.values {
            for hour in 0..<24 {
                buckets[hour] += day.hourlyTotal(hour)
            }
        }
        var bestHour: Int?
        var bestCount = 0
        for (hour, count) in buckets.enumerated() where count > bestCount {
            bestCount = count
            bestHour = hour
        }
        guard let bestHour else { return nil }
        return (bestHour, bestCount)
    }
}
