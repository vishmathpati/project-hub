import Foundation

// MARK: - Agent store

@MainActor
final class AgentStore: ObservableObject {

    func agents(for projectPath: String) -> [Agent] {
        AgentReader.agents(for: projectPath)
    }

    func create(agent: AgentTemplate, in projectPath: String) {
        do {
            try AgentReader.create(agent: agent, in: projectPath)
        } catch {
            // Best-effort; callers can observe by re-fetching agents()
        }
    }

    func delete(agentName: String, from projectPath: String) {
        do {
            try AgentReader.delete(agentName: agentName, from: projectPath)
        } catch {
            // Best-effort
        }
    }
}
