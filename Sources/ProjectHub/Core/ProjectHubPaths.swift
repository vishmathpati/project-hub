import Foundation

enum ProjectHubPaths {
    static func codexHome(home: String = FileManager.default.homeDirectoryForCurrentUser.path) -> String {
        let raw = ProcessInfo.processInfo.environment["CODEX_HOME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen = raw?.isEmpty == false ? raw! : (home as NSString).appendingPathComponent(".codex")
        return URL(fileURLWithPath: (chosen as NSString).expandingTildeInPath)
            .standardizedFileURL
            .path
    }
}
