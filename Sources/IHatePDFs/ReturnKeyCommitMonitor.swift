import AppKit
import SwiftUI

extension View {
    func commitOnPlainReturn(_ action: @escaping () -> Void) -> some View {
        modifier(ReturnKeyCommitMonitor(action: action))
    }
}

private struct ReturnKeyCommitMonitor: ViewModifier {
    let action: () -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                installMonitor()
            }
            .onDisappear {
                removeMonitor()
            }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isPlainReturn(event) else { return event }
            action()
            return nil
        }
    }

    private func removeMonitor() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private func isPlainReturn(_ event: NSEvent) -> Bool {
        guard event.keyCode == 36 || event.keyCode == 76 else { return false }

        let multilineModifiers: NSEvent.ModifierFlags = [.shift, .option, .command, .control]
        return event.modifierFlags.intersection(multilineModifiers).isEmpty
    }
}
