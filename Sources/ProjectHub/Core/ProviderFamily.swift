enum ProviderFamily {
    static func groupID(for toolID: String) -> String {
        switch toolID {
        case "claude-code", "claude-desktop":
            return "claude"
        default:
            return toolID
        }
    }

    static func grouped<T>(_ items: [T], id: KeyPath<T, String>) -> [(id: String, items: [T])] {
        var order: [String] = []
        var buckets: [String: [T]] = [:]
        for item in items {
            let gid = groupID(for: item[keyPath: id])
            if buckets[gid] == nil { order.append(gid) }
            buckets[gid, default: []].append(item)
        }
        return order.map { (id: $0, items: buckets[$0] ?? []) }
    }

    static func uniqueTileIDs(from toolIDs: [String]) -> [String] {
        var ids: [String] = []
        for toolID in toolIDs {
            let tile = iconToolID(for: groupID(for: toolID))
            if !ids.contains(tile) { ids.append(tile) }
        }
        return ids
    }

    static func displayName(for groupID: String) -> String {
        switch groupID {
        case "claude":
            return "Claude"
        default:
            return ToolPalette.label(for: groupID)
        }
    }

    static func iconToolID(for groupID: String) -> String {
        switch groupID {
        case "claude":
            return "claude-code"
        default:
            return groupID
        }
    }

    static func memberLabel(for toolID: String) -> String {
        switch toolID {
        case "claude-code":
            return "Code"
        case "claude-desktop":
            return "Desktop"
        default:
            return ToolPalette.label(for: toolID)
        }
    }
}
