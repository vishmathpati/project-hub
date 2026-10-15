import Foundation

enum ContextReductionAction: Equatable, Sendable {
    case enableClaudeToolSearch(projectPath: String)
    case makeClaudeSkillUserInvocableOnly(projectPath: String, skillName: String, skillSourcePath: String)

    var projectPath: String {
        switch self {
        case .enableClaudeToolSearch(let projectPath),
             .makeClaudeSkillUserInvocableOnly(let projectPath, _, _): projectPath
        }
    }
}

struct ContextChangePreview: Identifiable, Equatable, Sendable {
    var id: String { "\(targetPath)|\(after.hashValue)" }
    let action: ContextReductionAction
    let title: String
    let explanation: String
    let targetPath: String
    let before: String
    let after: String
    let existedBefore: Bool
}

struct ContextChangeReceipt: Equatable, Sendable {
    let preview: ContextChangePreview
    let appliedAt: Date
}

enum ContextActionError: LocalizedError, Equatable {
    case invalidProject(String)
    case targetOutsideProject(String)
    case symlinkTarget(String)
    case unreadable(String)
    case malformedJSON(String)
    case unsupportedShape(String)
    case ineligibleSkill(String)
    case stale(String)

    var errorDescription: String? {
        switch self {
        case .invalidProject(let path): "Project folder is unavailable: \(path)"
        case .targetOutsideProject(let path): "Refusing a settings target outside the project: \(path)"
        case .symlinkTarget(let path): "Refusing a settings path that crosses a symbolic link: \(path)"
        case .unreadable(let path): "The settings file is not readable: \(path)"
        case .malformedJSON(let path): "The settings file is not a valid JSON object: \(path)"
        case .unsupportedShape(let key): "The existing \(key) setting has an unsupported shape."
        case .ineligibleSkill(let name): "\(name) is not an unambiguous standalone Claude skill."
        case .stale(let path): "The settings file changed after preview. Review a fresh preview before applying: \(path)"
        }
    }
}

enum ContextActions {
    static func preview(_ action: ContextReductionAction) throws -> ContextChangePreview {
        try validateSkillIdentity(for: action)
        let target = try validatedTarget(projectPath: action.projectPath)
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: target)
        let before: String
        var root: [String: Any]
        if exists {
            guard fm.isReadableFile(atPath: target),
                  let data = fm.contents(atPath: target),
                  let text = String(data: data, encoding: .utf8) else {
                throw ContextActionError.unreadable(target)
            }
            guard let object = try? JSONSerialization.jsonObject(with: data),
                  let dictionary = object as? [String: Any] else {
                throw ContextActionError.malformedJSON(target)
            }
            before = text
            root = dictionary
        } else {
            before = ""
            root = [:]
        }

        let title: String
        let explanation: String
        switch action {
        case .enableClaudeToolSearch:
            var environment: [String: Any]
            if let existing = root["env"] {
                guard let dictionary = existing as? [String: Any] else {
                    throw ContextActionError.unsupportedShape("env")
                }
                environment = dictionary
            } else {
                environment = [:]
            }
            environment["ENABLE_TOOL_SEARCH"] = "true"
            root["env"] = environment
            title = "Enable MCP tool search for this project"
            explanation = "Claude can defer eligible MCP tool schemas when the selected model and proxy support tool search. This does not guarantee a token reduction."

        case .makeClaudeSkillUserInvocableOnly(_, let rawName, _):
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !name.contains(":"), !name.contains("/"), name != ".", name != ".." else {
                throw ContextActionError.ineligibleSkill(rawName)
            }
            var overrides: [String: Any]
            if let existing = root["skillOverrides"] {
                guard let dictionary = existing as? [String: Any] else {
                    throw ContextActionError.unsupportedShape("skillOverrides")
                }
                overrides = dictionary
            } else {
                overrides = [:]
            }
            overrides[name] = "user-invocable-only"
            root["skillOverrides"] = overrides
            title = "Load \(name) only when invoked"
            explanation = "Claude will keep this standalone skill available for explicit invocation without loading it automatically. Plugin skills are not eligible."
        }

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        let after = String(decoding: data, as: UTF8.self) + "\n"
        return .init(
            action: action,
            title: title,
            explanation: explanation,
            targetPath: target,
            before: before,
            after: after,
            existedBefore: exists
        )
    }

    static func apply(_ preview: ContextChangePreview) throws -> ContextChangeReceipt {
        try validateSkillIdentity(for: preview.action)
        let target = try validatedTarget(projectPath: preview.action.projectPath)
        guard target == preview.targetPath else { throw ContextActionError.targetOutsideProject(preview.targetPath) }
        let exists = FileManager.default.fileExists(atPath: target)
        let current = try exactCurrentText(at: target)
        if current == preview.after {
            return .init(preview: preview, appliedAt: Date())
        }
        guard exists == preview.existedBefore else { throw ContextActionError.stale(target) }
        guard current == preview.before else { throw ContextActionError.stale(target) }
        try ConfigWriter.applyTextPreview(
            configPath: target,
            expectedBefore: preview.before,
            approvedAfter: preview.after
        )
        return .init(preview: preview, appliedAt: Date())
    }

    static func undo(_ receipt: ContextChangeReceipt) throws {
        let preview = receipt.preview
        let target = try validatedTarget(projectPath: preview.action.projectPath)
        guard target == preview.targetPath else { throw ContextActionError.targetOutsideProject(preview.targetPath) }
        let fm = FileManager.default
        if !preview.existedBefore, !fm.fileExists(atPath: target) { return }
        let current = try exactCurrentText(at: target)
        if preview.existedBefore, current == preview.before { return }
        guard current == preview.after else { throw ContextActionError.stale(target) }

        if preview.existedBefore {
            try ConfigWriter.applyTextPreview(
                configPath: target,
                expectedBefore: preview.after,
                approvedAfter: preview.before
            )
        } else {
            try fm.removeItem(atPath: target)
        }
    }

    private static func exactCurrentText(at path: String) throws -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return "" }
        guard fm.isReadableFile(atPath: path),
              let data = fm.contents(atPath: path),
              let text = String(data: data, encoding: .utf8) else {
            throw ContextActionError.unreadable(path)
        }
        return text
    }

    private static func validateSkillIdentity(for action: ContextReductionAction) throws {
        guard case .makeClaudeSkillUserInvocableOnly(let projectPath, let rawName, let sourcePath) = action else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains(":"), !name.contains("/"), name != ".", name != ".." else {
            throw ContextActionError.ineligibleSkill(rawName)
        }
        let homes = ContextProviderHomes.current()
        let roots = [
            (projectPath as NSString).appendingPathComponent(".claude/skills"),
            (homes.claude as NSString).appendingPathComponent("skills"),
        ]
        let resolvedSource = URL(fileURLWithPath: sourcePath).standardizedFileURL.resolvingSymlinksInPath().path
        guard (resolvedSource as NSString).lastPathComponent == "SKILL.md",
              roots.contains(where: { root in
                  let resolvedRoot = URL(fileURLWithPath: root).standardizedFileURL.resolvingSymlinksInPath().path
                  let skillDirectory = (resolvedSource as NSString).deletingLastPathComponent
                  return (skillDirectory as NSString).deletingLastPathComponent == resolvedRoot
              }),
              let parsed = SkillReader.parse(at: resolvedSource), parsed.name == name else {
            throw ContextActionError.ineligibleSkill(rawName)
        }
        let matches = roots.flatMap { SkillReader.scanSkillDir($0, source: .claudeGlobal) }
            .filter { $0.name == name }
        guard matches.count == 1,
              URL(fileURLWithPath: (matches[0].path as NSString).appendingPathComponent("SKILL.md"))
                .standardizedFileURL.resolvingSymlinksInPath().path == resolvedSource else {
            throw ContextActionError.ineligibleSkill(rawName)
        }
    }

    private static func validatedTarget(projectPath: String) throws -> String {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: projectPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ContextActionError.invalidProject(projectPath)
        }
        let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath()
        let lexicalTarget = projectURL.appendingPathComponent(".claude/settings.local.json").standardizedFileURL
        var cursor = lexicalTarget.deletingLastPathComponent()
        while cursor.path != projectURL.path {
            if fm.fileExists(atPath: cursor.path) {
                let values = try? cursor.resourceValues(forKeys: [.isSymbolicLinkKey])
                if values?.isSymbolicLink == true { throw ContextActionError.symlinkTarget(cursor.path) }
            }
            let parent = cursor.deletingLastPathComponent()
            if parent.path == cursor.path { throw ContextActionError.targetOutsideProject(lexicalTarget.path) }
            cursor = parent
        }
        if fm.fileExists(atPath: lexicalTarget.path) {
            let values = try? lexicalTarget.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
            if values?.isSymbolicLink == true { throw ContextActionError.symlinkTarget(lexicalTarget.path) }
            if values?.isRegularFile != true { throw ContextActionError.unreadable(lexicalTarget.path) }
        }
        let resolved = lexicalTarget.resolvingSymlinksInPath().path
        guard resolved.hasPrefix(projectURL.path + "/") else {
            throw ContextActionError.targetOutsideProject(resolved)
        }
        return lexicalTarget.path
    }
}
