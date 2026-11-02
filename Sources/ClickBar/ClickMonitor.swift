import AppKit
import ApplicationServices
import ClickBarCore
import Foundation
import Observation
import ServiceManagement

enum AppCalendar {
    static var current: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        return calendar
    }
}

enum InstanceGuard {
    static func anotherInstanceRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let pid = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != pid && !$0.isTerminated }
    }
}

enum PermissionClient {
    static func isTrusted(prompt: Bool) -> Bool {
        guard prompt else { return AXIsProcessTrusted() }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

enum LoginItemState: Equatable {
    case off
    case on
    case needsApproval
    case missingApp
}

enum LoginItemClient {
    static var state: LoginItemState {
        let status = SMAppService.mainApp.status
        if status == .enabled { return .on }
        if status == .requiresApproval { return .needsApproval }
        if status == .notFound { return .missingApp }
        return .off
    }

    static var isOn: Bool {
        switch state {
        case .on, .needsApproval:
            return true
        case .off, .missingApp:
            return false
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }
}

/// Counts button presses only. Click location, window, and target app are never read or stored.
@MainActor
@Observable
final class ClickMonitor {
    static weak var current: ClickMonitor?

    let store: StatsStore
    var isPaused = false
    private(set) var isTrusted = false
    private(set) var serviceEpoch = 0
    private(set) var loginFailed = false
    private(set) var sessionLeft = 0
    private(set) var sessionRight = 0
    private(set) var sessionOther = 0
    private(set) var sessionStarted = Date()
    private(set) var clock = Date()

    private var monitors: [Any] = []
    private var deduper = ClickDeduper()
    private var timer: Timer?
    private var started = false
    private let suppressed: Bool

    var sessionTotal: Int {
        sessionLeft + sessionRight + sessionOther
    }

    init(store: StatsStore? = nil) {
        let shouldSuppress = InstanceGuard.anotherInstanceRunning()
        suppressed = shouldSuppress
        self.store = store ?? StatsStore.live(calendar: AppCalendar.current)
        if shouldSuppress {
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return
        }
        Self.current = self
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("正在统计鼠标点击")
        activate(prompt: false)
    }

    func activate(prompt: Bool) {
        guard !suppressed else { return }
        refreshTrust(promptIfNeeded: prompt)
        installMonitors()
        if !started {
            started = true
            startClock()
            scheduleSmokeIfNeeded()
        }
    }

    func togglePause() {
        isPaused.toggle()
    }

    func recheckTrust() {
        let trusted = PermissionClient.isTrusted(prompt: false)
        if trusted != isTrusted {
            isTrusted = trusted
            if trusted {
                installMonitors()
            }
        }
    }

    func relaunch() {
        flush()
        let path = Bundle.main.bundlePath.replacingOccurrences(of: "'", with: "'\\''")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; open '\(path)'"]
        do {
            try task.run()
        } catch {
            return
        }
        NSApp.terminate(nil)
    }

    func requestAccess() {
        refreshTrust(promptIfNeeded: false)
        isTrusted = PermissionClient.isTrusted(prompt: true)
        PermissionClient.openSettings()
        if isTrusted {
            installMonitors()
        }
        serviceEpoch &+= 1
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemClient.setEnabled(enabled)
            loginFailed = false
        } catch {
            loginFailed = true
        }
        serviceEpoch &+= 1
    }

    func resetAll() {
        store.reset()
        sessionLeft = 0
        sessionRight = 0
        sessionOther = 0
        sessionStarted = Date()
        clock = Date()
    }

    func revealRecords() {
        do {
            let url = try store.prepareRevealLocation()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            store.flush()
        }
    }

    func flush() {
        store.flush()
    }

    func record(_ payload: ClickPayload) {
        guard !suppressed, !isPaused else { return }
        let signal = ClickSignal(
            button: payload.button,
            eventNumber: payload.eventNumber,
            x: payload.x,
            y: payload.y,
            time: payload.date
        )
        guard deduper.shouldCount(signal) else { return }
        store.record(button: payload.button, at: payload.date, clickCount: payload.clickCount)
        switch payload.button {
        case .left:
            sessionLeft += 1
        case .right:
            sessionRight += 1
        case .other:
            sessionOther += 1
        }
        clock = payload.date
    }

    private func heartbeat() {
        let now = Date()
        clock = now
        store.useTimeZone(.current)
        store.flush()
        let trusted = PermissionClient.isTrusted(prompt: false)
        if trusted != isTrusted {
            isTrusted = trusted
            if trusted {
                installMonitors()
            }
        }
        serviceEpoch &+= 1
    }

    private static var buildStamp: String {
        guard let url = Bundle.main.executableURL else { return "unknown" }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = values?.fileSize ?? 0
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        return "\(size)-\(Int(modified))"
    }

    private func refreshTrust(promptIfNeeded: Bool) {
        var trusted = PermissionClient.isTrusted(prompt: false)
        let stamp = Self.buildStamp
        let prompted = UserDefaults.standard.string(forKey: Keys.promptedStamp)
        if promptIfNeeded, !trusted, !Self.skipPrompt, prompted != stamp {
            UserDefaults.standard.set(stamp, forKey: Keys.promptedStamp)
            trusted = PermissionClient.isTrusted(prompt: true)
        }
        isTrusted = trusted
    }

    private func installMonitors() {
        removeMonitors()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            ClickRouting.deliver(event)
        }) {
            monitors.append(global)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            ClickRouting.deliver(event)
            return event
        }
        if let local {
            monitors.append(local)
        }
    }

    private func removeMonitors() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }

    private func scheduleSmokeIfNeeded() {
        guard ProcessInfo.processInfo.environment["CLICKBAR_SMOKE"] == "1" else { return }
        fputs("ClickBar smoke ok\n", stdout)
        fflush(stdout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    private func startClock() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.heartbeat()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private static var skipPrompt: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["CLICKBAR_SKIP_PROMPT"] == "1" || environment["CLICKBAR_SMOKE"] == "1"
    }

    private enum Keys {
        static let promptedStamp = "ClickBar.promptedBuildStamp"
    }
}

struct ClickPayload: Sendable {
    var button: MouseButton
    var clickCount: Int
    var date: Date
    var eventNumber: Int
    var x: Double
    var y: Double

    init(event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            button = .left
        case .rightMouseDown:
            button = .right
        default:
            button = .other
        }
        clickCount = event.clickCount
        date = Date()
        eventNumber = event.eventNumber
        let screenPoint = Self.screenPoint(of: event)
        x = screenPoint.x
        y = screenPoint.y
    }

    private static func screenPoint(of event: NSEvent) -> NSPoint {
        guard let window = event.window else { return event.locationInWindow }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}

private enum ClickRouting {
    static func deliver(_ event: NSEvent) {
        let payload = ClickPayload(event: event)
        Task { @MainActor in
            ClickMonitor.current?.record(payload)
        }
    }
}
