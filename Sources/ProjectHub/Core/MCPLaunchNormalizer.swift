import Foundation

struct MCPLaunchMetadata {
    let command: String?
    let args: [String]
    let env: [String: String]
    let envFile: String?
}

enum MCPLaunchNormalizer {
    static func metadata(command: Any?, args explicitArgs: [String]) -> MCPLaunchMetadata {
        let tokens = launchTokens(command: command, explicitArgs: explicitArgs)
        guard let normalized = normalizeLaunchTokens(tokens) else {
            return MCPLaunchMetadata(
                command: tokens.first,
                args: tokens.isEmpty ? explicitArgs : Array(tokens.dropFirst()),
                env: [:],
                envFile: nil
            )
        }
        return MCPLaunchMetadata(
            command: normalized.command,
            args: normalized.args,
            env: normalized.env,
            envFile: normalized.envFile
        )
    }

    static func launch(command: Any?, args explicitArgs: [String]) -> (command: String?, args: [String]) {
        let meta = metadata(command: command, args: explicitArgs)
        return (meta.command, meta.args)
    }

    private static func launchTokens(command: Any?, explicitArgs: [String]) -> [String] {
        if let parts = command as? [String], !parts.isEmpty {
            return explicitArgs.isEmpty ? parts : [parts[0]] + explicitArgs
        }
        if let parts = command as? [Any] {
            let strings = parts.compactMap { $0 as? String }
            if !strings.isEmpty {
                return explicitArgs.isEmpty ? strings : [strings[0]] + explicitArgs
            }
        }
        guard let rawCommand = command as? String else {
            return explicitArgs
        }
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return explicitArgs }
        if explicitArgs.isEmpty {
            let tokens = shellSplit(trimmed)
            if tokens.count > 1, isLaunchCandidate(tokens) {
                return tokens
            }
        }
        return [trimmed] + explicitArgs
    }

    private static func isLaunchCandidate(_ tokens: [String]) -> Bool {
        guard let first = tokens.first else { return false }
        if isEnvCommand(first) || envAssignment(first) != nil {
            return true
        }
        return commandStarters.contains(URL(fileURLWithPath: first).lastPathComponent.lowercased())
    }

    private static func normalizeLaunchTokens(_ rawTokens: [String]) -> (env: [String: String], envFile: String?, command: String, args: [String])? {
        let tokens = expandEnvSplitString(rawTokens)
        guard !tokens.isEmpty else { return nil }
        var index = 0
        var env: [String: String] = [:]
        var envFile: String?

        if isEnvCommand(tokens[index]) {
            index += 1
            while index < tokens.count {
                let token = tokens[index]
                if token == "-i" || token == "--ignore-environment" {
                    index += 1
                    continue
                }
                if token == "-u" || token == "--unset" {
                    index += 2
                    continue
                }
                if token.hasPrefix("-u"), token.count > 2 {
                    index += 1
                    continue
                }
                if token.hasPrefix("-") { return nil }
                if let assignment = envAssignment(token) {
                    env[assignment.key] = assignment.value
                    index += 1
                    continue
                }
                if isEnvName(token),
                   index + 1 < tokens.count,
                   commandStarters.contains(URL(fileURLWithPath: tokens[index + 1]).lastPathComponent.lowercased()) {
                    env[token] = "${\(token)}"
                    index += 1
                    continue
                }
                break
            }
        } else {
            while index < tokens.count, let assignment = envAssignment(tokens[index]) {
                env[assignment.key] = assignment.value
                index += 1
            }
        }

        guard index < tokens.count else { return nil }
        let command = tokens[index]
        let args = Array(tokens.dropFirst(index + 1))
        if URL(fileURLWithPath: command).lastPathComponent.lowercased() == "docker" {
            env.merge(dockerEnvFlags(in: args)) { current, _ in current }
            envFile = dockerEnvFiles(in: args).first
        }
        return (env, envFile, command, args)
    }

    private static func expandEnvSplitString(_ tokens: [String]) -> [String] {
        guard tokens.count >= 3, isEnvCommand(tokens[0]) else { return tokens }
        var out: [String] = [tokens[0]]
        var index = 1
        while index < tokens.count {
            let token = tokens[index]
            if (token == "-S" || token == "--split-string"), index + 1 < tokens.count {
                out.append(contentsOf: shellSplit(tokens[index + 1]))
                index += 2
                continue
            }
            if token.hasPrefix("--split-string=") {
                out.append(contentsOf: shellSplit(String(token.dropFirst("--split-string=".count))))
                index += 1
                continue
            }
            out.append(token)
            index += 1
        }
        return out
    }

    private static func isEnvCommand(_ token: String) -> Bool {
        URL(fileURLWithPath: token).lastPathComponent.lowercased() == "env"
    }

    private static func envAssignment(_ token: String) -> (key: String, value: String)? {
        guard let eq = token.firstIndex(of: "="), eq > token.startIndex else { return nil }
        let key = String(token[..<eq])
        guard isEnvName(key) else { return nil }
        return (key, String(token[token.index(after: eq)...]))
    }

    private static func isEnvName(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first,
              first == "_" || CharacterSet.uppercaseLetters.contains(first) || CharacterSet.lowercaseLetters.contains(first) else {
            return false
        }
        return value.unicodeScalars.allSatisfy {
            $0 == "_" || CharacterSet.alphanumerics.contains($0)
        }
    }

    private static func dockerEnvFlags(in args: [String]) -> [String: String] {
        var env: [String: String] = [:]
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "-e" || token == "--env" {
                index += 1
                if index < args.count {
                    recordDockerEnv(args[index], into: &env)
                }
            } else if token.hasPrefix("--env=") {
                recordDockerEnv(String(token.dropFirst("--env=".count)), into: &env)
            } else if token.hasPrefix("-e"), token.count > 2 {
                recordDockerEnv(String(token.dropFirst(2)), into: &env)
            }
            index += 1
        }
        return env
    }

    private static func dockerEnvFiles(in args: [String]) -> [String] {
        var files: [String] = []
        var index = 0
        while index < args.count {
            let token = args[index]
            if token == "--env-file" {
                index += 1
                if index < args.count {
                    files.append(args[index])
                }
            } else if token.hasPrefix("--env-file=") {
                files.append(String(token.dropFirst("--env-file=".count)))
            }
            index += 1
        }
        return files.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func recordDockerEnv(_ raw: String, into env: inout [String: String]) {
        if let assignment = envAssignment(raw) {
            env[assignment.key] = assignment.value
        } else if isEnvName(raw) {
            env[raw] = "${\(raw)}"
        }
    }

    private static let commandStarters: Set<String> = [
        "env", "npx", "npm", "pnpm", "yarn", "bunx", "bun",
        "uvx", "uv", "python", "python3", "pipx",
        "docker", "node", "deno", "brew", "cargo", "go"
    ]

    private static func shellSplit(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escapeNext = false

        for ch in input {
            if escapeNext {
                current.append(ch)
                escapeNext = false
                continue
            }
            if ch == "\\" && !inSingle {
                escapeNext = true
                continue
            }
            if ch == "'" && !inDouble {
                inSingle.toggle()
                continue
            }
            if ch == "\"" && !inSingle {
                inDouble.toggle()
                continue
            }
            if ch.isWhitespace && !inSingle && !inDouble {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}
