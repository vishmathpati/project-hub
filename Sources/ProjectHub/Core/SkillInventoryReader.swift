import Foundation

enum SkillInventoryReader {
    static func installedSkills(for projectPath: String) -> [InstalledSkill] {
        let inventory = CompatibilityScanner.skillInventory(projectRoot: projectPath)
        let surfacesByID = inventory.matrix.reduce(into: [String: CompatibilityMatrixEntry]()) { partial, surface in
            if partial[surface.id] == nil {
                partial[surface.id] = surface
            }
        }
        let canonicalProjectRoot = inventory.projectRoot.map(Project.canonicalize) ?? Project.canonicalize(projectPath)
        let grouped = Dictionary(grouping: inventory.skills) { skill in
            canonicalFilePath(skill.path)
        }
        let duplicateKeys = duplicateSkillKeys(in: inventory.skills)
        let versionConflictKeys = versionConflictSkillKeys(in: inventory.skills)

        return grouped.compactMap { canonicalPath, observations in
            guard let first = observations.sorted(by: skillSort).first else { return nil }
            let surfaces = observations.compactMap { surfacesByID[$0.surfaceID] }
            let surface = surfaces.sorted(by: surfaceSort).first
            let toolLabels = uniqueStrings(
                observations.flatMap { $0.availableIn.map(\.label) }
            )
            let sourceLabels = uniqueStrings(surfaces.map(\.label))
            let canWriteSurface = surfaces.contains {
                $0.canWriteSafely && $0.writeMethod == .file && $0.path != nil
            }
            let isInsideProject = canonicalPath == canonicalProjectRoot
                || canonicalPath.hasPrefix(canonicalProjectRoot + "/")
            let canMutate = canWriteSurface && isInsideProject
            let state = state(for: observations)
            let diagnostics = diagnostics(
                for: observations,
                duplicateKeys: duplicateKeys,
                versionConflictKeys: versionConflictKeys
            )
            let skillMDPath = (first.path as NSString).appendingPathComponent("SKILL.md")
            let readOnlyReason: String?
            if canMutate {
                readOnlyReason = nil
            } else if !isInsideProject {
                readOnlyReason = "This skill is outside the selected project root."
            } else if surfaces.contains(where: { $0.writeMethod == .appUI || $0.canWriteSafely == false }) {
                readOnlyReason = "This skill is owned by a plugin, managed policy, or app UI."
            } else {
                readOnlyReason = "Project Hub does not have a safe write path for this skill source."
            }

            return InstalledSkill(
                originID: canonicalPath,
                name: first.name,
                description: first.description,
                claudePath: observations.contains { $0.toolID == .claudeCode } ? first.path : nil,
                codexPath: observations.contains { $0.toolID == .codexCLI || $0.toolID == .codexDesktop } ? first.path : nil,
                path: first.path,
                skillMDPath: skillMDPath,
                sourceLabel: sourceLabels.first ?? surface?.label ?? "Skill source",
                scopeLabel: scopeLabel(surface?.scope ?? first.scope),
                toolLabels: toolLabels,
                state: state,
                version: first.version,
                diagnostics: diagnostics,
                canEdit: canMutate,
                canRemove: canMutate,
                readOnlyReason: readOnlyReason
            )
        }
        .sorted { lhs, rhs in
            if lhs.name.localizedCaseInsensitiveCompare(rhs.name) != .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
    }

    private static func state(for observations: [CompatibilitySkillObservation]) -> InstalledSkill.State {
        if observations.contains(where: { !$0.parseOK }) {
            return .invalid
        }
        if observations.contains(where: { $0.enabledOverride == false || $0.claudeOverrideState == "off" }) {
            return .disabled
        }
        if observations.contains(where: {
            $0.claudeOverrideState == "name-only"
                || $0.claudeOverrideState == "user-invocable-only"
                || $0.allowImplicitInvocation == false
                || $0.claudeDisableModelInvocation == true
        }) {
            return .limited
        }
        return .active
    }

    private static func skillSort(_ lhs: CompatibilitySkillObservation, _ rhs: CompatibilitySkillObservation) -> Bool {
        if lhs.toolID.rawValue != rhs.toolID.rawValue { return lhs.toolID.rawValue < rhs.toolID.rawValue }
        return lhs.surfaceID < rhs.surfaceID
    }

    private static func surfaceSort(_ lhs: CompatibilityMatrixEntry, _ rhs: CompatibilityMatrixEntry) -> Bool {
        if lhs.precedence != rhs.precedence { return lhs.precedence < rhs.precedence }
        return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values where seen.insert(value).inserted {
            output.append(value)
        }
        return output
    }

    private static func duplicateSkillKeys(in observations: [CompatibilitySkillObservation]) -> Set<String> {
        let groups = Dictionary(grouping: observations, by: skillConflictKey)
        return Set(groups.compactMap { key, group in
            let paths = Set(group.map { canonicalFilePath($0.path) })
            return paths.count > 1 ? key : nil
        })
    }

    private static func versionConflictSkillKeys(in observations: [CompatibilitySkillObservation]) -> Set<String> {
        let groups = Dictionary(grouping: observations.filter { $0.version != nil }, by: skillConflictKey)
        return Set(groups.compactMap { key, group in
            let versions = Set(group.compactMap(\.version))
            let paths = Set(group.map { canonicalFilePath($0.path) })
            return versions.count > 1 && paths.count > 1 ? key : nil
        })
    }

    private static func diagnostics(
        for observations: [CompatibilitySkillObservation],
        duplicateKeys: Set<String>,
        versionConflictKeys: Set<String>
    ) -> [String] {
        var output: [String] = []
        let keys = Set(observations.map(skillConflictKey))
        if !keys.isDisjoint(with: duplicateKeys) {
            output.append("Duplicate name")
        }
        if !keys.isDisjoint(with: versionConflictKeys) {
            output.append("Version conflict")
        }
        return output
    }

    private static func skillConflictKey(_ skill: CompatibilitySkillObservation) -> String {
        "\(skill.toolID.rawValue):\(skill.name)"
    }

    private static func scopeLabel(_ scope: CompatibilityScope) -> String {
        switch scope {
        case .global: return "Global"
        case .project: return "Project"
        case .localProjectUser: return "Private"
        case .desktopApp: return "Desktop"
        case .account: return "Account"
        case .runtime: return "Runtime"
        }
    }

    private static func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }
}
