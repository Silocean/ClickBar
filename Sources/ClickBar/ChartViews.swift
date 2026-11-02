import AppKit
import ClickBarCore
import SwiftUI

enum Palette {
    static let left = Color.blue
    static let right = Color.orange
    static let other = Color.purple
}

struct CountCard: View {
    let title: String
    let systemImage: String
    let value: Int
    let subtitle: String
    let tint: Color

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            Text(ClickFormat.count(value))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: value)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)，\(ClickFormat.count(value)) 次，\(subtitle)")
    }
}

struct MiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
    }
}

struct ShareBar: View {
    let left: Int
    let right: Int
    let other: Int

    var body: some View {
        GeometryReader { proxy in
            let total = left + right + other
            if total == 0 {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
            } else {
                HStack(spacing: 2) {
                    segment(left, tint: Palette.left, total: total, width: proxy.size.width)
                    segment(right, tint: Palette.right, total: total, width: proxy.size.width)
                    segment(other, tint: Palette.other, total: total, width: proxy.size.width)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func segment(_ value: Int, tint: Color, total: Int, width: CGFloat) -> some View {
        if value > 0 {
            Capsule()
                .fill(tint)
                .frame(width: max(3, (width - gap(total: total)) * CGFloat(value) / CGFloat(total)))
        }
    }

    private func gap(total: Int) -> CGFloat {
        let parts = [left, right, other].filter { $0 > 0 }.count
        return CGFloat(max(0, parts - 1)) * 2
    }
}

struct HourlyChart: View {
    var model: PanelModel
    let stats: DayStats
    var highlightedHour: Int?
    var emptyText = "这一天还没有点击"

    private var hoveredHour: Int? { model.hoveredHour }

    private var peak: Int {
        (0..<24).map { stats.hourlyTotal($0) }.max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("每小时")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                legend
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    hourColumn(hour)
                }
            }
            .frame(height: 72)

            HStack {
                Text("0")
                Spacer()
                Text("6")
                Spacer()
                Text("12")
                Spacer()
                Text("18")
                Spacer()
                Text("24")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .accessibilityHidden(true)

            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem("左键", Palette.left)
            legendItem("右键", Palette.right)
            legendItem("其他", Palette.other)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ title: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(title)
        }
    }

    private func hourColumn(_ hour: Int) -> some View {
        let counts = bucket(hour)
        let total = counts.left + counts.right + counts.other
        let barHeight = peak > 0 ? max(total > 0 ? 3 : 0, CGFloat(total) / CGFloat(peak) * 68) : 0

        return VStack(spacing: 3) {
            Spacer(minLength: 0)
            if total > 0 {
                VStack(spacing: 0) {
                    if counts.other > 0 {
                        Rectangle()
                            .fill(Palette.other)
                            .frame(height: barHeight * CGFloat(counts.other) / CGFloat(total))
                    }
                    if counts.right > 0 {
                        Rectangle()
                            .fill(Palette.right)
                            .frame(height: barHeight * CGFloat(counts.right) / CGFloat(total))
                    }
                    if counts.left > 0 {
                        Rectangle()
                            .fill(Palette.left)
                            .frame(height: barHeight * CGFloat(counts.left) / CGFloat(total))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            } else if hour == highlightedHour {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 8)
            } else {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 1)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(hoveredHour == hour ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                model.hoveredHour = hour
            } else if model.hoveredHour == hour {
                model.hoveredHour = nil
            }
        }
        .help("\(ClickFormat.hourRange(hour))，左键 \(counts.left)，右键 \(counts.right)，其他 \(counts.other)")
    }

    private func bucket(_ hour: Int) -> (left: Int, right: Int, other: Int) {
        guard stats.hourlyLeft.indices.contains(hour) else { return (0, 0, 0) }
        return (stats.hourlyLeft[hour], stats.hourlyRight[hour], stats.hourlyOther[hour])
    }

    private var caption: String {
        if let hour = hoveredHour {
            let counts = bucket(hour)
            return "\(ClickFormat.hourRange(hour)) · 左 \(ClickFormat.count(counts.left)) · 右 \(ClickFormat.count(counts.right)) · 其他 \(ClickFormat.count(counts.other))"
        }
        if let peak = stats.peakHour {
            return "最活跃 \(ClickFormat.hourRange(peak.hour)) · \(ClickFormat.count(peak.count)) 次"
        }
        return emptyText
    }

    private var accessibilitySummary: String {
        if let peak = stats.peakHour {
            return "每小时点击。最活跃 \(ClickFormat.hourRange(peak.hour))，\(ClickFormat.count(peak.count)) 次。左键 \(ClickFormat.count(stats.left))，右键 \(ClickFormat.count(stats.right))，其他 \(ClickFormat.count(stats.other))。"
        }
        return "每小时点击。\(emptyText)"
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)，\(value)，\(detail)")
    }
}
