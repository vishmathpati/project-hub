import CryptoKit
import Foundation

/// Last Compatibility scan on disk so pages do not start empty after relaunch.
enum ConfigScanCache {
    static var directoryOverride: URL?

    static func load(projectRoot: String?, profileName: String? = nil) -> CompatibilityScanResult? {
        let url = fileURL(projectRoot: projectRoot, profileName: profileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CompatibilityScanResult.self, from: data)
    }

    static func save(_ result: CompatibilityScanResult) {
        let url = fileURL(
            projectRoot: result.projectRoot,
            profileName: result.codexProfileSelection?.name
        )
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(result) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func fileURL(projectRoot: String?, profileName: String?) -> URL {
        cacheDirectory().appendingPathComponent("\(cacheKey(projectRoot: projectRoot, profileName: profileName)).json")
    }

    static func cacheKey(projectRoot: String?, profileName: String?) -> String {
        let raw = [
            projectRoot?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "global",
            profileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ].joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func cacheDirectory() -> URL {
        if let directoryOverride { return directoryOverride }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ProjectHub/scan-cache", isDirectory: true)
    }
}
