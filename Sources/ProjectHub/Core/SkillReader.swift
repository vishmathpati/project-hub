import Foundation

// MARK: - Skill parsing helpers

enum SkillReader {
    struct OpenAIMetadata: Equatable {
        struct ToolDependency: Equatable {
            let type: String
            let value: String
            let description: String?
            let transport: String?
            let url: String?
        }

        let displayName: String?
        let shortDescription: String?
        let iconSmall: String?
        let iconLarge: String?
        let brandColor: String?
        let defaultPrompt: String?
        let allowImplicitInvocation: Bool?
        let toolDependencies: [ToolDependency]
    }

    struct ClaudeMetadata: Equatable {
        let whenToUse: String?
        let allowedTools: [String]
        let disableModelInvocation: Bool?
        let userInvocable: Bool?
        let argumentHint: String?
        let arguments: [String]
        let model: String?
        let effort: String?
        let context: String?
        let agent: String?
        let paths: [String]
        let shell: String?
        let hooks: String?
    }

    /// Parse a SKILL.md file at the given path. Returns nil if the file can't be read
    /// or doesn't have a valid frontmatter block.
    static func parse(at filePath: String) -> (name: String, description: String, triggers: [String])? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }
        guard let fm = parseFrontmatter(content) else { return nil }

        let name        = fm["name"] ?? ((filePath as NSString).deletingLastPathComponent as NSString).lastPathComponent
        let description = fm["description"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let triggers    = parseTriggers(from: content)

        return (name: name, description: description, triggers: triggers)
    }

    /// Scan a directory for skill subdirectories (each containing a SKILL.md).
    static func scanSkillDir(_ dirPath: String, source: SkillSource) -> [Skill] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dirPath) else { return [] }

        var skills: [Skill] = []
        for entry in entries.sorted() {
            let skillDir = (dirPath as NSString).appendingPathComponent(entry)
            let skillMd  = (skillDir as NSString).appendingPathComponent("SKILL.md")
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: skillDir, isDirectory: &isDir), isDir.boolValue else { continue }
            guard fm.fileExists(atPath: skillMd) else { continue }

            if let parsed = parse(at: skillMd) {
                skills.append(Skill(
                    name:        parsed.name,
                    description: parsed.description,
                    triggers:    parsed.triggers,
                    source:      source,
                    path:        skillDir
                ))
            }
        }
        return skills
    }

    static func parseOpenAIMetadata(at skillDirectory: String) -> OpenAIMetadata? {
        let metadataPath = (skillDirectory as NSString)
            .appendingPathComponent("agents/openai.yaml")
        return parseOpenAIMetadataFile(at: metadataPath)
    }

    static func parseClaudeMetadata(at skillDirectory: String) -> ClaudeMetadata? {
        let skillMD = (skillDirectory as NSString).appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOfFile: skillMD, encoding: .utf8),
              let frontmatter = parseFrontmatter(content) else {
            return nil
        }

        let metadata = ClaudeMetadata(
            whenToUse: frontmatter.firstValue(for: ["when_to_use", "when-to-use"]),
            allowedTools: parseListLike(frontmatter.firstValue(for: ["allowed-tools", "allowed_tools"]), splitOnWhitespace: true),
            disableModelInvocation: frontmatter.boolValue(for: ["disable-model-invocation", "disable_model_invocation"]),
            userInvocable: frontmatter.boolValue(for: ["user-invocable", "user_invocable"]),
            argumentHint: frontmatter.firstValue(for: ["argument-hint", "argument_hint"]),
            arguments: parseListLike(frontmatter.firstValue(for: ["arguments"]), splitOnWhitespace: true),
            model: frontmatter.firstValue(for: ["model"]),
            effort: frontmatter.firstValue(for: ["effort"]),
            context: frontmatter.firstValue(for: ["context"]),
            agent: frontmatter.firstValue(for: ["agent"]),
            paths: parseListLike(frontmatter.firstValue(for: ["paths"]), splitOnWhitespace: false),
            shell: frontmatter.firstValue(for: ["shell"]),
            hooks: frontmatter.firstValue(for: ["hooks"])
        )

        guard metadata.whenToUse != nil
                || !metadata.allowedTools.isEmpty
                || metadata.disableModelInvocation != nil
                || metadata.userInvocable != nil
                || metadata.argumentHint != nil
                || !metadata.arguments.isEmpty
                || metadata.model != nil
                || metadata.effort != nil
                || metadata.context != nil
                || metadata.agent != nil
                || !metadata.paths.isEmpty
                || metadata.shell != nil
                || metadata.hooks != nil else {
            return nil
        }
        return metadata
    }

    static func parseOpenAIMetadataFile(at filePath: String) -> OpenAIMetadata? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }

        var section: String?
        var inDependencyTools = false
        var currentTool: [String: String]?
        var displayName: String?
        var shortDescription: String?
        var iconSmall: String?
        var iconLarge: String?
        var brandColor: String?
        var defaultPrompt: String?
        var allowImplicitInvocation: Bool?
        var dependencies: [OpenAIMetadata.ToolDependency] = []

        func flushTool() {
            guard let tool = currentTool,
                  let type = tool["type"],
                  let value = tool["value"],
                  !type.isEmpty,
                  !value.isEmpty else {
                currentTool = nil
                return
            }
            dependencies.append(OpenAIMetadata.ToolDependency(
                type: type,
                value: value,
                description: tool["description"],
                transport: tool["transport"],
                url: tool["url"]
            ))
            currentTool = nil
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let withoutComment = stripYAMLComment(rawLine)
            let trimmed = withoutComment.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let indent = rawLine.prefix { $0 == " " || $0 == "\t" }.count
            if indent == 0, trimmed.hasSuffix(":") {
                flushTool()
                section = String(trimmed.dropLast())
                inDependencyTools = false
                continue
            }

            if section == "interface", indent > 0 {
                guard let pair = yamlPair(trimmed) else { continue }
                switch pair.key {
                case "display_name":
                    displayName = pair.value
                case "short_description":
                    shortDescription = pair.value
                case "icon_small":
                    iconSmall = pair.value
                case "icon_large":
                    iconLarge = pair.value
                case "brand_color":
                    brandColor = pair.value
                case "default_prompt":
                    defaultPrompt = pair.value
                default:
                    continue
                }
            } else if section == "policy", indent > 0 {
                guard let pair = yamlPair(trimmed), pair.key == "allow_implicit_invocation" else { continue }
                allowImplicitInvocation = yamlBool(pair.value)
            } else if section == "dependencies", indent > 0 {
                if trimmed == "tools:" {
                    inDependencyTools = true
                    continue
                }
                guard inDependencyTools else { continue }
                if trimmed.hasPrefix("- ") {
                    flushTool()
                    currentTool = [:]
                    let remainder = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if let pair = yamlPair(remainder) {
                        currentTool?[pair.key] = pair.value
                    }
                } else if currentTool != nil, let pair = yamlPair(trimmed) {
                    currentTool?[pair.key] = pair.value
                }
            }
        }
        flushTool()

        guard displayName != nil
                || shortDescription != nil
                || iconSmall != nil
                || iconLarge != nil
                || brandColor != nil
                || defaultPrompt != nil
                || allowImplicitInvocation != nil
                || !dependencies.isEmpty else {
            return nil
        }

        return OpenAIMetadata(
            displayName: displayName,
            shortDescription: shortDescription,
            iconSmall: iconSmall,
            iconLarge: iconLarge,
            brandColor: brandColor,
            defaultPrompt: defaultPrompt,
            allowImplicitInvocation: allowImplicitInvocation,
            toolDependencies: dependencies
        )
    }

    // MARK: - Frontmatter parser

    /// Extract YAML frontmatter between the first two `---` lines.
    /// Returns a flat [key: value] dictionary. Multi-line values (block scalars) are
    /// captured as-is by joining continuation lines.
    static func parseFrontmatter(_ content: String) -> [String: String]? {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var inFrontmatter = false
        var fmLines: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if !inFrontmatter {
                    inFrontmatter = true
                    continue
                } else {
                    break
                }
            }
            if inFrontmatter { fmLines.append(line) }
        }

        var result: [String: String] = [:]
        var currentKey: String? = nil
        var accumulator: [String] = []

        func flush() {
            guard let key = currentKey else { return }
            result[key] = accumulator.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            currentKey = nil
            accumulator = []
        }

        for line in fmLines {
            // A new top-level key: starts at column 0, contains `: `
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && line.contains(":") {
                flush()
                let colonIdx = line.firstIndex(of: ":")!
                let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                currentKey = key
                if !value.isEmpty && value != "|" && value != ">" {
                    accumulator.append(value)
                }
            } else if currentKey != nil {
                // Continuation / block scalar line
                accumulator.append(line.trimmingCharacters(in: .whitespaces))
            }
        }
        flush()
        return result.isEmpty ? nil : result
    }

    // MARK: - Triggers parser

    /// Parse `triggers:` list items (lines starting with `- `).
    private static func parseTriggers(from content: String) -> [String] {
        let lines = content.components(separatedBy: "\n")
        var inTriggers = false
        var triggers: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "triggers:" {
                inTriggers = true
                continue
            }
            if inTriggers {
                if trimmed.hasPrefix("- ") {
                    triggers.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines))
                } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    break  // end of triggers block
                }
            }
        }
        return triggers
    }

    private static func yamlPair(_ line: String) -> (key: String, value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
        var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2,
           (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }
        guard !key.isEmpty else { return nil }
        return (key, value)
    }

    private static func yamlBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "yes", "on":
            return true
        case "false", "no", "off":
            return false
        default:
            return nil
        }
    }

    private static func parseListLike(_ value: String?, splitOnWhitespace: Bool) -> [String] {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return []
        }

        value = unquote(value)
        if value.hasPrefix("[") && value.hasSuffix("]") {
            value = String(value.dropFirst().dropLast())
        }

        if value.contains("\n") {
            return value
                .components(separatedBy: .newlines)
                .map { line in
                    var item = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if item.hasPrefix("- ") {
                        item = String(item.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return unquote(item)
                }
                .filter { !$0.isEmpty }
        }

        let separators = splitOnWhitespace ? CharacterSet(charactersIn: ", \t") : CharacterSet(charactersIn: ",")
        return splitScalarList(value, separators: separators)
    }

    private static func splitScalarList(_ value: String, separators: CharacterSet) -> [String] {
        var items: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var parenDepth = 0

        for scalar in value.unicodeScalars {
            let character = Character(scalar)
            if character == "\"", !inSingle {
                inDouble.toggle()
                current.append(character)
                continue
            }
            if character == "'", !inDouble {
                inSingle.toggle()
                current.append(character)
                continue
            }
            if character == "(", !inSingle, !inDouble {
                parenDepth += 1
                current.append(character)
                continue
            }
            if character == ")", !inSingle, !inDouble {
                parenDepth = max(0, parenDepth - 1)
                current.append(character)
                continue
            }
            if separators.contains(scalar), !inSingle, !inDouble, parenDepth == 0 {
                let item = unquote(current.trimmingCharacters(in: .whitespacesAndNewlines))
                if !item.isEmpty {
                    items.append(item)
                }
                current = ""
                continue
            }
            current.append(character)
        }

        let item = unquote(current.trimmingCharacters(in: .whitespacesAndNewlines))
        if !item.isEmpty {
            items.append(item)
        }
        return items
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func stripYAMLComment(_ line: String) -> String {
        var inSingle = false
        var inDouble = false
        var escaped = false
        var out = ""
        for ch in line {
            if escaped {
                out.append(ch)
                escaped = false
                continue
            }
            if inDouble && ch == "\\" {
                out.append(ch)
                escaped = true
                continue
            }
            if ch == "\"", !inSingle {
                inDouble.toggle()
                out.append(ch)
                continue
            }
            if ch == "'", !inDouble {
                inSingle.toggle()
                out.append(ch)
                continue
            }
            if ch == "#", !inSingle, !inDouble {
                break
            }
            out.append(ch)
        }
        return out
    }
}

private extension Dictionary where Key == String, Value == String {
    func firstValue(for keys: [String]) -> String? {
        for key in keys {
            if let value = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                if value.count >= 2,
                   (value.hasPrefix("\"") && value.hasSuffix("\""))
                    || (value.hasPrefix("'") && value.hasSuffix("'")) {
                    return String(value.dropFirst().dropLast())
                }
                return value
            }
        }
        return nil
    }

    func boolValue(for keys: [String]) -> Bool? {
        guard let value = firstValue(for: keys) else { return nil }
        switch value.lowercased() {
        case "true", "yes", "on":
            return true
        case "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}
