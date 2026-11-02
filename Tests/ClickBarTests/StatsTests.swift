import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    file: StaticString = #fileID,
    line: UInt = #line
) throws {
    if actual != expected {
        throw TestFailure(description: "\(file):\(line) expected \(expected), got \(actual)")
    }
}

func expectTrue(
    _ condition: Bool,
    _ message: String,
    file: StaticString = #fileID,
    line: UInt = #line
) throws {
    if !condition {
        throw TestFailure(description: "\(file):\(line) \(message)")
    }
}

func requireValue<T>(
    _ value: T?,
    file: StaticString = #fileID,
    line: UInt = #line
) throws -> T {
    guard let value else {
        throw TestFailure(description: "\(file):\(line) unexpected nil")
    }
    return value
}

enum TestDates {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 12,
        _ minute: Int = 0,
        calendar: Calendar = calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    static func stats(left: Int = 0, right: Int = 0, other: Int = 0, hour: Int = 12) -> DayStats {
        var hourlyLeft = Array(repeating: 0, count: 24)
        var hourlyRight = Array(repeating: 0, count: 24)
        var hourlyOther = Array(repeating: 0, count: 24)
        hourlyLeft[hour] = left
        hourlyRight[hour] = right
        hourlyOther[hour] = other
        return DayStats(
            left: left,
            right: right,
            other: other,
            hourlyLeft: hourlyLeft,
            hourlyRight: hourlyRight,
            hourlyOther: hourlyOther
        )
    }
}

@main
struct TestMain {
    static func main() {
        MainActor.assumeIsolated {
            do {
                try runAll()
            } catch {
                fputs("FAIL \(error)\n", stderr)
                exit(1)
            }
        }
    }
}

@MainActor
func runAll() throws {
    let tests: [(String, () throws -> Void)] = [
        ("recentKeysIncludeTodayAndSixEarlierDays", recentKeysIncludeTodayAndSixEarlierDays),
        ("currentStreakKeepsYesterdayWhenTodayIsEmpty", currentStreakKeepsYesterdayWhenTodayIsEmpty),
        ("currentStreakBreaksWhenYesterdayIsAlsoEmpty", currentStreakBreaksWhenYesterdayIsAlsoEmpty),
        ("currentStreakIncludesToday", currentStreakIncludesToday),
        ("longestStreakCrossesTheNewYearAndStopsAtAGap", longestStreakCrossesTheNewYearAndStopsAtAGap),
        ("totalsSkipMissingDaysAndRememberTheBusiestOne", totalsSkipMissingDaysAndRememberTheBusiestOne),
        ("busiestHourSumsDaysAndKeepsTheEarlierTie", busiestHourSumsDaysAndKeepsTheEarlierTie),
        ("dayKeyRoundTripsAtNoon", dayKeyRoundTripsAtNoon),
        ("groupsThousandsAndUsesWan", groupsThousandsAndUsesWan),
        ("percentAndAverageHaveStableText", percentAndAverageHaveStableText),
        ("recordsButtonsIntoTheLocalHourAndPersists", recordsButtonsIntoTheLocalHourAndPersists),
        ("resetWritesAnEmptyFile", resetWritesAnEmptyFile),
        ("unreadableFileIsArchivedInsteadOfDiscardedSilently", unreadableFileIsArchivedInsteadOfDiscardedSilently),
        ("shortAndNegativePayloadsAreClamped", shortAndNegativePayloadsAreClamped),
        ("duplicateMenuBarClickCountsOnce", duplicateMenuBarClickCountsOnce),
        ("laterClickAtTheSameSpotStillCounts", laterClickAtTheSameSpotStillCounts)
    ]
    for (name, test) in tests {
        try test()
        print("ok \(name)")
    }
    print("\(tests.count) tests passed")
}

private let calendar = TestDates.calendar

private func recentKeysIncludeTodayAndSixEarlierDays() throws {
    let today = TestDates.date(2026, 11, 2, calendar: calendar)
    let keys = StatsMath.recentKeys(endingAt: today, dayCount: 7, calendar: calendar)
    try expectEqual(keys, [
        "2026-10-27",
        "2026-10-28",
        "2026-10-29",
        "2026-10-30",
        "2026-10-31",
        "2026-11-01",
        "2026-11-02"
    ])
}

private func currentStreakKeepsYesterdayWhenTodayIsEmpty() throws {
    let days = [
        "2026-10-31": TestDates.stats(left: 2),
        "2026-11-01": TestDates.stats(left: 4),
        "2026-11-02": TestDates.stats(left: 1)
    ]
    let today = TestDates.date(2026, 11, 3, calendar: calendar)
    try expectEqual(StatsMath.currentStreak(days: days, today: today, calendar: calendar), 3)
}

private func currentStreakBreaksWhenYesterdayIsAlsoEmpty() throws {
    let days = [
        "2026-11-01": TestDates.stats(left: 4)
    ]
    let today = TestDates.date(2026, 11, 3, calendar: calendar)
    try expectEqual(StatsMath.currentStreak(days: days, today: today, calendar: calendar), 0)
}

private func currentStreakIncludesToday() throws {
    let days = [
        "2026-11-01": TestDates.stats(left: 1),
        "2026-11-02": TestDates.stats(left: 1)
    ]
    let today = TestDates.date(2026, 11, 2, 9, calendar: calendar)
    try expectEqual(StatsMath.currentStreak(days: days, today: today, calendar: calendar), 2)
}

private func longestStreakCrossesTheNewYearAndStopsAtAGap() throws {
    let days = [
        "2026-12-30": TestDates.stats(left: 1),
        "2026-12-31": TestDates.stats(left: 1),
        "2027-01-01": TestDates.stats(left: 1),
        "2027-01-03": TestDates.stats(left: 1),
        "2027-01-04": TestDates.stats(left: 1)
    ]
    try expectEqual(StatsMath.longestStreak(days: days, calendar: calendar), 3)
}

private func totalsSkipMissingDaysAndRememberTheBusiestOne() throws {
    let days = [
        "2026-11-01": TestDates.stats(left: 2, right: 1),
        "2026-11-02": TestDates.stats(left: 8)
    ]
    let totals = StatsMath.totals(
        in: days,
        keys: ["2026-10-31", "2026-11-01", "2026-11-02"]
    )
    try expectEqual(totals.total, 11)
    try expectEqual(totals.left, 10)
    try expectEqual(totals.right, 1)
    try expectEqual(totals.activeDays, 2)
    try expectEqual(totals.busiestKey, "2026-11-02")
    try expectEqual(totals.busiestTotal, 8)
    try expectEqual(totals.dailyAverage, 5.5)
}

private func busiestHourSumsDaysAndKeepsTheEarlierTie() throws {
    var day = DayStats()
    for _ in 0..<4 {
        day.add(button: .left, hour: 9, isDoubleClick: false)
        day.add(button: .right, hour: 15, isDoubleClick: false)
    }
    let busiest = StatsMath.busiestHour(days: ["2026-11-02": day])
    try expectEqual(busiest?.hour, 9)
    try expectEqual(busiest?.count, 4)
}

private func dayKeyRoundTripsAtNoon() throws {
    let original = TestDates.date(2026, 11, 2, 15, 40, calendar: calendar)
    let key = DayKey.make(original, calendar: calendar)
    let parsed = try requireValue(DayKey.date(from: key, calendar: calendar))
    try expectEqual(key, "2026-11-02")
    try expectTrue(calendar.isDate(parsed, inSameDayAs: original), "same day")
    try expectTrue(DayKey.date(from: "bad", calendar: calendar) == nil, "invalid key")
}

private func groupsThousandsAndUsesWan() throws {
    try expectEqual(ClickFormat.count(1284), "1,284")
    try expectEqual(ClickFormat.count(9999), "9,999")
    try expectEqual(ClickFormat.compact(9999), "9,999")
    try expectEqual(ClickFormat.compact(10_000), "1万")
    try expectEqual(ClickFormat.compact(12_500), "1.3万")
}

private func percentAndAverageHaveStableText() throws {
    try expectEqual(ClickFormat.percent(part: 0, total: 0), "—")
    try expectEqual(ClickFormat.percent(part: 1, total: 200), "<1%")
    try expectEqual(ClickFormat.percent(part: 1, total: 2), "50%")
    try expectEqual(ClickFormat.average(0), "0")
    try expectEqual(ClickFormat.average(9.24), "9.2")
    try expectEqual(ClickFormat.average(172.4), "172")
    try expectEqual(ClickFormat.hourRange(23), "23:00–24:00")
    try expectEqual(ClickFormat.hourRange(24), "—")
}

@MainActor
private func recordsButtonsIntoTheLocalHourAndPersists() throws {
    try withStore { store in
        let moment = TestDates.date(2026, 11, 2, 15, 40)
        store.record(button: .left, at: moment, clickCount: 1)
        store.record(button: .left, at: moment, clickCount: 2)
        store.record(button: .left, at: moment, clickCount: 3)
        store.record(button: .right, at: moment, clickCount: 1)
        store.record(button: .other, at: moment, clickCount: 1)
        store.flush()

        let day = try requireValue(store.days["2026-11-02"])
        try expectEqual(day.left, 3)
        try expectEqual(day.right, 1)
        try expectEqual(day.other, 1)
        try expectEqual(day.doubleClicks, 1)
        try expectEqual(day.hourlyTotal(15), 5)
        try expectEqual(day.peakHour?.hour, 15)

        let reloaded = StatsStore(fileURL: store.fileURL, calendar: TestDates.calendar)
        try expectEqual(reloaded.days["2026-11-02"], day)

        let directory = store.fileURL.deletingLastPathComponent()
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
        try expectEqual(mode & 0o777, 0o700)
    }
}

@MainActor
private func resetWritesAnEmptyFile() throws {
    try withStore { store in
        store.record(button: .left, at: TestDates.date(2026, 11, 2, 9), clickCount: 1)
        store.reset()
        try expectTrue(store.days.isEmpty, "days cleared")
        let data = try Data(contentsOf: store.fileURL)
        let decoded = try JSONDecoder().decode(StatsFile.self, from: data)
        try expectEqual(decoded.version, 1)
        try expectTrue(decoded.days.isEmpty, "file cleared")
    }
}

@MainActor
private func unreadableFileIsArchivedInsteadOfDiscardedSilently() throws {
    try withStore { store in
        let garbage = Data("not-json".utf8)
        let directory = store.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try garbage.write(to: store.fileURL)
        let reloaded = StatsStore(fileURL: store.fileURL, calendar: TestDates.calendar)
        try expectTrue(reloaded.days.isEmpty, "corrupt file ignored")
        try expectTrue(reloaded.lastError != nil, "error surfaced")
        let backup = directory.appendingPathComponent("stats.invalid.json")
        try expectEqual(try Data(contentsOf: backup), garbage)
    }
}

@MainActor
private func shortAndNegativePayloadsAreClamped() throws {
    try withStore { store in
        let json = """
        {"version":1,"days":{"2026-11-02":{"left":-4,"right":2,"other":0,"doubleClicks":-1,"hourlyLeft":[1],"hourlyOther":[3,4]}}}
        """
        let directory = store.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.fileURL)
        let reloaded = StatsStore(fileURL: store.fileURL, calendar: TestDates.calendar)
        let day = try requireValue(reloaded.days["2026-11-02"])
        try expectEqual(day.left, 0)
        try expectEqual(day.right, 2)
        try expectEqual(day.doubleClicks, 0)
        try expectEqual(day.hourlyLeft[0], 1)
        try expectEqual(day.hourlyLeft[1], 0)
        try expectEqual(day.hourlyOther[0], 3)
        try expectEqual(day.hourlyOther[1], 4)
        try expectEqual(day.hourlyOther.count, 24)
    }
}

private func duplicateMenuBarClickCountsOnce() throws {
    var deduper = ClickDeduper()
    let time = Date(timeIntervalSince1970: 1_700_000_000)
    let first = ClickSignal(button: .left, eventNumber: 41, x: 1200, y: 20, time: time)
    let sameEvent = ClickSignal(button: .left, eventNumber: 41, x: 1200, y: 20, time: time.addingTimeInterval(0.001))
    let otherDelivery = ClickSignal(button: .other, eventNumber: 42, x: 1201, y: 21, time: time.addingTimeInterval(0.01))
    try expectTrue(deduper.shouldCount(first), "first click")
    try expectTrue(!deduper.shouldCount(sameEvent), "same event number")
    try expectTrue(!deduper.shouldCount(otherDelivery), "second delivery nearby")
}

private func laterClickAtTheSameSpotStillCounts() throws {
    var deduper = ClickDeduper()
    let time = Date(timeIntervalSince1970: 1_700_000_000)
    let first = ClickSignal(button: .left, eventNumber: 7, x: 10, y: 10, time: time)
    let second = ClickSignal(button: .left, eventNumber: 8, x: 10, y: 10, time: time.addingTimeInterval(0.25))
    try expectTrue(deduper.shouldCount(first), "first")
    try expectTrue(deduper.shouldCount(second), "later click")
}

@MainActor
private func withStore(_ body: (StatsStore) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClickBar-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }
    let store = StatsStore(
        fileURL: directory.appendingPathComponent("stats.json"),
        calendar: TestDates.calendar
    )
    try body(store)
}
