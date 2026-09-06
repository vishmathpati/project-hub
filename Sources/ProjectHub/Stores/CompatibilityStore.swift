import Foundation

@MainActor
final class CompatibilityStore: ObservableObject {
    @Published private(set) var result: CompatibilityScanResult?
    @Published private(set) var isScanning = false

    func restore(projectRoot: String?) {
        guard result == nil, !isScanning else { return }
        Task.detached(priority: .utility) {
            let loaded = ConfigScanCache.load(projectRoot: projectRoot, kind: .full)
            await MainActor.run {
                if self.result == nil {
                    self.result = loaded
                }
            }
        }
    }

    func replace(_ result: CompatibilityScanResult?) {
        self.result = result
    }

    func scan(projectRoot: String?, codexProfileSelection: CodexProfileSelection? = nil) {
        guard !isScanning else { return }
        isScanning = true
        Task.detached(priority: .utility) {
            let result = CompatibilityScanner.scan(
                projectRoot: projectRoot,
                codexProfileSelection: codexProfileSelection,
                kind: .full
            )
            ConfigScanCache.save(result, kind: .full)
            await MainActor.run {
                self.result = result
                self.isScanning = false
            }
        }
    }
}
