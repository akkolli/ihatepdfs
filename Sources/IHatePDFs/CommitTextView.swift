import AppKit
import IHatePDFsCore
import SwiftUI

struct CommitTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var focusOnAppear = true
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = CommitTextNSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.onCommit = onCommit

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CommitTextNSTextView else { return }

        textView.onCommit = onCommit
        textView.font = font
        if textView.string != text {
            textView.string = text
        }

        guard focusOnAppear,
              !context.coordinator.didFocus,
              textView.window != nil
        else {
            return
        }

        context.coordinator.didFocus = true
        DispatchQueue.main.async { [weak textView] in
            guard let textView else { return }
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        var didFocus = false

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private final class CommitTextNSTextView: NSTextView {
    var onCommit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        guard !hasMarkedText() else {
            super.keyDown(with: event)
            return
        }

        if ReturnKeyCommitPolicy.shouldCommit(
            keyCode: UInt16(event.keyCode),
            shift: event.modifierFlags.contains(.shift),
            option: event.modifierFlags.contains(.option),
            command: event.modifierFlags.contains(.command),
            control: event.modifierFlags.contains(.control),
            isEditableMultilineText: isEditable && !isFieldEditor
        ) {
            onCommit?()
            return
        }

        super.keyDown(with: event)
    }
}
