import Foundation

struct ImportCredentialPromptItem: Identifiable, Equatable {
    let id: String
    let inputName: String
    let detail: String
    let required: Bool
    let secret: Bool
}

enum ImportCredentialPlanner {
    static func requirements(for server: ParsedServer) -> [ImportCredentialRequirement] {
        var requirements = server.credentialRequirements

        if let env = server.config["env"] as? [String: Any] {
            for key in env.keys.sorted() {
                if let value = env[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.isEmpty || !placeholderEnvNames(in: value).isEmpty else { continue }
                }
                requirements.append(.init(
                    kind: .env,
                    name: key,
                    envName: key,
                    placeholder: nil,
                    required: false,
                    secret: true,
                    description: nil,
                    source: "env"
                ))
            }
        }

        if let headers = server.config["headers"] as? [String: String] {
            for header in headers.keys.sorted() {
                let value = headers[header] ?? ""
                guard let envName = placeholderEnvName(in: value) else { continue }
                requirements.append(.init(
                    kind: .header,
                    name: header,
                    envName: envName,
                    placeholder: value,
                    required: false,
                    secret: true,
                    description: nil,
                    source: "header placeholder"
                ))
            }
        }

        if let url = server.config["url"] as? String {
            for envName in placeholderEnvNames(in: url) {
                requirements.append(.init(
                    kind: .urlVariable,
                    name: envName,
                    envName: envName,
                    placeholder: "${\(envName)}",
                    required: false,
                    secret: false,
                    description: nil,
                    source: "URL placeholder"
                ))
            }
        }

        return dedupe(requirements)
    }

    static func promptItems(for server: ParsedServer) -> [ImportCredentialPromptItem] {
        promptItems(for: requirements(for: server))
    }

    static func promptItems(for requirements: [ImportCredentialRequirement]) -> [ImportCredentialPromptItem] {
        requirements.map { requirement in
            let inputName = requirement.envName
                ?? placeholderEnvName(in: requirement.placeholder ?? "")
                ?? requirement.name
            return .init(
                id: "\(requirement.kind.rawValue)|\(inputName)|\(requirement.name)",
                inputName: inputName,
                detail: promptDetail(for: requirement),
                required: requirement.required,
                secret: requirement.secret
            )
        }
    }

    static func promptSummary(for server: ParsedServer) -> String {
        let items = promptItems(for: server)
        guard !items.isEmpty else { return "Add credential values if this server needs them." }
        return "Fill these placeholders: \(items.map { "\($0.inputName) (\($0.detail.lowercased()))" }.joined(separator: ", "))."
    }

    static func requirementSummary(for server: ParsedServer) -> String? {
        requirementSummary(for: requirements(for: server))
    }

    static func requirementSummary(for requirements: [ImportCredentialRequirement]) -> String? {
        let envNames = names(for: requirements, kind: .env, useRequirementName: false)
        let headerNames = names(for: requirements, kind: .header, useRequirementName: true)
        let urlNames = names(for: requirements, kind: .urlVariable, useRequirementName: false)
        var parts: [String] = []
        if !envNames.isEmpty {
            parts.append("env \(envNames.joined(separator: ", "))")
        }
        if !headerNames.isEmpty {
            parts.append("headers \(headerNames.joined(separator: ", "))")
        }
        if !urlNames.isEmpty {
            parts.append("URL values \(urlNames.joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    static func envHintNames(for server: ParsedServer) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for requirement in requirements(for: server) {
            let name = requirement.envName ?? placeholderEnvName(in: requirement.placeholder ?? "") ?? requirement.name
            guard seen.insert(name).inserted else { continue }
            names.append(name)
        }
        return names
    }

    private static func promptDetail(for requirement: ImportCredentialRequirement) -> String {
        let base: String
        switch requirement.kind {
        case .env:
            base = "Env \(requirement.name)"
        case .header:
            base = "Header \(requirement.name)"
        case .urlVariable:
            base = "URL \(requirement.name)"
        }
        return requirement.required ? "\(base) · Required" : base
    }

    private static func dedupe(_ requirements: [ImportCredentialRequirement]) -> [ImportCredentialRequirement] {
        var seen = Set<String>()
        var output: [ImportCredentialRequirement] = []
        for requirement in requirements {
            let key = [
                requirement.kind.rawValue,
                requirement.envName ?? "",
                requirement.name
            ].joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            output.append(requirement)
        }
        return output
    }

    private static func names(
        for requirements: [ImportCredentialRequirement],
        kind: ImportCredentialRequirement.Kind,
        useRequirementName: Bool
    ) -> [String] {
        var seen = Set<String>()
        return requirements
            .filter { $0.kind == kind }
            .compactMap { requirement in
                let name = useRequirementName
                    ? requirement.name
                    : (requirement.envName
                        ?? placeholderEnvName(in: requirement.placeholder ?? "")
                        ?? requirement.name)
                guard !name.isEmpty, seen.insert(name).inserted else { return nil }
                return name
            }
            .sorted()
    }

    private static func placeholderEnvNames(in value: String) -> [String] {
        var names: [String] = []
        var seen = Set<String>()
        let pattern = #"\$\{([A-Za-z_][A-Za-z0-9_]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsValue = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length))
        for match in matches {
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: value) else { continue }
            let name = String(value[range])
            if seen.insert(name).inserted {
                names.append(name)
            }
        }
        return names
    }

    private static func placeholderEnvName(in value: String) -> String? {
        let names = placeholderEnvNames(in: value)
        return names.count == 1 ? names[0] : nil
    }
}
