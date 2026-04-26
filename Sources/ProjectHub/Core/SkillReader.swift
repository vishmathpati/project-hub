import Foundation

// MARK: - Skill parsing helpers

enum SkillReader {

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
}
