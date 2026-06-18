import IHatePDFsCore
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { proxy in
            content
                .onAppear {
                    appState.updateWindowWidth(proxy.size.width)
                }
                .onChange(of: proxy.size.width) { width in
                    appState.updateWindowWidth(width)
                }
        }
        .navigationTitle(appState.displayTitle)
        .frame(minWidth: 820, minHeight: 620)
        .toolbar {
            ReaderToolbar()
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if appState.document == nil {
                EmptyDocumentView()
            } else {
                HSplitView {
                    if appState.showLeftSidebar {
                        LeftSidebarView()
                            .frame(minWidth: 170, idealWidth: 210, maxWidth: 280)
                    }

                    PDFReaderView()
                        .frame(minWidth: 420)

                    if appState.showCommentsSidebar {
                        CommentsReviewSidebar()
                            .frame(minWidth: 260, idealWidth: 310, maxWidth: 400)
                    }
                }
            }

            StatusBarView()
        }
    }
}

private struct PDFReaderView: View {
    var body: some View {
        PDFKitRepresentedView()
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct EmptyDocumentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Open a PDF")
                .font(.title2)

            Text("Use standard PDF annotations for selected-text comments, highlights, underlines, and free text.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button {
                appState.openDocument()
            } label: {
                Label("Open PDF", systemImage: "folder")
            }
            .keyboardShortcut("o")
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct StatusBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            Text(appState.statusMessage)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if appState.document != nil {
                Text("\(appState.annotations.count) annotations")
                Text("Page \(appState.currentPageIndex + 1) of \(max(appState.pageCount, 1))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.bar)
    }
}

private struct ReaderToolbar: ToolbarContent {
    @EnvironmentObject private var appState: AppState
    @FocusState private var searchFocused: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                appState.openDocument()
            } label: {
                Label("Open", systemImage: "folder")
            }
            .help("Open PDF")

            Button {
                appState.showLeftSidebar.toggle()
            } label: {
                Label("Pages", systemImage: "sidebar.left")
            }
            .disabled(appState.document == nil)
            .help("Toggle Page Sidebar")

            Button {
                appState.showCommentsSidebar.toggle()
            } label: {
                Label("Comments Sidebar", systemImage: "sidebar.right")
            }
            .disabled(appState.document == nil)
            .help(appState.showCommentsSidebar ? "Hide Comments Sidebar" : "Show Comments Sidebar")
            .accessibilityLabel("Toggle Comments Sidebar")
        }

        ToolbarItemGroup(placement: .principal) {
            Button {
                appState.goToPreviousPage()
            } label: {
                Label("Previous Page", systemImage: "chevron.up")
            }
            .disabled(appState.document == nil)
            .help("Previous Page")

            TextField("Page", text: $appState.pageText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 52)
                .onSubmit {
                    appState.goToPageFromField()
                }
                .disabled(appState.document == nil)

            Text("/ \(max(appState.pageCount, 1))")
                .foregroundStyle(.secondary)

            Button {
                appState.goToNextPage()
            } label: {
                Label("Next Page", systemImage: "chevron.down")
            }
            .disabled(appState.document == nil)
            .help("Next Page")
        }

        ToolbarItemGroup {
            if appState.showToolbarSearch {
                TextField("Search", text: $appState.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .focused($searchFocused)
                    .onSubmit {
                        appState.runSearch()
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            searchFocused = true
                        }
                    }
                    .disabled(appState.document == nil)

                Button {
                    appState.previousSearchResult()
                } label: {
                    Label("Previous Match", systemImage: "chevron.left")
                }
                .disabled(appState.searchResults.isEmpty)
                .help("Previous Search Match")

                Button {
                    appState.nextSearchResult()
                } label: {
                    Label("Next Match", systemImage: "chevron.right")
                }
                .disabled(appState.searchResults.isEmpty)
                .help("Next Search Match")

                Button {
                    appState.hideSearch()
                } label: {
                    Label("Close Search", systemImage: "xmark")
                }
                .disabled(appState.document == nil)
                .help("Close Search")
            } else {
                Button {
                    appState.showSearch()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(appState.document == nil)
                .help("Search")
            }
        }

        ToolbarItemGroup {
            Button {
                appState.addHighlight()
            } label: {
                Label("Highlight", systemImage: "highlighter")
            }
            .disabled(appState.document == nil)
            .help("Highlight Selection")

            Button {
                appState.addUnderline()
            } label: {
                Label("Underline", systemImage: "underline")
            }
            .disabled(appState.document == nil)
            .help("Underline Selection")

            Button {
                appState.addComment()
            } label: {
                Label("Comment", systemImage: "text.bubble")
            }
            .accessibilityLabel("Comment on Selection")
            .help("Comment on Selection")
            .disabled(appState.document == nil)
        }

        ToolbarItemGroup {
            Button {
                appState.zoomOut()
            } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .disabled(appState.document == nil)
            .help("Zoom Out")

            Button {
                appState.zoomIn()
            } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .disabled(appState.document == nil)
            .help("Zoom In")

            Button {
                appState.fitWidth()
            } label: {
                Label("Fit Width", systemImage: "arrow.left.and.right")
            }
            .disabled(appState.document == nil)
            .help("Fit to Width")

            Button {
                appState.fitPage()
            } label: {
                Label("Fit Page", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .disabled(appState.document == nil)
            .help("Fit Page")
        }

        ToolbarItemGroup {
            Button {
                appState.saveDocument()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(appState.document == nil)
            .help("Save PDF")

            Button {
                appState.shareDocument()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(appState.document == nil)
            .help("Share PDF")
        }
    }
}
