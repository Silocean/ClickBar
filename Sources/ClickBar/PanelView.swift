import ClickBarCore
import SwiftUI

struct PanelView: View {
    var model: PanelModel
    var monitor: ClickMonitor

    private var calendar: Calendar { AppCalendar.current }

    private var tabBinding: Binding<PanelTab> {
        Binding(
            get: { model.tab },
            set: { newValue in
                model.tab = newValue
                model.hoveredHour = nil
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !monitor.isTrusted {
                permissionBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            Picker("视图", selection: tabBinding) {
                ForEach(PanelTab.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("视图")
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch model.tab {
                case .today:
                    TodayView(model: model, monitor: monitor)
                case .history:
                    HistoryView(model: model, monitor: monitor)
                case .insights:
                    InsightsView(model: model, monitor: monitor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Divider()
            footer
        }
        .frame(width: 372)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("点击统计")
                    .font(.system(size: 15, weight: .semibold))
                Text(statusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(DayLabel.fullDate(monitor.clock, today: monitor.clock, calendar: calendar))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                Text(DayLabel.weekdayName(monitor.clock, calendar: calendar))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
    }

    private var statusLine: String {
        if monitor.isPaused { return "已暂停" }
        if monitor.isTrusted { return "正在记录" }
        return "只能记录这个面板里的点击"
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("需要允许辅助功能")
                    .font(.system(size: 13, weight: .semibold))
                Text("系统设置里若已经打开，那是上一份签名，不会作用在现在这份上。请把「点击统计」关掉再打开，然后重新打开本应用。这次允许后，以后更新不用再授权。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("打开辅助功能设置") {
                        monitor.requestAccess()
                    }
                    Button("重新打开应用") {
                        monitor.relaunch()
                    }
                }
                .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = monitor.store.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button {
                    monitor.togglePause()
                } label: {
                    Label(monitor.isPaused ? "继续" : "暂停", systemImage: monitor.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("p", modifiers: [.command])

                Button(role: .destructive) {
                    monitor.flush()
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("退出", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Text("只在应用运行时计数，不记录点击位置和所在窗口。数据保存在本机。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }
}
