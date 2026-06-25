import AppKit
import SwiftUI

@main
struct IHatePDFsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppWindowRoot()
        }
        .windowStyle(.titleBar)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppStateRegistry.shared.confirmApplicationShouldTerminate()
            ? .terminateNow
            : .terminateCancel
    }
}

@MainActor
private final class AppStateRegistry {
    static let shared = AppStateRegistry()

    private var appStates: [WeakAppState] = []
    private(set) var isTerminationApproved = false

    func register(_ appState: AppState) {
        prune()

        guard !appStates.contains(where: { $0.value === appState }) else {
            return
        }

        appStates.append(WeakAppState(appState))
    }

    func unregister(_ appState: AppState) {
        appStates.removeAll { $0.value == nil || $0.value === appState }
    }

    func confirmApplicationShouldTerminate() -> Bool {
        prune()

        for appState in appStates.compactMap(\.value) {
            guard appState.confirmApplicationQuit() else {
                cancelTerminationApproval()
                return false
            }
        }

        isTerminationApproved = true
        return true
    }

    func cancelTerminationApproval() {
        isTerminationApproved = false
    }

    private func prune() {
        appStates.removeAll { $0.value == nil }
    }
}

private final class WeakAppState {
    weak var value: AppState?

    init(_ value: AppState) {
        self.value = value
    }
}

private struct AppWindowRoot: View {
    @StateObject private var appState = AppState()

    var body: some View {
        MainView()
            .environmentObject(appState)
            .focusedObject(appState)
            .background(WindowCloseGuard(appState: appState))
            .onOpenURL { url in
                appState.loadDocument(from: url)
            }
            .onAppear {
                AppStateRegistry.shared.register(appState)
            }
            .onDisappear {
                AppStateRegistry.shared.unregister(appState)
            }
    }
}

private struct WindowCloseGuard: NSViewRepresentable {
    @ObservedObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeNSView(context: Context) -> WindowCloseGuardView {
        let view = WindowCloseGuardView()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ view: WindowCloseGuardView, context: Context) {
        context.coordinator.appState = appState
        context.coordinator.updateDocumentState()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        view.reportWindow()
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        weak var appState: AppState?
        private weak var window: NSWindow?
        private weak var previousDelegate: NSWindowDelegate?

        init(appState: AppState) {
            self.appState = appState
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else { return }

            if let oldWindow = self.window, oldWindow.delegate === self {
                oldWindow.delegate = previousDelegate
            }

            self.window = window
            previousDelegate = window?.delegate

            if window?.delegate !== self {
                window?.delegate = self
            }

            updateDocumentState()
        }

        func updateDocumentState() {
            guard let window else { return }

            let representedURL = appState?.documentURL
            if window.representedURL != representedURL {
                window.representedURL = representedURL
            }

            let isDocumentEdited = appState?.hasUnsavedWork == true
            if window.isDocumentEdited != isDocumentEdited {
                window.isDocumentEdited = isDocumentEdited
            }
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if previousDelegate?.windowShouldClose?(sender) == false {
                AppStateRegistry.shared.cancelTerminationApproval()
                return false
            }

            if AppStateRegistry.shared.isTerminationApproved {
                return true
            }

            return appState?.confirmDocumentWindowClose() ?? true
        }

        func windowWillClose(_ notification: Notification) {
            previousDelegate?.windowWillClose?(notification)

            if window?.delegate === self {
                window?.delegate = previousDelegate
            }
            window = nil
            previousDelegate = nil
        }

        deinit {
            MainActor.assumeIsolated {
                if window?.delegate === self {
                    window?.delegate = previousDelegate
                }
            }
        }
    }
}

private final class WindowCloseGuardView: NSView {
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

private struct AppCommands: Commands {
    @FocusedObject private var appState: AppState?

    private var hasDocument: Bool {
        appState?.document != nil
    }

    private var hasTextSelection: Bool {
        appState?.hasTextSelection == true
    }

    private var canSaveDocument: Bool {
        appState?.canSaveDocument == true
    }

    private var saveHelpText: String {
        appState?.saveHelpText ?? "Open a PDF before saving."
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open...") {
                appState?.openDocument()
            }
            .keyboardShortcut("o")
            .disabled(appState == nil)

            Button("Save") {
                appState?.saveDocument()
            }
            .keyboardShortcut("s")
            .disabled(!canSaveDocument)
            .help(saveHelpText)

            Button("Save As...") {
                appState?.saveDocumentAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!hasDocument)

            Button("Share...") {
                appState?.shareDocument()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!hasDocument)

            Divider()

            Button("Settings...") {
                openSettingsWindow()
            }

            Divider()

            Button("Close PDF") {
                appState?.closeDocument()
            }
            .keyboardShortcut("w")
            .disabled(!hasDocument)
        }

        CommandGroup(after: .textEditing) {
            Button("Find in PDF") {
                appState?.showSearch()
            }
            .keyboardShortcut("f")
            .disabled(!hasDocument)

            Button("Find Next") {
                appState?.nextSearchResult()
            }
            .keyboardShortcut("g")
            .disabled(appState?.searchResults.isEmpty != false)

            Button("Find Previous") {
                appState?.previousSearchResult()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(appState?.searchResults.isEmpty != false)
        }

        CommandMenu("View") {
            Button("Toggle Page Sidebar") {
                appState?.showLeftSidebar.toggle()
            }
            .keyboardShortcut("0", modifiers: [.command, .option])
            .disabled(!hasDocument)

            Button("Toggle Comments Sidebar") {
                appState?.showCommentsSidebar.toggle()
            }
            .keyboardShortcut("1", modifiers: [.command, .option])
            .disabled(!hasDocument)

            Divider()

            Button("Zoom In") {
                appState?.zoomIn()
            }
            .keyboardShortcut("+")
            .disabled(!hasDocument)

            Button("Zoom Out") {
                appState?.zoomOut()
            }
            .keyboardShortcut("-")
            .disabled(!hasDocument)

            Button("Fit to Width") {
                appState?.fitWidth()
            }
            .keyboardShortcut("9", modifiers: [.command])
            .disabled(!hasDocument)

            Button("Fit to Page") {
                appState?.fitPage()
            }
            .keyboardShortcut("8", modifiers: [.command])
            .disabled(!hasDocument)

            Button("Two Pages Continuous") {
                appState?.twoPageContinuous()
            }
            .keyboardShortcut("7", modifiers: [.command])
            .disabled(!hasDocument)
        }

        CommandMenu("Annotate") {
            Button("Highlight Selection") {
                appState?.addHighlight()
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(!hasDocument || !hasTextSelection)

            Button("Underline Selection") {
                appState?.addUnderline()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            .disabled(!hasDocument || !hasTextSelection)

            Button("Comment on Selection") {
                appState?.addComment()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(!hasDocument || !hasTextSelection)

            Button("Add Free Text") {
                appState?.addFreeText()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(!hasDocument)
        }

        CommandGroup(after: .windowArrangement) {
            Button("Minimize") {
                appState?.minimizeWindow()
            }
            .keyboardShortcut("m", modifiers: [.command])
            .disabled(appState == nil)

            Button("Toggle Full Screen") {
                appState?.toggleFullScreen()
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
            .disabled(appState == nil)
        }
    }

    private func openSettingsWindow() {
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
