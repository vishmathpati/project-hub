import Foundation

@MainActor
final class AgentStore: ObservableObject {
    @Published var lastError: String?
    private var agentsByPath: [String: [Agent]] = [:]

    func agents(for projectPath: String) -> [Agent] {
        if let cached = agentsByPath[projectPath] { return cached }
        let list = AgentReader.agents(for: projectPath)
        agentsByPath[projectPath] = list
        return list
    }

    func invalidate(projectPath: String) {
        agentsByPath[projectPath] = AgentReader.agents(for: projectPath)
        objectWillChange.send()
    }

    func create(agent: AgentTemplate, in projectPath: String) {
        do {
            try AgentReader.create(agent: agent, in: projectPath)
            invalidate(projectPath: projectPath)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(agentName: String, from projectPath: String) {
        do {
            try AgentReader.delete(agentName: agentName, from: projectPath)
            invalidate(projectPath: projectPath)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
