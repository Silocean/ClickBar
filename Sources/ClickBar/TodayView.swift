import ClickBarCore
import SwiftUI

struct TodayView: View {
    var model: PanelModel
    var monitor: ClickMonitor

    private var calendar: Calendar { AppCalendar.current }
    private var stats: DayStats {
        monitor.store.days[DayKey.make(monitor.clock, calendar: calendar)] ?? DayStats()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CountCard(
                    title: "左键",
                    systemImage: "circle.lefthalf.filled",
                    value: stats.left,
                    subtitle: share(stats.left),
                    tint: Palette.left
                )
                CountCard(
                    title: "右键",
                    systemImage: "circle.righthalf.filled",
                    value: stats.right,
                    subtitle: share(stats.right),
                    tint: Palette.right
                )
            }

            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Palette.other)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text("其他键 \(ClickFormat.count(stats.other))")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                Spacer()
                Text("合计 \(ClickFormat.count(stats.total))")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)

            ShareBar(left: stats.left, right: stats.right, other: stats.other)
                .frame(height: 6)

            HStack(spacing: 8) {
                MiniStat(title: "本小时", value: ClickFormat.count(thisHour))
                MiniStat(title: "比昨天", value: yesterdayDelta)
                MiniStat(title: "双击", value: ClickFormat.count(stats.doubleClicks))
            }

            sessionLine

            HourlyChart(
                model: model,
                stats: stats,
                highlightedHour: calendar.component(.hour, from: monitor.clock),
                emptyText: "今天还没有点击"
            )
        }
    }

    @ViewBuilder
    private var sessionLine: some View {
        let sessionTotal = monitor.sessionTotal
        let sessionStarted = monitor.sessionStarted
        if monitor.isPaused {
            Text("统计已暂停")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        } else {
            TimelineView(.periodic(from: sessionStarted, by: 1)) { context in
                Text("本次已运行 \(ClickFormat.duration(since: sessionStarted, now: context.date)) · \(ClickFormat.pace(count: sessionTotal, since: sessionStarted, now: context.date))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var thisHour: Int {
        stats.hourlyTotal(calendar.component(.hour, from: monitor.clock))
    }

    private var yesterdayDelta: String {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: monitor.clock) else {
            return "—"
        }
        let key = DayKey.make(yesterday, calendar: calendar)
        guard let previous = monitor.store.days[key] else { return "无记录" }
        let delta = stats.total - previous.total
        if delta == 0 { return "持平" }
        if delta > 0 { return "多 \(ClickFormat.count(delta))" }
        return "少 \(ClickFormat.count(-delta))"
    }

    private func share(_ part: Int) -> String {
        guard stats.total > 0 else { return "今天" }
        return "占 \(ClickFormat.percent(part: part, total: stats.total))"
    }
}
