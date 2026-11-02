import ClickBarCore
import SwiftUI

struct HistoryView: View {
    var model: PanelModel
    var monitor: ClickMonitor

    private var calendar: Calendar { AppCalendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("历史范围", selection: rangeBinding) {
                ForEach(HistoryRange.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("历史范围")

            VStack(alignment: .leading, spacing: 2) {
                Text("合计 \(ClickFormat.count(totals.total)) · 日均 \(ClickFormat.average(average))")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                Text(summaryDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if let selectedKey = effectiveKey, let stats = monitor.store.days[selectedKey] {
                VStack(alignment: .leading, spacing: 6) {
                    Text(DayLabel.relative(key: selectedKey, today: monitor.clock, calendar: calendar))
                        .font(.system(size: 12, weight: .semibold))
                    HourlyChart(model: model, stats: stats, emptyText: "这一天还没有点击")
                }
            }

            if rows.isEmpty {
                ContentUnavailableView {
                    Label("还没有历史记录", systemImage: "calendar")
                } description: {
                    Text("应用运行期间的点击会按天留在这里。")
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                columnHeader
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(rows, id: \.key) { row in
                            dayRow(row)
                        }
                    }
                }
                .frame(height: min(220, CGFloat(rows.count) * 58))
            }
        }
    }

    private var rangeBinding: Binding<HistoryRange> {
        Binding(
            get: { model.historyRange },
            set: { model.historyRange = $0 }
        )
    }

    private var effectiveKey: String? {
        if let selected = model.selectedKey, rows.contains(where: { $0.key == selected }) {
            return selected
        }
        return rows.first?.key
    }

    private var windowKeys: [String] {
        if let dayCount = model.historyRange.dayCount {
            return StatsMath.recentKeys(endingAt: monitor.clock, dayCount: dayCount, calendar: calendar)
        }
        return StatsMath.sortedKeys(monitor.store.days)
    }

    private var totals: RangeTotals {
        StatsMath.totals(in: monitor.store.days, keys: windowKeys)
    }

    private var average: Double {
        let divisor = model.historyRange.dayCount ?? max(totals.activeDays, 1)
        guard divisor > 0 else { return 0 }
        return Double(totals.total) / Double(divisor)
    }

    private var summaryDetail: String {
        if let key = totals.busiestKey {
            let title = DayLabel.relative(key: key, today: monitor.clock, calendar: calendar)
            let basis = model.historyRange == .all ? "按有点击的日期" : "含没有点击的日期"
            return "最多 \(title) \(ClickFormat.count(totals.busiestTotal)) 次 · \(basis)"
        }
        return model.historyRange == .all ? "还没有点击记录" : "这一段还没有点击"
    }

    private var rows: [(key: String, stats: DayStats)] {
        windowKeys
            .compactMap { key -> (String, DayStats)? in
                guard let stats = monitor.store.days[key], stats.total > 0 else { return nil }
                return (key, stats)
            }
            .sorted { $0.0 > $1.0 }
            .map { (key: $0.0, stats: $0.1) }
    }

    private var maxTotal: Int {
        max(rows.map(\.stats.total).max() ?? 1, 1)
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("日期")
                .frame(maxWidth: .infinity, alignment: .leading)
            columnTitle("左键", Palette.left)
            columnTitle("右键", Palette.right)
            Text("合计")
                .frame(width: 64, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private func columnTitle(_ title: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(title)
        }
        .frame(width: 64, alignment: .trailing)
    }

    private func dayRow(_ row: (key: String, stats: DayStats)) -> some View {
        let selected = effectiveKey == row.key
        return Button {
            model.selectedKey = row.key
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(DayLabel.relative(key: row.key, today: monitor.clock, calendar: calendar))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(DayLabel.detail(key: row.key, today: monitor.clock, calendar: calendar))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    countText(row.stats.left)
                    countText(row.stats.right)
                    countText(row.stats.total, strong: true)
                }
                ShareBar(left: row.stats.left, right: row.stats.right, other: row.stats.other)
                    .frame(height: 4)
                    .scaleEffect(
                        x: max(0.08, CGFloat(row.stats.total) / CGFloat(maxTotal)),
                        y: 1,
                        anchor: .leading
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(rowFill(selected: selected, key: row.key))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                model.hoveredKey = row.key
            } else if model.hoveredKey == row.key {
                model.hoveredKey = nil
            }
        }
        .accessibilityLabel(rowAccessibility(row))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func countText(_ value: Int, strong: Bool = false) -> some View {
        Text(ClickFormat.count(value))
            .font(.system(size: 12, weight: strong ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .frame(width: 64, alignment: .trailing)
    }

    private func rowFill(selected: Bool, key: String) -> Color {
        if selected { return Color.accentColor.opacity(0.14) }
        if model.hoveredKey == key { return Color.primary.opacity(0.05) }
        return Color.clear
    }

    private func rowAccessibility(_ row: (key: String, stats: DayStats)) -> String {
        let title = DayLabel.relative(key: row.key, today: monitor.clock, calendar: calendar)
        return "\(title)，左键 \(row.stats.left)，右键 \(row.stats.right)，合计 \(row.stats.total)"
    }

}
