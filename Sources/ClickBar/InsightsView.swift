import ClickBarCore
import SwiftUI

struct InsightsView: View {
    var model: PanelModel
    var monitor: ClickMonitor

    private var calendar: Calendar { AppCalendar.current }

    var body: some View {
        let message = loginMessage
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("登录时打开", isOn: launchBinding)
                    .font(.system(size: 13))
                if let message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(items) { item in
                        StatTile(title: item.title, value: item.value, detail: item.detail)
                    }
                }
            }
            .frame(height: 248)

            HStack(spacing: 8) {
                Button("在访达中显示记录") {
                    monitor.revealRecords()
                }
                Spacer()
                Button("清除全部记录", role: .destructive) {
                    model.confirmReset = true
                }
                .disabled(monitor.store.days.isEmpty && monitor.sessionTotal == 0)
            }
            .font(.system(size: 12))
            .buttonStyle(.borderless)

            Text("点击统计 \(appVersion)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .confirmationDialog(
            "清除全部点击记录？",
            isPresented: Binding(
                get: { model.confirmReset },
                set: { model.confirmReset = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button("清除全部记录", role: .destructive) {
                monitor.resetAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("今天、历史和统计都会清空，而且无法撤销。")
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: {
                _ = monitor.serviceEpoch
                return LoginItemClient.isOn
            },
            set: { monitor.setLaunchAtLogin($0) }
        )
    }

    private var loginMessage: String? {
        _ = monitor.serviceEpoch
        if LoginItemClient.state == .needsApproval {
            return "请在“系统设置 → 通用 → 登录项与扩展”中允许点击统计。"
        }
        guard monitor.loginFailed else { return nil }
        switch LoginItemClient.state {
        case .missingApp:
            return "请把 ClickBar.app 放进“应用程序”文件夹，再用那个副本开启。"
        case .off:
            return "这次没能改开机启动，可以再试一次。"
        case .on, .needsApproval:
            return nil
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var items: [Insight] {
        let days = monitor.store.days
        let today = monitor.clock
        let lifetime = StatsMath.totals(in: days, keys: Array(days.keys))
        let weekKeys = StatsMath.recentKeys(endingAt: today, dayCount: 7, calendar: calendar)
        let monthKeys = StatsMath.recentKeys(endingAt: today, dayCount: 30, calendar: calendar)
        let week = StatsMath.totals(in: days, keys: weekKeys)
        let month = StatsMath.totals(in: days, keys: monthKeys)
        let streak = StatsMath.currentStreak(days: days, today: today, calendar: calendar)
        let longest = StatsMath.longestStreak(days: days, calendar: calendar)
        let hour = StatsMath.busiestHour(days: days)
        let firstKey = StatsMath.sortedKeys(days).first { (days[$0]?.total ?? 0) > 0 }
        let todayTotal = days[DayKey.make(today, calendar: calendar)]?.total ?? 0

        return [
            Insight(
                id: "total",
                title: "累计点击",
                value: ClickFormat.count(lifetime.total),
                detail: "左 \(ClickFormat.count(lifetime.left)) · 右 \(ClickFormat.count(lifetime.right)) · 其他 \(ClickFormat.count(lifetime.other))"
            ),
            Insight(
                id: "days",
                title: "统计天数",
                value: "\(lifetime.activeDays) 天",
                detail: firstKey.map { "从 \(DayLabel.fullDate(DayKey.date(from: $0, calendar: calendar) ?? today, today: today, calendar: calendar)) 开始" } ?? "还没有记录"
            ),
            Insight(
                id: "average",
                title: "日均点击",
                value: ClickFormat.average(lifetime.dailyAverage),
                detail: "只计算有点击的日期"
            ),
            Insight(
                id: "busiest-day",
                title: "单日最高",
                value: lifetime.busiestKey == nil ? "—" : ClickFormat.count(lifetime.busiestTotal),
                detail: lifetime.busiestKey.map { DayLabel.relative(key: $0, today: today, calendar: calendar) } ?? "还没有记录"
            ),
            Insight(
                id: "week",
                title: "近 7 日",
                value: ClickFormat.count(week.total),
                detail: "日均 \(ClickFormat.average(Double(week.total) / 7))，含空档"
            ),
            Insight(
                id: "month",
                title: "近 30 日",
                value: ClickFormat.count(month.total),
                detail: "日均 \(ClickFormat.average(Double(month.total) / 30))，含空档"
            ),
            Insight(
                id: "left-share",
                title: "左键占比",
                value: ClickFormat.percent(part: lifetime.left, total: lifetime.total),
                detail: "累计 \(ClickFormat.count(lifetime.left)) 次"
            ),
            Insight(
                id: "right-share",
                title: "右键占比",
                value: ClickFormat.percent(part: lifetime.right, total: lifetime.total),
                detail: "累计 \(ClickFormat.count(lifetime.right)) 次"
            ),
            Insight(
                id: "streak",
                title: "当前连续",
                value: "\(streak) 天",
                detail: streakDetail(streak: streak, todayTotal: todayTotal)
            ),
            Insight(
                id: "longest",
                title: "最长连续",
                value: "\(longest) 天",
                detail: longest == 0 ? "还没有连续记录" : "有点击的连续日期"
            ),
            Insight(
                id: "hour",
                title: "最活跃时段",
                value: hour.map { ClickFormat.hourRange($0.hour) } ?? "—",
                detail: hour.map { "累计 \(ClickFormat.count($0.count)) 次" } ?? "还没有点击"
            ),
            Insight(
                id: "double",
                title: "累计双击",
                value: ClickFormat.count(lifetime.doubleClicks),
                detail: "第二次按下计为一次双击"
            )
        ]
    }

    private func streakDetail(streak: Int, todayTotal: Int) -> String {
        if streak == 0 { return "还没有连续记录" }
        if todayTotal == 0 { return "今天还没点击，先按昨天计" }
        return "一直到今天"
    }
}

private struct Insight: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
}
