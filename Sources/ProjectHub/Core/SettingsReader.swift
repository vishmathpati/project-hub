import Foundation

// MARK: - User settings model

struct PermissionSection {
    var allow: [String] = []
    var deny: [String] = []
    var ask: [String] = []
    var additionalDirectories: [String] = []
}

struct BehaviourSection {
    var model: String? = nil
    var cleanupPeriodDays: Int? = nil
    var enableAllProjectMcpServers: Bool? = nil
    var enabledMcpjsonServers: [String] = []
    var disabledMcpjsonServers: [String] = []
}

struct UISection {
    var statusLine: String? = nil
    var outputStyle: String? = nil
    var spinnerMode: String? = nil
    var spinnerVerbs: [String] = []
}

struct UserSettings {
    var permissions = PermissionSection()
    var behaviour = BehaviourSection()
    var ui = UISection()
    var env: [String: String] = [:]
    var hookEvents: [String] = []
}

struct LoadedUserSettings {
    let path: String
    let text: String
    let root: [String: Any]
    let model: UserSettings
}

enum SettingsReadError: Error, LocalizedError {
    case missing(String)
    case unreadable(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .missing(let p):    return "Settings file not found at \(p)"
        case .unreadable(let m): return "Could not read settings: \(m)"
        case .invalid(let m):    return "Settings is not valid JSON: \(m)"
        }
    }
}

// MARK: - Settings reader

enum SettingsReader {

    static func settingsPath() -> String {
        (NSHomeDirectory() as NSString).appendingPathComponent(".claude/settings.json")
    }

    static func load() throws -> LoadedUserSettings {
        let path = settingsPath()
        guard FileManager.default.fileExists(atPath: path) else {
            throw SettingsReadError.missing(path)
        }
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw SettingsReadError.unreadable(path)
        }
        let stripped = ConfigWriter.stripJsonComments(raw)
        guard let data = stripped.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SettingsReadError.invalid(path)
        }
        return LoadedUserSettings(path: path, text: raw, root: root, model: parse(root))
    }

    static func parse(_ root: [String: Any]) -> UserSettings {
        var out = UserSettings()
        let perms = root["permissions"] as? [String: Any] ?? [:]
        out.permissions.allow = stringArray(perms["allow"])
        out.permissions.deny = stringArray(perms["deny"])
        out.permissions.ask = stringArray(perms["ask"])
        out.permissions.additionalDirectories = stringArray(perms["additionalDirectories"])
        if out.permissions.additionalDirectories.isEmpty {
            out.permissions.additionalDirectories = stringArray(root["additionalDirectories"])
        }
        out.behaviour.model = (root["model"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        out.behaviour.cleanupPeriodDays = intValue(root["cleanupPeriodDays"])
        out.behaviour.enableAllProjectMcpServers = boolValue(root["enableAllProjectMcpServers"])
        out.behaviour.enabledMcpjsonServers = stringArray(root["enabledMcpjsonServers"])
        out.behaviour.disabledMcpjsonServers = stringArray(root["disabledMcpjsonServers"])
        out.ui.statusLine = statusLineCommand(root["statusLine"])
        out.ui.outputStyle = (root["outputStyle"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let spinner = root["spinnerVerbs"]
        if let dict = spinner as? [String: Any] {
            out.ui.spinnerMode = (dict["mode"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            out.ui.spinnerVerbs = stringArray(dict["verbs"])
        } else {
            out.ui.spinnerVerbs = stringArray(spinner)
        }
        out.env = stringDictionary(root["env"])
        out.hookEvents = ((root["hooks"] as? [String: Any]) ?? [:]).keys.sorted()
        return out
    }

    static func jsonText(for root: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func rootWithPermissions(_ root: [String: Any], _ p: PermissionSection) -> [String: Any] {
        var out = root
        var perms = out["permissions"] as? [String: Any] ?? [:]
        perms["allow"] = p.allow
        perms["deny"] = p.deny
        perms["ask"] = p.ask
        perms["additionalDirectories"] = p.additionalDirectories
        out["permissions"] = perms
        return out
    }

    static func rootWithBehaviour(_ root: [String: Any], _ b: BehaviourSection) -> [String: Any] {
        var out = root
        if let v = b.model, !v.isEmpty { out["model"] = v } else { out.removeValue(forKey: "model") }
        if let v = b.cleanupPeriodDays { out["cleanupPeriodDays"] = v } else { out.removeValue(forKey: "cleanupPeriodDays") }
        if let v = b.enableAllProjectMcpServers { out["enableAllProjectMcpServers"] = v } else { out.removeValue(forKey: "enableAllProjectMcpServers") }
        out["enabledMcpjsonServers"] = b.enabledMcpjsonServers
        out["disabledMcpjsonServers"] = b.disabledMcpjsonServers
        return out
    }

    static func rootWithUI(_ root: [String: Any], _ u: UISection) -> [String: Any] {
        var out = root
        if let cmd = u.statusLine, !cmd.isEmpty {
            if var dict = out["statusLine"] as? [String: Any] {
                dict["command"] = cmd
                out["statusLine"] = dict
            } else {
                out["statusLine"] = cmd
            }
        } else {
            out.removeValue(forKey: "statusLine")
        }
        if let v = u.outputStyle, !v.isEmpty { out["outputStyle"] = v } else { out.removeValue(forKey: "outputStyle") }
        if u.spinnerVerbs.isEmpty, u.spinnerMode == nil {
            out.removeValue(forKey: "spinnerVerbs")
        } else {
            var dict = out["spinnerVerbs"] as? [String: Any] ?? [:]
            if let m = u.spinnerMode, !m.isEmpty { dict["mode"] = m } else { dict.removeValue(forKey: "mode") }
            dict["verbs"] = u.spinnerVerbs
            out["spinnerVerbs"] = dict
        }
        return out
    }

    static func rootWithEnv(_ root: [String: Any], _ env: [String: String]) -> [String: Any] {
        var out = root
        if env.isEmpty { out.removeValue(forKey: "env") } else { out["env"] = env }
        return out
    }

    private static func statusLineCommand(_ value: Any?) -> String? {
        if let s = value as? String { return s.isEmpty ? nil : s }
        if let dict = value as? [String: Any], let cmd = dict["command"] as? String, !cmd.isEmpty { return cmd }
        return nil
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        if let any = value as? [Any] { return any.compactMap { $0 as? String } }
        return []
    }

    private static func stringDictionary(_ value: Any?) -> [String: String] {
        guard let dict = value as? [String: Any] else { return [:] }
        return Dictionary(uniqueKeysWithValues: dict.map { ($0.key, "\($0.value)") })
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        if let s = value as? String {
            switch s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }
}
