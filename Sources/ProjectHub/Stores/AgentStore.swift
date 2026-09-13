import Foundation

@MainActor
final class AgentStore: ObservableObject {
    @Published var lastError: String?
    @Published private(set) var agentsByPath: [String: [Agent]] = [:]

    func agents(for projectPath: String) -> [Agent] {
        agentsByPath[projectPath] ?? []
    }

    func load(for projectPath: String) async {
        guard agentsByPath[projectPath] == nil else { return }
        let list = await Task.detached(priority: .utility) {
            AgentReader.agents(for: projectPath)
        }.value
        agentsByPath[projectPath] = list
    }

    func invalidate(projectPath: String) {
        agentsByPath.removeValue(forKey: projectPath)
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
