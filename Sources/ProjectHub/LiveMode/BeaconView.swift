import SwiftUI
import AppKit

// MARK: - The floating dot button view

struct BeaconView: View {
    @ObservedObject var watcher: ProjectWatcher
    let usedFraction: Double   // 0...1, drives the ring colour
    let sidebarOpen: Bool

    var body: some View {
        ZStack {
            // Dark glass circle
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(Color.black.opacity(0.55))
                )
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)

            // Usage ring — always drawn, fades in as usage rises
            Circle()
                .trim(from: 0, to: usedFraction)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: usedFraction)
                .padding(3)

            // Stack icon
            Image(systemName: sidebarOpen
                  ? "square.stack.3d.up.fill"
                  : "square.stack.3d.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(watcher.claudeIsFront
                                 ? Color.cyan
                                 : Color.white.opacity(0.7))
                .animation(.easeInOut(duration: 0.2), value: watcher.claudeIsFront)

            // "Claude active" glow pulse
            if watcher.claudeIsFront {
                Circle()
                    .stroke(Color.cyan.opacity(0.25), lineWidth: 2)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: pulseScale
                    )
            }
        }
        .frame(width: 48, height: 48)
        .onAppear { startPulse() }
    }

    // MARK: - Pulse animation

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    private func startPulse() {
        pulseScale   = 1.35
        pulseOpacity = 0.0
    }

    // MARK: - Ring gradient

    private var ringGradient: AngularGradient {
        let colour = colorFor(usedFraction)
        return AngularGradient(
            gradient: Gradient(colors: [colour.opacity(0.6), colour]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * usedFraction)
        )
    }

    private func colorFor(_ f: Double) -> Color {
        switch f {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        case ..<0.9:  return .orange
        default:      return .red
        }
    }
}

// MARK: - Drag + click NSView wrapper

/// Transparent NSView that moves its parent NSWindow on drag,
/// and fires `onTap` on a clean click (no drag). Right-click → context menu.
final class DragClickView: NSView {
    var onTap:        (() -> Void)?
    var onDragEnded:  ((NSPoint) -> Void)?

    private var dragStart: NSPoint?
    private var didDrag    = false
    private let dragThreshold: CGFloat = 4

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        didDrag   = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let loc = NSEvent.mouseLocation
        let dx = loc.x - start.x
        let dy = loc.y - start.y
        if abs(dx) > dragThreshold || abs(dy) > dragThreshold { didDrag = true }
        window?.setFrameOrigin(NSPoint(
            x: (window?.frame.origin.x ?? 0) + event.deltaX,
            y: (window?.frame.origin.y ?? 0) - event.deltaY
        ))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            if let origin = window?.frame.origin { onDragEnded?(origin) }
        } else {
            onTap?()
        }
        dragStart = nil
        didDrag   = false
    }

    override func rightMouseUp(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Close Live Mode",
                     action:    #selector(closeLiveMode),
                     keyEquivalent: "")
        menu.items.first?.target = self
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func closeLiveMode() {
        NotificationCenter.default.post(name: .projecthubLiveModeClose, object: nil)
    }

    // Accept first mouse so clicks land without activating the app
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - NSViewRepresentable

struct DragClickViewRepresentable: NSViewRepresentable {
    var onTap: () -> Void
    var onDragEnded: (NSPoint) -> Void

    func makeNSView(context: Context) -> DragClickView {
        let v = DragClickView()
        v.onTap       = onTap
        v.onDragEnded = onDragEnded
        return v
    }

    func updateNSView(_ nsView: DragClickView, context: Context) {
        nsView.onTap       = onTap
        nsView.onDragEnded = onDragEnded
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let projecthubLiveModeClose = Notification.Name("com.projecthub.liveMode.close")
}
