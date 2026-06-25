import AppKit
import IHatePDFsCore
import SwiftUI

extension View {
    func commitOnPlainReturn(isEnabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        modifier(ReturnKeyCommitMonitor(isEnabled: isEnabled, action: action))
    }
}

private struct ReturnKeyCommitMonitor: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void
    @State private var monitor: Any?
    @State private var eventWindowBox = EventWindowBox()

    func body(content: Content) -> some View {
        content
            .background(
                EventWindowReader { window in
                    eventWindowBox.windowID = window.map(ObjectIdentifier.init)
                }
            )
            .onAppear {
                eventWindowBox.isEnabled = isEnabled
                installMonitor()
            }
            .onChange(of: isEnabled) { value in
                eventWindowBox.isEnabled = value
            }
            .onDisappear {
                removeMonitor()
            }
    }

    private func installMonitor() {
        removeMonitor()
        let eventWindowBox = eventWindowBox
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard eventWindowBox.isEnabled,
                  shouldCommit(event),
                  eventWindowBox.windowID.map({ event.window.map(ObjectIdentifier.init) == $0 }) == true
            else {
                return event
            }

            action()
            return nil
        }
    }

    private func removeMonitor() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private func shouldCommit(_ event: NSEvent) -> Bool {
        let textView = event.window?.firstResponder as? NSTextView
        let isEditableMultilineText = textView?.isEditable == true && textView?.isFieldEditor == false
        return ReturnKeyCommitPolicy.shouldCommit(
            keyCode: UInt16(event.keyCode),
            shift: event.modifierFlags.contains(.shift),
            option: event.modifierFlags.contains(.option),
            command: event.modifierFlags.contains(.command),
            control: event.modifierFlags.contains(.control),
            isEditableMultilineText: isEditableMultilineText
        )
    }
}

private final class EventWindowBox {
    var windowID: ObjectIdentifier?
    var isEnabled = true
}

private struct EventWindowReader: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowReportingView {
        let view = WindowReportingView()
        view.onWindowChange = onWindowChange
        return view
    }

    func updateNSView(_ view: WindowReportingView, context: Context) {
        view.onWindowChange = onWindowChange
        view.reportWindow()
    }
}

private final class WindowReportingView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportWindow()
    }

    func reportWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            onWindowChange?(window)
        }
    }
}
