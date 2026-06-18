import AppKit
import SwiftUI

@main
struct IHatePDFsApp: App {
    var body: some Scene {
        WindowGroup {
            AppWindowRoot()
        }
        .windowStyle(.titleBar)
        .commands {
            AppCommands()
        }
    }
}

private struct AppWindowRoot: View {
    @StateObject private var appState = AppState()

    var body: some View {
        MainView()
            .environmentObject(appState)
            .focusedObject(appState)
            .onOpenURL { url in
                appState.loadDocument(from: url)
            }
    }
}

private struct AppCommands: Commands {
    @FocusedObject private var appState: AppState?

    private var hasDocument: Bool {
        appState?.document != nil
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
            .disabled(!hasDocument)

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
            .disabled(!hasDocument)

            Button("Underline Selection") {
                appState?.addUnderline()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            .disabled(!hasDocument)

            Button("Comment on Selection") {
                appState?.addComment()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(!hasDocument)

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
}
