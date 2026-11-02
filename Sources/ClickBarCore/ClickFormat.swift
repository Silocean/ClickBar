import Foundation

public enum ClickFormat {
    public static func count(_ value: Int) -> String {
        let sign = value < 0 ? "-" : ""
        let digits = String(abs(value))
        var groups: [String] = []
        var rest = digits[...]
        while rest.count > 3 {
            let split = rest.index(rest.endIndex, offsetBy: -3)
            groups.append(String(rest[split...]))
            rest = rest[..<split]
        }
        groups.append(String(rest))
        return sign + groups.reversed().joined(separator: ",")
    }

    public static func compact(_ value: Int) -> String {
        let sign = value < 0 ? "-" : ""
        let magnitude = abs(value)
        let body: String
        switch magnitude {
        case 0..<10_000:
            body = count(magnitude)
        case 10_000..<100_000_000:
            body = trim(Double(magnitude) / 10_000) + "万"
        default:
            body = trim(Double(magnitude) / 100_000_000) + "亿"
        }
        return sign + body
    }

    public static func percent(part: Int, total: Int) -> String {
        guard total > 0, part >= 0 else { return "—" }
        let value = Double(part) / Double(total) * 100
        if part > 0, value < 1 {
            return "<1%"
        }
        return "\(Int(value.rounded()))%"
    }

    public static func average(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        if value >= 10 {
            return count(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    public static func hourRange(_ hour: Int) -> String {
        guard (0..<24).contains(hour) else { return "—" }
        return String(format: "%02d:00–%02d:00", hour, hour + 1)
    }

    public static func duration(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remain = seconds % 60
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分"
        }
        if minutes > 0 {
            return "\(minutes) 分 \(remain) 秒"
        }
        return "\(remain) 秒"
    }

    public static func pace(count: Int, since start: Date, now: Date) -> String {
        guard count > 0 else { return "还没有点击" }
        let seconds = now.timeIntervalSince(start)
        guard seconds >= 20 else { return "节奏计算中" }
        let perMinute = Double(count) / seconds * 60
        if perMinute < 10 {
            return String(format: "约 %.1f 次/分钟", perMinute)
        }
        return "约 \(self.count(Int(perMinute.rounded()))) 次/分钟"
    }

    private static func trim(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.05 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }
}
