import AppKit
import SwiftUI

@main
struct IHatePDFsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .onOpenURL { url in
                    appState.loadDocument(from: url)
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    appState.openDocument()
                }
                .keyboardShortcut("o")

                Button("Save") {
                    appState.saveDocument()
                }
                .keyboardShortcut("s")
                .disabled(appState.document == nil)

                Button("Save As...") {
                    appState.saveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.document == nil)

                Button("Share...") {
                    appState.shareDocument()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState.document == nil)

                Divider()

                Button("Close PDF") {
                    appState.closeDocument()
                }
                .keyboardShortcut("w")
                .disabled(appState.document == nil)
            }

            CommandGroup(after: .textEditing) {
                Button("Find in PDF") {
                    appState.showSearch()
                }
                .keyboardShortcut("f")
                .disabled(appState.document == nil)

                Button("Find Next") {
                    appState.nextSearchResult()
                }
                .keyboardShortcut("g")
                .disabled(appState.searchResults.isEmpty)

                Button("Find Previous") {
                    appState.previousSearchResult()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(appState.searchResults.isEmpty)
            }

            CommandMenu("View") {
                Button("Toggle Page Sidebar") {
                    appState.showLeftSidebar.toggle()
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
                .disabled(appState.document == nil)

                Button("Toggle Comments Sidebar") {
                    appState.showCommentsSidebar.toggle()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(appState.document == nil)

                Divider()

                Button("Zoom In") {
                    appState.zoomIn()
                }
                .keyboardShortcut("+")
                .disabled(appState.document == nil)

                Button("Zoom Out") {
                    appState.zoomOut()
                }
                .keyboardShortcut("-")
                .disabled(appState.document == nil)

                Button("Fit to Width") {
                    appState.fitWidth()
                }
                .keyboardShortcut("9", modifiers: [.command])
                .disabled(appState.document == nil)

                Button("Fit to Page") {
                    appState.fitPage()
                }
                .keyboardShortcut("8", modifiers: [.command])
                .disabled(appState.document == nil)

                Button("Two Pages Continuous") {
                    appState.twoPageContinuous()
                }
                .keyboardShortcut("7", modifiers: [.command])
                .disabled(appState.document == nil)
            }

            CommandMenu("Annotate") {
                Button("Highlight Selection") {
                    appState.addHighlight()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(appState.document == nil)

                Button("Underline Selection") {
                    appState.addUnderline()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(appState.document == nil)

                Button("Comment on Selection") {
                    appState.addComment()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(appState.document == nil)

                Button("Add Free Text") {
                    appState.addFreeText()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(appState.document == nil)
            }

            CommandGroup(after: .windowArrangement) {
                Button("Minimize") {
                    appState.minimizeWindow()
                }
                .keyboardShortcut("m", modifiers: [.command])

                Button("Toggle Full Screen") {
                    appState.toggleFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
        }
    }
}
