import ClickBarCore
import Foundation

enum DayLabel {
    static func relative(key: String, today: Date, calendar: Calendar) -> String {
        guard let date = DayKey.date(from: key, calendar: calendar) else { return key }
        if calendar.isDate(date, inSameDayAs: today) {
            return "今天"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天"
        }
        return fullDate(date, today: today, calendar: calendar)
    }

    static func detail(key: String, today: Date, calendar: Calendar) -> String {
        guard let date = DayKey.date(from: key, calendar: calendar) else { return "" }
        let weekday = weekdayName(date, calendar: calendar)
        let dateText = fullDate(date, today: today, calendar: calendar)
        if calendar.isDate(date, inSameDayAs: today) {
            return "\(dateText) \(weekday)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "\(dateText) \(weekday)"
        }
        return weekday
    }

    static func fullDate(_ date: Date, today: Date, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let todayYear = calendar.component(.year, from: today)
        if year != todayYear {
            return "\(year)年\(month)月\(day)日"
        }
        return "\(month)月\(day)日"
    }

    static func weekdayName(_ date: Date, calendar: Calendar) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.weekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}

enum HistoryRange: String, CaseIterable, Identifiable {
    case week
    case month
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "7 天"
        case .month: "30 天"
        case .all: "全部"
        }
    }

    var dayCount: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .all: nil
        }
    }
}

enum PanelTab: String, CaseIterable, Identifiable {
    case today
    case history
    case insights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "今天"
        case .history: "历史"
        case .insights: "统计"
        }
    }
}
