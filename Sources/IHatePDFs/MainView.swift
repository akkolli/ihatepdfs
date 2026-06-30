import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var leftSidebarWidth: CGFloat = ReaderAdaptiveLayout(sizeClass: .regular).leftSidebarIdealWidth
    @State private var rightSidebarWidth: CGFloat = ReaderAdaptiveLayout(sizeClass: .regular).rightSidebarIdealWidth
    @State private var leftSidebarDragStartWidth: CGFloat?
    @State private var rightSidebarDragStartWidth: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            content(availableWidth: proxy.size.width)
                .onAppear {
                    appState.updateWindowWidth(proxy.size.width)
                }
                .onChange(of: proxy.size.width) { width in
                    appState.updateWindowWidth(width)
                }
        }
        .navigationTitle(appState.displayTitle)
        .frame(
            minWidth: ReaderAdaptiveLayout.minimumWindowWidth,
            minHeight: ReaderAdaptiveLayout.minimumWindowHeight
        )
        .toolbar {
            ReaderToolbar()
        }
    }

    private func content(availableWidth: CGFloat) -> some View {
        let layout = ReaderAdaptiveLayout(width: availableWidth)
        let showsRightSidebar = appState.showCommentsSidebar
        let showsLeftSidebar = appState.showLeftSidebar && (layout.allowsDualSidebars || !showsRightSidebar)
        let sidebarWidths = layout.resolvedSidebarWidths(
            availableWidth: availableWidth,
            requestedLeft: leftSidebarWidth,
            requestedRight: rightSidebarWidth,
            showLeft: showsLeftSidebar,
            showRight: showsRightSidebar
        )

        return VStack(spacing: 0) {
            if appState.document == nil {
                EmptyDocumentView()
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        if showsLeftSidebar {
                            LeftSidebarView()
                                .frame(width: sidebarWidths.left)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .leading).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )

                            SidebarResizeHandle()
                                .gesture(leftSidebarResizeGesture(for: layout))
                        }

                        PDFReaderView()
                            .frame(minWidth: layout.documentMinWidth, maxWidth: .infinity)

                        if showsRightSidebar {
                            SidebarResizeHandle()
                                .gesture(rightSidebarResizeGesture(for: layout))

                            RightSidebarView()
                                .frame(width: sidebarWidths.right)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                        }
                    }
                    .animation(.easeInOut(duration: 0.18), value: appState.showLeftSidebar)
                    .animation(.easeInOut(duration: 0.18), value: appState.showCommentsSidebar)
                    .animation(.easeInOut(duration: 0.18), value: appState.readerSizeClass)
                }
            }

            StatusBarView()
        }
    }

    private func leftSidebarResizeGesture(for layout: ReaderAdaptiveLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if leftSidebarDragStartWidth == nil {
                    leftSidebarDragStartWidth = leftSidebarWidth
                }
                let proposedWidth = (leftSidebarDragStartWidth ?? leftSidebarWidth) + value.translation.width
                leftSidebarWidth = layout.clampedLeftWidth(proposedWidth)
            }
            .onEnded { _ in
                leftSidebarDragStartWidth = nil
            }
    }

    private func rightSidebarResizeGesture(for layout: ReaderAdaptiveLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if rightSidebarDragStartWidth == nil {
                    rightSidebarDragStartWidth = rightSidebarWidth
                }
                let proposedWidth = (rightSidebarDragStartWidth ?? rightSidebarWidth) - value.translation.width
                rightSidebarWidth = layout.clampedRightWidth(proposedWidth)
            }
            .onEnded { _ in
                rightSidebarDragStartWidth = nil
            }
    }
}

private struct SidebarResizeHandle: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: ReaderAdaptiveLayout.resizeHandleWidth)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .center) {
                Capsule()
                    .fill(InterfacePalette.hairline(for: colorScheme).opacity(isHovering ? 0.95 : 0.58))
                    .frame(width: isHovering ? 2 : 1, height: isHovering ? 42 : 30)
                .animation(.easeInOut(duration: 0.12), value: isHovering)
            }
            .background {
                Rectangle()
                    .fill(Color.accentColor.opacity(isHovering ? 0.05 : 0))
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pop()
                }
            }
            .help("Resize Sidebar")
    }
}

private struct PDFReaderView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDropTargeted = false

    var body: some View {
        ZStack(alignment: .bottom) {
            PDFKitRepresentedView()
                .background(Color(nsColor: .windowBackgroundColor))

            if appState.canShowSelectionActions {
                SelectionActionBar()
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if isDropTargeted {
                DropTargetOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $isDropTargeted
        ) { providers in
            appState.openDroppedDocument(from: providers)
        }
        .animation(.easeInOut(duration: 0.14), value: appState.canShowSelectionActions)
        .animation(.easeInOut(duration: 0.16), value: isDropTargeted)
    }
}

private struct SelectionActionBar: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppSettings.highlightColorStorageKey)
    private var storedHighlightColor = AppSettings.defaultHighlightColorStorageValue

    private var activeHighlightDisplayColor: Color {
        Color(nsColor: AppSettings.displayColor(forHighlightColor: AppSettings.highlightColor(from: storedHighlightColor)))
    }

    var body: some View {
        HStack(spacing: 2) {
            actionButton(
                "Highlight (H)",
                systemImage: "highlighter",
                foregroundStyle: activeHighlightDisplayColor
            ) {
                appState.addHighlight()
            }

            actionButton(
                "Underline (U)",
                systemImage: "underline",
                foregroundStyle: InterfacePalette.primaryText(for: colorScheme)
            ) {
                appState.addUnderline()
            }

            actionButton(
                "Comment (C)",
                systemImage: "text.bubble",
                foregroundStyle: InterfacePalette.primaryText(for: colorScheme)
            ) {
                appState.addComment()
            }
        }
        .controlSize(.small)
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 5)
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        foregroundStyle: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(foregroundStyle)
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct EmptyDocumentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 46, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(InterfacePalette.quietText(for: colorScheme))
                        .frame(width: 62, height: 62)

                    Text("Open a PDF")
                        .font(.title2.weight(.semibold))

                    Button {
                        appState.openDocument()
                    } label: {
                        Label("Open PDF", systemImage: "doc")
                    }
                    .keyboardShortcut("o")
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }

                RecentPDFsView()
                    .frame(maxWidth: 420)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isDropTargeted {
                DropTargetOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $isDropTargeted
        ) { providers in
            appState.openDroppedDocument(from: providers)
        }
        .animation(.easeInOut(duration: 0.16), value: isDropTargeted)
        .onAppear {
            appState.refreshRecentDocuments()
        }
    }
}

private struct RecentPDFsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var recentPDFs: [RecentDocumentItem] {
        Array(appState.recentDocuments.prefix(5))
    }

    var body: some View {
        if !recentPDFs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Button {
                        appState.clearRecentDocuments()
                    } label: {
                        Label("Clear Recent PDFs", systemImage: "xmark.circle")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    .help("Clear Recent PDFs")
                }

                ForEach(recentPDFs, id: \.id) { url in
                    Button {
                        appState.openRecentDocument(url.url)
                    } label: {
                        RecentPDFRow(item: url)
                    }
                    .buttonStyle(.plain)
                    .help(url.url.path)
                }
            }
            .padding(.top, 2)
        }
    }
}

private struct RecentPDFRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: RecentDocumentItem

    private var detailText: String {
        let pieces = [item.pageText, item.openedAt.map { Self.relativeDateFormatter.localizedString(for: $0, relativeTo: Date()) }]
            .compactMap { $0 }

        if pieces.isEmpty {
            return item.folderName
        }
        return pieces.joined(separator: " - ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(InterfacePalette.quietText(for: colorScheme))
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(InterfacePalette.subtleFill(for: colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 1)
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter
    }()
}

private struct DropTargetOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 36, weight: .regular))
                .symbolRenderingMode(.hierarchical)
            Text("Drop to Open")
                .font(.title3.weight(.semibold))
        }
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.72 : 0.82))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    Color.accentColor.opacity(colorScheme == .dark ? 0.68 : 0.58),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .padding(18)
        }
    }
}

private struct StatusBarView: View {
    @EnvironmentObject private var appState: AppState

    private var annotationStatusText: String {
        let count = appState.annotations.count
        return count == 1 ? "1 annotation" : "\(count) annotations"
    }

    var body: some View {
        if appState.isCompactWindow {
            compactStatus
        } else {
            regularStatus
        }
    }

    private var regularStatus: some View {
        HStack(spacing: 12) {
            Text(appState.statusMessage)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if appState.document != nil {
                if appState.hasUnsentSidebarReplyDraft {
                    Text("Reply draft")
                }
                Text(annotationStatusText)
                Text("Page \(appState.currentPageIndex + 1) of \(max(appState.pageCount, 1))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.bar)
    }

    private var compactStatus: some View {
        HStack(spacing: 8) {
            Text(appState.statusMessage)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            if appState.document != nil {
                if appState.hasUnsentSidebarReplyDraft {
                    Image(systemName: "text.bubble")
                        .help("Reply draft")
                        .accessibilityLabel("Reply draft")
                }

                Text("\(appState.currentPageIndex + 1)/\(max(appState.pageCount, 1))")
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(.bar)
    }
}

private struct ReaderToolbar: ToolbarContent {
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppSettings.highlightColorStorageKey)
    private var storedHighlightColor = AppSettings.defaultHighlightColorStorageValue
    @State private var showsHighlightPalette = false
    @FocusState private var searchFocused: Bool

    private var activeHighlightColor: NSColor {
        AppSettings.highlightColor(from: storedHighlightColor)
    }

    private var activeHighlightDisplayColor: Color {
        Color(nsColor: AppSettings.displayColor(forHighlightColor: activeHighlightColor))
    }

    private var pageNumberWidth: CGFloat {
        CGFloat(max(2, String(max(appState.pageCount, 1)).count)) * (appState.isCompactWindow ? 8 : 8.4)
            + (appState.isCompactWindow ? 16 : 20)
    }

    private var totalPageNumberWidth: CGFloat {
        CGFloat(max(1, String(max(appState.pageCount, 1)).count)) * (appState.isCompactWindow ? 7.8 : 8.2)
            + (appState.isCompactWindow ? 18 : 21)
    }

    private var pageSeparatorSpacing: CGFloat {
        appState.isCompactWindow ? 28 : 46
    }

    private var pageControlWidth: CGFloat {
        pageNumberWidth + totalPageNumberWidth + (appState.isCompactWindow ? 46 : 56)
    }

    private var compactToolbarControlsEnabled: Bool {
        appState.isCompactWindow
    }

    private var annotationToolsMenu: some View {
        Menu {
            Button {
                appState.toggleHighlighterMode()
            } label: {
                Label(
                    appState.isHighlighterModeActive
                    ? "Turn Highlighter Off (H)"
                    : "Turn Highlighter On (H)",
                    systemImage: "highlighter"
                )
            }
            .disabled(appState.document == nil)

            Button {
                appState.addUnderline()
            } label: {
                Label("Underline Selection (U)", systemImage: "underline")
            }
            .disabled(appState.document == nil || !appState.hasTextSelection)

            Button {
                appState.addComment()
            } label: {
                Label("Comment (C)", systemImage: "text.bubble")
            }
            .disabled(appState.document == nil || !appState.hasTextSelection)
        } label: {
            Image(systemName: "pencil.tip.crop.circle")
        }
        .help("Annotation Tools")
        .disabled(appState.document == nil)
    }

    private var highlightColorButton: some View {
        Button {
            showsHighlightPalette.toggle()
        } label: {
            Image(systemName: "circle.fill")
                .foregroundStyle(activeHighlightDisplayColor)
        }
        .popover(isPresented: $showsHighlightPalette, arrowEdge: .bottom) {
            HighlightPalettePopover(
                storedHighlightColor: $storedHighlightColor,
                onSelect: { color in
                    showsHighlightPalette = false
                    appState.selectHighlightColor(color, applyToSelection: appState.hasTextSelection)
                }
            )
        }
        .help("Highlight Color")
        .accessibilityLabel("Highlight Color Palette")
        .disabled(appState.document == nil)
    }

    var body: some ToolbarContent {
        if appState.document == nil {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.openDocument()
                } label: {
                    Label("Open", systemImage: "doc")
                }
                .help("Open PDF")
            }
        } else {
            ToolbarItemGroup(placement: .navigation) {
            Button {
                appState.togglePageSidebar()
            } label: {
                Image(systemName: "square.grid.2x2")
            }
            .labelStyle(.iconOnly)
            .disabled(appState.document == nil)
                .help("Toggle Page Thumbnails")

            Button {
                appState.toggleBookmarkForCurrentPage()
            } label: {
                Image(systemName: appState.currentPageBookmark == nil ? "bookmark" : "bookmark.fill")
            }
            .labelStyle(.iconOnly)
            .disabled(appState.document == nil)
            .help(appState.bookmarkActionHelpText)
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 5) {
                Button {
                    appState.goToPreviousPage()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!appState.canGoToPreviousPage)
                .help("Previous Page")

                TextField("Page", text: $appState.pageText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(width: pageNumberWidth, height: compactToolbarControlsEnabled ? 21 : 22)
                    .onSubmit {
                        appState.goToPageFromField()
                    }
                    .disabled(appState.document == nil)

                HStack(spacing: pageSeparatorSpacing) {
                    Text("/")
                    Text("\(max(appState.pageCount, 1))")
                }
                .font(.system(size: 13, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: totalPageNumberWidth + pageSeparatorSpacing, alignment: .leading)

                Button {
                    appState.goToNextPage()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!appState.canGoToNextPage)
                .help("Next Page")
                }
                .controlSize(.small)
                .frame(width: pageControlWidth)
            }

            ToolbarItemGroup(placement: .primaryAction) {
            if appState.showToolbarSearch {
                HStack(spacing: 7) {
                    ZStack(alignment: .trailing) {
                        TextField("Search", text: $appState.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(.leading, 10)
                            .padding(.trailing, appState.canClearSearchQuery ? 28 : 10)
                            .frame(height: compactToolbarControlsEnabled ? 26 : 28)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        searchFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                                        lineWidth: searchFocused ? 2 : 1
                                    )
                            }
                            .focused($searchFocused)
                            .onChange(of: appState.toolbarSearchFocusRequest) { _ in
                                searchFocused = true
                            }
                            .onSubmit {
                                appState.runSearch()
                            }
                            .disabled(appState.document == nil)

                        if appState.canClearSearchQuery {
                            Button {
                                appState.clearSearchQuery()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .symbolRenderingMode(.hierarchical)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 9)
                            .disabled(appState.document == nil)
                            .help("Clear Search")
                            .accessibilityLabel("Clear Search")
                        }
                    }
                    .frame(width: compactToolbarControlsEnabled ? 138 : 154, height: compactToolbarControlsEnabled ? 26 : 28)

                    if let searchSummaryText = appState.searchSummaryText {
                        Text(searchSummaryText)
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: searchSummaryText == "No match" ? 58 : 34, alignment: .leading)
                            .layoutPriority(1)
                            .accessibilityLabel(searchSummaryText)
                    }
                }

            Button {
                appState.previousSearchResult()
            } label: {
                Image(systemName: "chevron.left")
            }
            .labelStyle(.iconOnly)
            .disabled(appState.searchResults.isEmpty)
            .help("Previous Search Match")

            Button {
                appState.nextSearchResult()
            } label: {
                Image(systemName: "chevron.right")
            }
            .labelStyle(.iconOnly)
            .disabled(appState.searchResults.isEmpty)
            .help("Next Search Match")

            Button {
                appState.hideSearch()
            } label: {
                Image(systemName: "xmark")
            }
            .labelStyle(.iconOnly)
            .disabled(appState.document == nil)
            .help("Close Search")
        } else {
            Button {
                appState.showSearch()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .disabled(appState.document == nil)
            .help("Search")
        }
    }

        ToolbarItem(placement: .primaryAction) {
            annotationToolsMenu
        }

        ToolbarItem(placement: .primaryAction) {
            highlightColorButton
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                appState.fitWidth()
            } label: {
                Image(systemName: "arrow.left.and.right")
            }
            .labelStyle(.iconOnly)
            .disabled(appState.document == nil)
            .help("Fit to Width")

            Button {
                appState.toggleRightSidebarVisibility()
            } label: {
                Image(systemName: "sidebar.right")
                    .foregroundStyle(appState.showCommentsSidebar ? Color.accentColor : Color.primary)
            }
            .labelStyle(.iconOnly)
            .disabled(appState.document == nil)
            .help(appState.showCommentsSidebar ? "Hide Right Sidebar" : "Show Right Sidebar")
            .accessibilityLabel("Toggle Right Sidebar")

            Button {
                appState.shareDocument()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .disabled(appState.document == nil)
            .help("Share PDF")
        }
        }
    }
}

private struct HighlightPalettePopover: View {
    @Binding var storedHighlightColor: String
    let onSelect: (NSColor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "highlighter")
                    .foregroundStyle(Color(nsColor: AppSettings.displayColor(
                        forHighlightColor: AppSettings.highlightColor(from: storedHighlightColor)
                    )))
                Text("Highlight")
                    .font(.headline)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                ForEach(Array(AppSettings.highlightSwatches.enumerated()), id: \.offset) { _, swatch in
                    Button {
                        storedHighlightColor = AppSettings.storageString(forHighlightColor: swatch.color)
                        onSelect(swatch.color)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(nsColor: AppSettings.displayColor(forHighlightColor: swatch.color)))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            isSelected(swatch.color) ? Color.accentColor : Color(nsColor: .separatorColor),
                                            lineWidth: isSelected(swatch.color) ? 2 : 0.8
                                        )
                                }

                            if isSelected(swatch.color) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(nsColor: .labelColor))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(swatch.name)
                    .accessibilityLabel("Highlight \(swatch.name)")
                }
            }
        }
        .padding(14)
        .frame(width: 284)
    }

    private func isSelected(_ color: NSColor) -> Bool {
        AppSettings.storageString(forHighlightColor: color) == storedHighlightColor
    }
}
