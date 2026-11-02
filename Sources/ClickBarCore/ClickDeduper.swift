import Foundation

public struct ClickSignal: Equatable, Sendable {
    public var button: MouseButton
    public var eventNumber: Int
    public var x: Double
    public var y: Double
    public var time: Date

    public init(button: MouseButton, eventNumber: Int, x: Double, y: Double, time: Date) {
        self.button = button
        self.eventNumber = eventNumber
        self.x = x
        self.y = y
        self.time = time
    }
}

/// Drops the second delivery of one physical click.
/// Menu-bar clicks are observed by both the app-local and global monitors.
public struct ClickDeduper: Sendable {
    private var seenNumbers: [Int] = []
    private var lastAccepted: ClickSignal?
    public var window: TimeInterval
    public var distance: Double

    public init(window: TimeInterval = 0.08, distance: Double = 8) {
        self.window = window
        self.distance = distance
    }

    public mutating func shouldCount(_ signal: ClickSignal) -> Bool {
        if signal.eventNumber != 0, seenNumbers.contains(signal.eventNumber) {
            return false
        }
        if signal.eventNumber != 0 {
            remember(signal.eventNumber)
        }
        if let lastAccepted,
           abs(signal.time.timeIntervalSince(lastAccepted.time)) < window,
           hypot(signal.x - lastAccepted.x, signal.y - lastAccepted.y) <= distance {
            return false
        }
        lastAccepted = signal
        return true
    }

    private mutating func remember(_ number: Int) {
        seenNumbers.append(number)
        if seenNumbers.count > 64 {
            seenNumbers.removeFirst(seenNumbers.count - 64)
        }
    }
}
