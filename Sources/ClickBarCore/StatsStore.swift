import Foundation
import Observation

public struct StatsFile: Codable, Equatable, Sendable {
    public var version: Int
    public var days: [String: DayStats]

    public init(version: Int = 1, days: [String: DayStats]) {
        self.version = version
        self.days = days
    }
}

/// Local daily click totals. Locations, windows, and app names are never stored.
@MainActor
@Observable
public final class StatsStore {
    public private(set) var days: [String: DayStats] = [:]
    public private(set) var lastError: String?
    public let fileURL: URL
    private var calendar: Calendar
    private var dirty = false
    private var pendingClicks = 0
    private var lastSave = Date.distantPast

    public init(fileURL: URL, calendar: Calendar = .current) {
        self.fileURL = fileURL
        self.calendar = calendar
        load()
    }

    public static func defaultFileURL() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("ClickBar", isDirectory: true)
            .appendingPathComponent("stats.json")
    }

    public static func live(calendar: Calendar = .current) -> StatsStore {
        StatsStore(fileURL: defaultFileURL(), calendar: calendar)
    }

    public func useTimeZone(_ timeZone: TimeZone) {
        calendar.timeZone = timeZone
    }

    public func record(button: MouseButton, at date: Date = .now, clickCount: Int = 1) {
        let key = DayKey.make(date, calendar: calendar)
        var day = days[key] ?? DayStats()
        let hour = calendar.component(.hour, from: date)
        day.add(button: button, hour: hour, isDoubleClick: clickCount == 2)
        var updated = days
        updated[key] = day
        days = updated
        dirty = true
        pendingClicks += 1
        if pendingClicks >= 10 || Date().timeIntervalSince(lastSave) >= 1 {
            saveNow()
        }
    }

    public func reset() {
        days = [:]
        dirty = true
        pendingClicks = 0
        saveNow()
    }

    public func flush() {
        guard dirty else { return }
        saveNow()
    }

    public func revealURL() -> URL {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return fileURL.deletingLastPathComponent()
    }

    public func prepareRevealLocation() throws -> URL {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
        return revealURL()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(StatsFile.self, from: data)
            days = decoded.days
            lastError = nil
        } catch {
            archiveUnreadableFile()
            days = [:]
        }
    }

    private func saveNow() {
        do {
            let payload = StatsFile(version: 1, days: days)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try writeAtomically(try encoder.encode(payload))
            dirty = false
            pendingClicks = 0
            lastSave = Date()
            lastError = nil
        } catch {
            lastError = "记录未能保存"
        }
    }

    private func writeAtomically(_ data: Data) throws {
        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // Best effort: never block the save if the directory cannot be tightened.
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let temporary = directory.appendingPathComponent(".stats-\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: [.atomic])
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    private func archiveUnreadableFile() {
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent("stats.invalid.json")
        do {
            let data = try Data(contentsOf: fileURL)
            try data.write(to: backup, options: [.atomic])
            lastError = "原有记录无法读取，已保留为 stats.invalid.json"
        } catch {
            lastError = "原有记录无法读取"
        }
    }
}
