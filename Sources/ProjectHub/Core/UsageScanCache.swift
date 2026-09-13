import Foundation

/// Per-file cache of parsed usage records, modelled on t3code's
/// `usage-scan-cache.json` (pingdotgg/t3code): each entry records the file's size
/// and modified date, and reuse is decided from those two values alone.
///
/// This is what makes counting every usage event affordable. Re-parsing the raw
/// logs on each refresh costs tens of seconds, which is why the reader used to
/// keep only one event per session and under-reported a week of Codex usage by
/// two orders of magnitude.
enum UsageScanCache {
    static var directoryOverride: URL?

    struct Record: Codable {
        let date: Date
        let model: String?
        let requestID: String?
        let input: Int
        let cacheWrite: Int
        let cacheRead: Int
        let output: Int
        let cost: Double
    }

    struct FileEntry: Codable {
        var size: Int
        var modified: Double
        var offset: Int
        var records: [Record]
    }

    private struct Document: Codable {
        var version: Int
        var files: [String: FileEntry]
    }

    private static let lock = NSLock()
    private static var loaded: Document?

    /// True when the cached entry still describes the file on disk, so its records
    /// can be reused without opening it.
    static func entry(for path: String, size: Int, modified: Double) -> FileEntry? {
        lock.lock()
        defer { lock.unlock() }
        guard let hit = current().files[path], hit.size == size, hit.modified == modified else {
            return nil
        }
        return hit
    }

    static func store(_ entry: FileEntry, for path: String) {
        lock.lock()
        loaded?.files[path] = entry
        lock.unlock()
    }

    /// Persists. Deliberately does not prune: `loadEvents` runs once per provider
    /// root, so pruning to the current call's file list would erase the other
    /// provider's entries on every refresh. An entry for a deleted file is never
    /// read, because the file is no longer enumerated.
    static func commit() {
        lock.lock()
        let document = current()
        lock.unlock()

        let directory = cacheDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(document) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func current() -> Document {
        if let loaded { return loaded }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: Document
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(Document.self, from: data) {
            document = decoded
        } else {
            document = Document(version: 1, files: [:])
        }
        loaded = document
        return document
    }

    private static var fileURL: URL {
        cacheDirectory().appendingPathComponent("usage-scan-cache.json")
    }

    private static func cacheDirectory() -> URL {
        if let directoryOverride { return directoryOverride }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ProjectHub/scan-cache", isDirectory: true)
    }
}
