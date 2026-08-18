import Foundation

@MainActor
final class CompatibilityStore: ObservableObject {
    @Published private(set) var result: CompatibilityScanResult?
    @Published private(set) var isScanning = false

    func restore(projectRoot: String?) {
        guard result == nil else { return }
        result = ConfigScanCache.load(projectRoot: projectRoot)
    }

    func scan(projectRoot: String?) {
        guard !isScanning else { return }
        isScanning = true
        Task.detached(priority: .utility) {
            let result = CompatibilityScanner.scan(projectRoot: projectRoot)
            ConfigScanCache.save(result)
            await MainActor.run {
                self.result = result
                self.isScanning = false
            }
        }
    }
}
