import AppKit
import ClickBarCore
import Observation
import SwiftUI

@main
final class ClickBarController: NSObject, NSApplicationDelegate {
    static var keepAlive: ClickBarController?

    private var monitor: ClickMonitor?
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?

    static func main() {
        let app = NSApplication.shared
        let delegate = ClickBarController()
        keepAlive = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            self.bootstrap()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            self.monitor?.flush()
        }
    }

    @MainActor
    private func bootstrap() {
        let monitor = ClickMonitor()
        let panelModel = PanelModel()
        self.monitor = monitor
        monitor.activate(prompt: true)
        configurePopover(model: panelModel, monitor: monitor)
        configureStatusItem()
        observeMenuBar()
    }

    @MainActor
    private func configurePopover(model: PanelModel, monitor: ClickMonitor) {
        let controller = NSHostingController(rootView: PanelView(model: model, monitor: monitor))
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = false
    }

    @MainActor
    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(togglePanel(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        renderStatusItem()
    }

    @objc private func togglePanel(_ sender: Any?) {
        MainActor.assumeIsolated {
            self.togglePanelOnMain(sender)
        }
    }

    @MainActor
    private func togglePanelOnMain(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        monitor?.recheckTrust()
    }

    @MainActor
    private func observeMenuBar() {
        withObservationTracking {
            renderStatusItem()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeMenuBar()
            }
        }
    }

    @MainActor
    private func renderStatusItem() {
        guard let monitor, let button = statusItem?.button else { return }
        let calendar = AppCalendar.current
        let key = DayKey.make(monitor.clock, calendar: calendar)
        let stats = monitor.store.days[key] ?? DayStats()
        let state: String
        if monitor.isPaused {
            state = "已暂停"
        } else if monitor.isTrusted {
            state = "正在记录"
        } else {
            state = "尚未获得辅助功能权限"
        }
        let help = "点击统计，今日左键 \(ClickFormat.count(stats.left))，右键 \(ClickFormat.count(stats.right))，其他 \(ClickFormat.count(stats.other))。\(state)"

        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "点击统计")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.alphaValue = monitor.isPaused ? 0.55 : 1
        button.toolTip = help
        button.setAccessibilityLabel(help)
    }
}

extension ClickBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        MainActor.assumeIsolated {
            if let window = self.popover.contentViewController?.view.window {
                window.level = .popUpMenu
                window.makeKey()
            }
            self.armOutsideClickMonitor()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            self.disarmOutsideClickMonitor()
        }
    }

    @MainActor
    private func armOutsideClickMonitor() {
        disarmOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.closePopoverIfClickIsOutside()
                }
            }
        }
    }

    @MainActor
    private func disarmOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    @MainActor
    private func closePopoverIfClickIsOutside() {
        guard popover.isShown else { return }
        let mouse = NSEvent.mouseLocation
        if let frame = popover.contentViewController?.view.window?.frame, frame.contains(mouse) {
            return
        }
        if let button = statusItem?.button, let window = button.window {
            let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
            if buttonFrame.contains(mouse) {
                return
            }
        }
        popover.performClose(nil)
    }
}
