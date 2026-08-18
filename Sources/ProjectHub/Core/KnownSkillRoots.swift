import Foundation

/// Official skill folders only. Never walk a whole project tree.
enum KnownSkillRoots {
    static let skippedDirectoryNames: Set<String> = [
        ".git",
        ".build",
        ".swiftpm",
        "SourcePackages",
        "checkouts",
        "DerivedData",
        "node_modules",
        "build",
        "dist",
        ".next",
        "vendor",
        ".npm",
        ".yarn",
        ".gradle",
        "__pycache__",
        "Pods",
        "target",
        ".cache",
        ".venv",
        "venv",
        "Library",
        ".t3",
        ".Trash"
    ]

    static func existingNestedClaudeSkillDirectories(
        from start: URL,
        excluding excludedPaths: Set<String>,
        maxDepth: Int = 6,
        maxDirectoriesVisited: Int = 256
    ) -> [URL] {
        let fm = FileManager.default
        var roots: [URL] = []
        var visited = 0

        func visit(_ directory: URL, depth: Int) {
            guard visited < maxDirectoriesVisited, depth <= maxDepth else { return }
            visited += 1

            let name = directory.lastPathComponent
            if skippedDirectoryNames.contains(name) { return }

            let skills = directory
                .appendingPathComponent(".claude", isDirectory: true)
                .appendingPathComponent("skills", isDirectory: true)
            if isDirectory(skills, fm: fm), !excludedPaths.contains(skills.path) {
                roots.append(skills)
            }

            guard depth < maxDepth,
                  let children = try? fm.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: []
                  ) else {
                return
            }

            for child in children {
                let childName = child.lastPathComponent
                if skippedDirectoryNames.contains(childName) || childName == ".claude" {
                    continue
                }
                guard isVisitableDirectory(child, fm: fm) else { continue }
                visit(child, depth: depth + 1)
            }
        }

        visit(start, depth: 0)
        return roots.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    private static func isVisitableDirectory(_ url: URL, fm: FileManager) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if values?.isSymbolicLink == true { return false }
        if values?.isDirectory == true { return true }
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func isDirectory(_ url: URL, fm: FileManager) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
