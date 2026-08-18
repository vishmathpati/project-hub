import Foundation

/// Kept only to parse a saved Anthropic usage payload in tests.
/// Live Usage never reads Keychain or calls the network.
enum ClaudeUsageClient {
    static func windows(from body: [String: Any]) -> [UsageWindow] {
        var result: [UsageWindow] = []
        if let five = body["five_hour"] as? [String: Any] {
            result.append(window(five, title: "5-hour"))
        }
        if let week = body["seven_day"] as? [String: Any] {
            result.append(window(week, title: "Weekly"))
        }
        if let limits = body["limits"] as? [[String: Any]] {
            for limit in limits {
                let kind = (limit["kind"] as? String) ?? ""
                if kind == "weekly_scoped",
                   let name = ((limit["scope"] as? [String: Any])?["model"] as? [String: Any])?["display_name"] as? String {
                    result.append(window(limit, title: "Weekly \(name)"))
                }
            }
        }
        return result
    }

    private static func window(_ raw: [String: Any], title: String) -> UsageWindow {
        let used = number(raw["utilization"]) ?? number(raw["used_percentage"]) ?? number(raw["percent"]) ?? 0
        return UsageWindow(
            title: title,
            usedPercent: min(max(used, 0), 100),
            resetsAt: date(raw["resets_at"]),
            windowMinutes: nil
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        if let seconds = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        if let seconds = value as? Double {
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: string)
        }
        return nil
    }
}
