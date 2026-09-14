import Foundation

enum LimitPeriod: String, CaseIterable, Identifiable, Codable {
    case day, week, month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

enum LimitMode: Equatable, Codable {
    case explicit(Int)
    case maxPrevious

    enum CodingKeys: String, CodingKey { case kind, value }
    enum Kind: String, Codable { case explicit, maxPrevious }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        switch try box.decode(Kind.self, forKey: .kind) {
        case .explicit: self = .explicit(try box.decode(Int.self, forKey: .value))
        case .maxPrevious: self = .maxPrevious
        }
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .explicit(let value):
            try box.encode(Kind.explicit, forKey: .kind)
            try box.encode(value, forKey: .value)
        case .maxPrevious:
            try box.encode(Kind.maxPrevious, forKey: .kind)
            try box.encode(0, forKey: .value)
        }
    }
}

struct UsageLimit: Equatable, Codable {
    var period: LimitPeriod
    var mode: LimitMode
    var thresholds: [Int]

    init(period: LimitPeriod, mode: LimitMode = .maxPrevious, thresholds: [Int] = [75, 90]) {
        self.period = period
        self.mode = mode
        self.thresholds = thresholds
    }

    var explicitValue: Int {
        if case .explicit(let value) = mode { return max(0, value) }
        return 0
    }

    var isMaxPrevious: Bool {
        if case .maxPrevious = mode { return true }
        return false
    }
}

enum LimitStatus: String, Equatable, Codable {
    case ok, warning, exceeded
}

struct LimitProgress: Equatable {
    let period: LimitPeriod
    let periodKey: String
    let used: Int
    let cap: Int
    let percent: Double
    let status: LimitStatus

    init(period: LimitPeriod, periodKey: String, used: Int, cap: Int) {
        self.period = period
        self.periodKey = periodKey
        self.used = used
        self.cap = cap
        let value = cap > 0 ? Double(used) / Double(cap) * 100 : 0
        self.percent = value
        if value >= 90 {
            self.status = .exceeded
        } else if value >= 70 {
            self.status = .warning
        } else {
            self.status = .ok
        }
    }

    var statusText: String {
        switch status {
        case .ok: return "on track"
        case .warning: return "approaching"
        case .exceeded: return "over 90%"
        }
    }
}

struct ThresholdEvent: Equatable, Codable, Identifiable {
    enum Kind: String, Codable { case crossed, reset }

    let key: String
    let period: LimitPeriod
    let periodKey: String
    let threshold: Int?
    let kind: Kind
    let date: Date

    var id: String { key }

    var text: String {
        switch kind {
        case .crossed: return "\(period.title) hit \(threshold ?? 0)%"
        case .reset: return "\(period.title) window reset"
        }
    }
}

struct UsageLimitsState: Equatable, Codable {
    var limits: [UsageLimit]
    var firedKeys: Set<String>
    var lastKeys: [String: String]
    var events: [ThresholdEvent]

    init(
        limits: [UsageLimit] = LimitPeriod.allCases.map { UsageLimit(period: $0) },
        firedKeys: Set<String> = [],
        lastKeys: [String: String] = [:],
        events: [ThresholdEvent] = []
    ) {
        self.limits = limits
        self.firedKeys = firedKeys
        self.lastKeys = lastKeys
        self.events = events
    }

    func limit(for period: LimitPeriod) -> UsageLimit? {
        limits.first(where: { $0.period == period })
    }

    mutating func setMode(_ mode: LimitMode, for period: LimitPeriod) {
        guard let index = limits.firstIndex(where: { $0.period == period }) else { return }
        limits[index].mode = mode
    }

    mutating func setExplicit(_ value: Int, for period: LimitPeriod) {
        setMode(.explicit(max(0, value)), for: period)
    }
}

enum UsageLimits {
    static var directoryOverride: URL?

    static func load() -> UsageLimitsState {
        guard let data = try? Data(contentsOf: fileURL()) else { return UsageLimitsState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let state = try? decoder.decode(UsageLimitsState.self, from: data) { return state }
        return UsageLimitsState()
    }

    static func save(_ state: UsageLimitsState) {
        let url = fileURL()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func fileURL() -> URL {
        cacheDirectory().appendingPathComponent("usage-limits.json")
    }

    private static func cacheDirectory() -> URL {
        if let directoryOverride { return directoryOverride }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ProjectHub/usage-limits", isDirectory: true)
    }

    static func currentKey(for period: LimitPeriod, now: Date = Date()) -> String {
        switch period {
        case .day:
            let format = DateFormatter()
            format.dateFormat = "yyyy-MM-dd"
            return format.string(from: now)
        case .week:
            let iso = Calendar(identifier: .iso8601)
            let parts = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
        case .month:
            let format = DateFormatter()
            format.dateFormat = "yyyy-MM"
            return format.string(from: now)
        }
    }

    static func used(for period: LimitPeriod, now: Date = Date()) -> (key: String, tokens: Int) {
        let key = currentKey(for: period, now: now)
        switch period {
        case .day:
            let row = UsageReader.dailyBreakdown().first(where: { $0.key == key })
            return (key, row?.totals.tokens ?? 0)
        case .week:
            let row = UsageReader.weeklyBreakdown().first(where: { $0.key == key })
            return (key, row?.totals.tokens ?? 0)
        case .month:
            let row = UsageReader.monthlyBreakdown().first(where: { $0.key == key })
            return (key, row?.totals.tokens ?? 0)
        }
    }

    static func cap(for limit: UsageLimit, currentKey: String) -> Int? {
        switch limit.mode {
        case .explicit(let value):
            return value > 0 ? value : nil
        case .maxPrevious:
            let rows: [UsageReader.UsageBreakdownRow]
            switch limit.period {
            case .day: rows = UsageReader.dailyBreakdown()
            case .week: rows = UsageReader.weeklyBreakdown()
            case .month: rows = UsageReader.monthlyBreakdown()
            }
            let best = rows.filter { $0.key != currentKey }.map(\.totals.tokens).max() ?? 0
            return best > 0 ? best : nil
        }
    }

    static func progress(for period: LimitPeriod, state: UsageLimitsState, now: Date = Date()) -> LimitProgress? {
        guard let limit = state.limit(for: period) else { return nil }
        let current = used(for: period, now: now)
        guard let resolved = cap(for: limit, currentKey: current.key) else { return nil }
        return LimitProgress(period: period, periodKey: current.key, used: current.tokens, cap: resolved)
    }

    static func progressAll(state: UsageLimitsState, now: Date = Date()) -> [LimitProgress] {
        LimitPeriod.allCases.compactMap { progress(for: $0, state: state, now: now) }
    }

    static func poll(_ state: inout UsageLimitsState, now: Date = Date()) -> [ThresholdEvent] {
        var fresh: [ThresholdEvent] = []
        for limit in state.limits {
            let current = used(for: limit.period, now: now)
            if state.lastKeys[limit.period.rawValue] != current.key {
                let seenBefore = state.lastKeys[limit.period.rawValue] != nil
                state.lastKeys[limit.period.rawValue] = current.key
                if seenBefore {
                    let event = ThresholdEvent(
                        key: "\(limit.period.rawValue)|\(current.key)|reset",
                        period: limit.period,
                        periodKey: current.key,
                        threshold: nil,
                        kind: .reset,
                        date: now
                    )
                    if !state.events.contains(where: { $0.key == event.key }) {
                        state.events.append(event)
                        fresh.append(event)
                    }
                }
            }
            guard let resolved = cap(for: limit, currentKey: current.key) else { continue }
            let advance = LimitProgress(period: limit.period, periodKey: current.key, used: current.tokens, cap: resolved)
            for threshold in limit.thresholds.sorted() {
                guard advance.percent >= Double(threshold) else { continue }
                let key = "\(limit.period.rawValue)|\(current.key)|\(threshold)"
                if state.firedKeys.contains(key) { continue }
                state.firedKeys.insert(key)
                let event = ThresholdEvent(
                    key: key,
                    period: limit.period,
                    periodKey: current.key,
                    threshold: threshold,
                    kind: .crossed,
                    date: now
                )
                state.events.append(event)
                fresh.append(event)
            }
        }
        state.events.sort { $0.date > $1.date }
        if state.events.count > 30 { state.events = Array(state.events.prefix(30)) }
        return fresh
    }
}
