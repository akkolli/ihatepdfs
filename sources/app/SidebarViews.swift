import AppKit
import IHatePDFsCore
import SwiftUI

struct LeftSidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            LeftSidebarModeSwitcher(selection: $appState.leftSidebarMode)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Divider()

            switch appState.leftSidebarMode {
            case .pages:
                PDFThumbnailRepresentedView()
                    .padding(.vertical, 6)
            case .annotations:
                AnnotationNavigationListView()
            }
        }
        .background(.bar)
    }
}

private struct LeftSidebarModeSwitcher: View {
    @Binding var selection: LeftSidebarMode

    var body: some View {
        Picker("Left Sidebar", selection: $selection) {
            Text("Pages").tag(LeftSidebarMode.pages)
            Text("Marks").tag(LeftSidebarMode.annotations)
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .labelsHidden()
    }
}

private struct AnnotationNavigationListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            SidebarSectionHeader(
                title: "Annotations",
                count: appState.annotations.count,
                systemImage: "list.bullet.rectangle"
            )

            Divider()

            if appState.annotations.isEmpty {
                SidebarEmptyState(
                    systemImage: "list.bullet.rectangle",
                    title: "No annotations",
                    message: "Highlights, underlines, and comments will appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(appState.annotations) { item in
                            AnnotationNavigationRow(item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct AnnotationNavigationRow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let item: AnnotationSnapshot

    private var previewText: String {
        if item.kind == .highlight, !item.hasComment {
            return item.highlightExcerpt
        }

        if item.kind == .reply {
            return item.contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Reply"
                : item.contents
        }

        return item.firstLine
    }

    private var submetadataText: String {
        var parts = ["Page \(item.pageLabel)"]
        if !item.author.isEmpty {
            parts.append(item.author)
        }
        return parts.joined(separator: " - ")
    }

    private var dateText: String? {
        let date = item.modifiedAt ?? item.createdAt
        return date?.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        Button {
            appState.select(item)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.kind.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.id == appState.selectedAnnotationID ? Color.accentColor : InterfacePalette.secondaryText(for: colorScheme))
                    .frame(width: 16, height: 18)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(item.kind.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if let dateText {
                            Text(dateText)
                                .font(.caption2)
                                .foregroundStyle(InterfacePalette.quietText(for: colorScheme))
                                .lineLimit(1)
                        }
                    }

                    Text(submetadataText)
                        .font(.caption2)
                        .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                        .lineLimit(1)

                    Text(previewText)
                        .font(.caption)
                        .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(item.id == appState.selectedAnnotationID ? InterfacePalette.selectedRowFill(for: colorScheme) : Color.clear)
        }
        .buttonStyle(.plain)
        .help("Go to \(item.kind.displayName.lowercased()) on page \(item.pageLabel)")
        .onHover { isHovered in
            appState.setCommentHover(item, isHovered: isHovered)
        }
    }
}

struct RightSidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            SidebarModeSwitcher(selection: $appState.sidebarMode)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            switch appState.sidebarMode {
            case .annotations, .pages:
                CommentsReviewSidebar()
            case .highlights:
                HighlightedTextListView()
            }
        }
        .background(.bar)
    }
}

private struct SidebarModeSwitcher: View {
    @Binding var selection: SidebarMode

    var body: some View {
        Picker("Right Sidebar", selection: $selection) {
            Text("Comments").tag(SidebarMode.annotations)
            Text("Highlights").tag(SidebarMode.highlights)
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .labelsHidden()
    }
}

private struct HighlightedTextListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var totalHighlightCount: Int {
        appState.highlightedTextItems.count
    }

    var body: some View {
        VStack(spacing: 0) {
            highlightHeader

            Divider()

            if appState.highlightedTextGroups.isEmpty {
                SidebarEmptyState(
                    systemImage: "highlighter",
                    title: "No highlighted text",
                    message: "Highlighted passages will appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        switch appState.highlightSortMode {
                        case .color:
                            ForEach(appState.highlightedTextGroups, id: \.id) { group in
                                HighlightGroupView(group: group)
                            }
                        case .page:
                            ForEach(appState.highlightedTextItems) { item in
                                HighlightRow(item: item, showsColorSwatch: true)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var highlightHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "highlighter")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))

            Text("Highlights")
                .font(.headline)
                .lineLimit(1)

            Text("\(totalHighlightCount)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))

            Spacer()

            Button {
                appState.highlightSortMode = appState.highlightSortMode == .color ? .page : .color
            } label: {
                Image(systemName: appState.highlightSortMode.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .controlSize(.mini)
            .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
            .help("Sort highlights by \(appState.highlightSortMode == .color ? "page" : "color")")
            .accessibilityLabel("Toggle Highlight Sort")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}

private struct HighlightGroupView: View {
    let group: HighlightedTextGroup
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(group.color)
                    .frame(width: 34, height: 7)
                    .overlay {
                        Capsule()
                            .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 0.6)
                    }

                Text(group.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                Text("\(group.items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 5)
            .help(group.title)

            ForEach(group.items) { item in
                HighlightRow(item: item, showsColorSwatch: false)
            }
        }
    }
}

private struct HighlightRow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let item: AnnotationSnapshot
    let showsColorSwatch: Bool

    private var swatchColor: Color {
        Color(nsColor: AppSettings.displayColor(forHighlightColor: item.annotation.color))
    }

    var body: some View {
        Button {
            appState.selectHighlightedText(item)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.id == appState.selectedAnnotationID ? "largecircle.fill.circle" : "circle")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(item.id == appState.selectedAnnotationID ? Color.accentColor : InterfacePalette.quietText(for: colorScheme))
                    .frame(width: 14, height: 18)

                if showsColorSwatch {
                    Capsule()
                        .fill(swatchColor)
                        .frame(width: 20, height: 6)
                        .overlay {
                            Capsule()
                                .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 0.6)
                        }
                        .padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("p. \(item.pageLabel)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))

                    Text(item.highlightExcerpt)
                        .font(.caption)
                        .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(item.id == appState.selectedAnnotationID ? InterfacePalette.selectedRowFill(for: colorScheme) : Color.clear)
        }
        .buttonStyle(.plain)
        .help("Go to highlight on page \(item.pageLabel)")
        .onHover { isHovered in
            appState.setCommentHover(item, isHovered: isHovered)
        }
    }
}

private struct SidebarSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let count: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}

private struct SidebarEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(InterfacePalette.quietText(for: colorScheme))
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
            Text(message)
                .font(.caption)
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CommentsReviewSidebar: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsSearch = false
    @State private var showsFilters = false
    @State private var showsAdvancedFilters = false
    @FocusState private var isCommentSearchFocused: Bool

    private var groupedComments: [(pageIndex: Int, items: [AnnotationSnapshot])] {
        let grouped = Dictionary(grouping: appState.topLevelComments, by: \.pageIndex)
        return grouped
            .map { (pageIndex: $0.key, items: $0.value) }
            .sorted { $0.pageIndex < $1.pageIndex }
    }

    private var visibleCommentCount: Int {
        appState.topLevelComments.reduce(0) { partial, item in
            partial + 1 + (appState.repliesByParent[item.id]?.count ?? 0)
        }
    }

    private var totalCommentCount: Int {
        appState.annotations.reduce(0) { partial, item in
            let isVisibleReviewItem = item.isReply ? item.hasComment : item.kind != .highlight || item.hasComment
            return partial + (isVisibleReviewItem ? 1 : 0)
        }
    }

    private var isFilteringComments: Bool {
        hasActiveCommentSearch || hasActiveCommentFilters
    }

    private var hasActiveCommentSearch: Bool {
        !appState.commentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasActiveCommentFilters: Bool {
        appState.commentFilter != .all
            || appState.selectedKindFilter != nil
            || appState.selectedAuthorFilter != "All Authors"
            || appState.selectedStatusFilter != ReviewState.allStatuses
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isFilteringComments { filterSummary }
            if showsSearch || showsFilters {
                Divider()
                filters
            }
            Divider()
            commentList
        }
        .background(.bar)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                .help("Comments")

            Text("Comments")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)

            Text(commentCountText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()

            Spacer()

            Button {
                showsSearch.toggle()
                if showsSearch {
                    focusCommentSearch()
                } else {
                    isCommentSearchFocused = false
                }
            } label: {
                Label(
                    "Search Comments",
                    systemImage: (showsSearch || hasActiveCommentSearch) ? "magnifyingglass.circle.fill" : "magnifyingglass"
                )
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .foregroundStyle(hasActiveCommentSearch ? InterfacePalette.actionText(for: colorScheme) : InterfacePalette.secondaryText(for: colorScheme))
            .help("Search Comments")

            Button {
                showsFilters.toggle()
            } label: {
                Label(
                    "Filter Comments",
                    systemImage: (showsFilters || hasActiveCommentFilters) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                )
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .foregroundStyle(hasActiveCommentFilters ? InterfacePalette.actionText(for: colorScheme) : InterfacePalette.secondaryText(for: colorScheme))
            .help("Filter Comments")

            if isFilteringComments {
                Button {
                    clearVisibleFilters()
                } label: {
                    Label("Clear Comment Filters", systemImage: "xmark.circle.fill")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                .help("Clear Comment Filters")
                .accessibilityLabel("Clear Comment Filters")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private var commentCountText: String {
        guard isFilteringComments, totalCommentCount > 0 else { return "\(visibleCommentCount)" }
        return "\(visibleCommentCount)/\(totalCommentCount)"
    }

    private var filters: some View {
        VStack(spacing: 8) {
            if showsSearch {
                commentSearchField
            }

            if showsFilters {
                Picker("Comment filter", selection: $appState.commentFilter) {
                    ForEach(CommentFilter.allCases, id: \.self) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                DisclosureGroup("More Filters", isExpanded: $showsAdvancedFilters) {
                    VStack(spacing: 8) {
                        Picker("Type", selection: Binding(
                            get: { appState.selectedKindFilter },
                            set: { appState.selectedKindFilter = $0 }
                        )) {
                            Text("All Types").tag(Optional<AcademicAnnotationKind>.none)
                            ForEach(AcademicAnnotationKind.allCases.filter { $0 != .other }, id: \.self) { kind in
                                Text(kind.displayName).tag(Optional(kind))
                            }
                        }

                        Picker("Author", selection: $appState.selectedAuthorFilter) {
                            ForEach(appState.authors, id: \.self) { author in
                                Text(author).tag(author)
                            }
                        }

                        Picker("Status", selection: $appState.selectedStatusFilter) {
                            ForEach(appState.statuses, id: \.self) { status in
                                Text(status).tag(status)
                            }
                        }
                    }
                    .labelsHidden()
                    .padding(.top, 4)
                }
                .font(.caption)
            }
        }
        .padding(10)
    }

    private var filterSummary: some View {
        HStack(spacing: 8) {
            Label(commentCountText, systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.medium))
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                .lineLimit(1)

            Spacer(minLength: 6)

            Button {
                clearVisibleFilters()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.medium))
            .buttonStyle(.plain)
            .foregroundStyle(InterfacePalette.actionText(for: colorScheme))
            .help("Clear Comment Filters")
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(InterfacePalette.subtleFill(for: colorScheme))
    }

    private var commentSearchField: some View {
        ZStack(alignment: .trailing) {
            TextField("Search comments", text: $appState.commentSearchText)
                .textFieldStyle(.plain)
                .padding(.leading, 8)
                .padding(.trailing, hasActiveCommentSearch ? 28 : 8)
                .frame(height: 28)
                .background(InterfacePalette.fieldFill(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isCommentSearchFocused ? Color.accentColor : InterfacePalette.hairline(for: colorScheme),
                            lineWidth: isCommentSearchFocused ? 1.4 : 1
                        )
                }
                .focused($isCommentSearchFocused)
                .onAppear {
                    isCommentSearchFocused = true
                }

            if hasActiveCommentSearch {
                Button {
                    appState.commentSearchText = ""
                    focusCommentSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
                .help("Clear Search")
                .accessibilityLabel("Clear Search")
            }
        }
    }

    private func clearVisibleFilters() {
        appState.clearCommentFilters()
        if !showsSearch {
            isCommentSearchFocused = false
        }
    }

    private func focusCommentSearch() {
        isCommentSearchFocused = true
    }

    private var commentList: some View {
        Group {
            if groupedComments.isEmpty {
                CommentsEmptyState(isFiltering: isFilteringComments)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedComments, id: \.pageIndex) { group in
                            PageCommentGroup(
                                pageIndex: group.pageIndex,
                                items: group.items,
                                repliesByParent: appState.repliesByParent,
                                showsPageHeader: appState.pageCount > 1,
                                isFiltering: isFilteringComments
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct CommentsEmptyState: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let isFiltering: Bool

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle" : "text.bubble")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(InterfacePalette.quietText(for: colorScheme))

            Text(isFiltering ? "No matching comments" : "No comments yet")
                .font(.callout.weight(.semibold))
                .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))

            Text(isFiltering ? "Adjust search or filters." : "Comments will appear here.")
                .font(.caption)
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isFiltering {
                Button {
                    appState.clearCommentFilters()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PageCommentGroup: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let pageIndex: Int
    let items: [AnnotationSnapshot]
    let repliesByParent: [String: [AnnotationSnapshot]]
    let showsPageHeader: Bool
    let isFiltering: Bool

    private var isCollapsed: Bool {
        showsPageHeader && !isFiltering && appState.collapsedPageIndexes.contains(pageIndex)
    }

    private var visibleItemCount: Int {
        items.reduce(0) { partial, item in
            partial + 1 + (repliesByParent[item.id]?.count ?? 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsPageHeader {
                if isFiltering {
                    pageHeader
                        .help("Filtered results are expanded")
                } else {
                    Button {
                        if isCollapsed {
                            appState.collapsedPageIndexes.remove(pageIndex)
                        } else {
                            appState.collapsedPageIndexes.insert(pageIndex)
                        }
                    } label: {
                        pageHeader
                    }
                    .buttonStyle(.plain)
                    .help(isCollapsed ? "Expand Page Comments" : "Collapse Page Comments")
                }
            }

            if !isCollapsed {
                ForEach(items) { item in
                    let replies = repliesByParent[item.id] ?? []
                    CommentRow(item: item, replies: replies)
                        .id(([item.sidebarRenderID] + replies.map(\.sidebarRenderID)).joined(separator: "|"))
                }
            }
        }
    }

    private var pageHeader: some View {
        HStack {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.caption2.weight(.semibold))
                .frame(width: 12)
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
            Text("Page \(pageIndex + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
            Spacer()
            Text("\(visibleItemCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
        }
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 5)
    }
}

private struct CommentRow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isRowHovered = false
    let item: AnnotationSnapshot
    let replies: [AnnotationSnapshot]

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !replies.isEmpty {
                Rectangle()
                    .fill(InterfacePalette.connector(for: colorScheme))
                    .frame(width: 1)
                    .padding(.leading, 22)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
            }

            VStack(alignment: .leading, spacing: 0) {
                parentComment

                ForEach(replies) { reply in
                    ReplyRow(item: reply, threadRoot: item)
                        .id(reply.sidebarRenderID)
                }

                if appState.sidebarReplyParentID == item.id {
                    SidebarReplyComposer(threadRoot: item)
                        .id("reply-composer-\(item.id)")
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InterfacePalette.hairline(for: colorScheme))
                .frame(height: 1)
        }
    }

    private var parentComment: some View {
        HStack(alignment: .top, spacing: 8) {
            CommentMarker(symbolName: item.kind.symbolName, size: 28, font: .caption)
                .frame(width: 30, alignment: .center)
                .padding(.top, 2)
                .help(item.kind == .reply ? "Reply" : "Comment Thread")

            VStack(alignment: .leading, spacing: 5) {
                Button {
                    appState.select(item)
                } label: {
                    commentSummary
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                        appState.select(item)
                }

                HStack(spacing: 6) {
                    Text(item.kind.displayName)
                        .font(.caption2)
                        .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    ReviewStatusChip(item: item)
                    Spacer()
                    CommentReviewRowActions(
                        isVisible: isRowHovered || appState.sidebarReplyParentID == item.id,
                        onEdit: {
                            appState.edit(item)
                        },
                        onReply: {
                            appState.beginSidebarReply(to: item, inThread: item)
                        },
                        onDelete: {
                            appState.delete(item)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowFill(for: item))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovered in
            isRowHovered = isHovered
            appState.setCommentHover(item, isHovered: isHovered)
        }
        .contextMenu {
            Button {
                appState.edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                appState.beginSidebarReply(to: item, inThread: item)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            Button(role: .destructive) {
                appState.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var commentSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.author)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                Text(dateString(item.modifiedAt ?? item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }

            if item.hasComment {
                Text(item.contents)
                    .font(.callout)
                    .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            } else if replies.isEmpty {
                Text("No comment text")
                    .font(.callout)
                    .foregroundStyle(InterfacePalette.quietText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func rowFill(for item: AnnotationSnapshot) -> Color {
        if item.id == appState.selectedAnnotationID {
            return InterfacePalette.selectedRowFill(for: colorScheme)
        }
        if isRowHovered {
            return InterfacePalette.subtleFill(for: colorScheme)
        }
        return Color.clear
    }

    private func dateString(_ date: Date?) -> String {
        guard let date else { return "No date" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private extension AnnotationSnapshot {
    var sidebarRenderID: String {
        [
            id,
            author,
            contents,
            status,
            String(modifiedAt?.timeIntervalSinceReferenceDate ?? 0),
            String(describing: bounds.minX),
            String(describing: bounds.minY)
        ].joined(separator: "|")
    }
}

private struct CommentMarker: View {
    @Environment(\.colorScheme) private var colorScheme
    let symbolName: String
    let size: CGFloat
    let font: Font

    var body: some View {
        ZStack {
            Circle()
                .fill(InterfacePalette.markerFill(for: colorScheme))
            Circle()
                .stroke(InterfacePalette.markerStroke(for: colorScheme), lineWidth: 0.75)
            Image(systemName: symbolName)
                .font(font)
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct SidebarReplyComposer: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let threadRoot: AnnotationSnapshot

    private let editorHorizontalInset: CGFloat = 7
    private let editorVerticalInset: CGFloat = 6

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CommentMarker(symbolName: "arrowshape.turn.up.left", size: 22, font: .caption2)
                .frame(width: 28, alignment: .center)
                .padding(.top, 9)
                .help("Reply")

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Reply")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))

                    if let target = appState.sidebarReplyTarget {
                        Text("to \(target.author)")
                            .font(.caption2)
                            .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                            .lineLimit(1)
                    } else {
                        Text("to \(threadRoot.author)")
                            .font(.caption2)
                            .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                            .lineLimit(1)
                    }

                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    CommitTextView(
                        text: $appState.sidebarReplyDraft,
                        font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                        onCommit: {
                            if !appState.sidebarReplyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                appState.commitSidebarReply()
                            }
                        }
                    )
                        .padding(.horizontal, editorHorizontalInset)
                        .padding(.vertical, editorVerticalInset)

                    if appState.sidebarReplyDraft.isEmpty {
                        Text("Write a reply")
                            .font(.callout)
                            .foregroundStyle(InterfacePalette.quietText(for: colorScheme))
                            .padding(.leading, editorHorizontalInset + 6)
                            .padding(.top, editorVerticalInset)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 76)
                .background(InterfacePalette.fieldFill(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 1)
                }

                HStack(spacing: 8) {
                    TextField("Author", text: $appState.sidebarReplyAuthor)
                        .textFieldStyle(.plain)
                        .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                        .onSubmit {
                            if !appState.sidebarReplyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                appState.commitSidebarReply()
                            }
                        }
                        .padding(.horizontal, 7)
                        .frame(height: 26)
                        .background(InterfacePalette.fieldFill(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 1)
                        }

                    Spacer()

                    Button("Cancel") {
                        appState.cancelSidebarReply()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))

                    Button {
                        appState.commitSidebarReply()
                    } label: {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                    .disabled(appState.sidebarReplyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
                .font(.caption.weight(.medium))
            }
        }
        .padding(.top, 9)
        .padding(.bottom, 2)
    }
}

private struct ReviewStatusChip: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let item: AnnotationSnapshot

    var body: some View {
        Button {
            appState.toggleReviewed(item)
        } label: {
            HStack(spacing: 4) {
                if isReviewed {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }

                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(background)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(isReviewed ? "Mark as not reviewed" : "Mark as reviewed")
    }

    private var isReviewed: Bool {
        ReviewState.isReviewed(item.status)
    }

    private var label: String {
        ReviewState.label(for: item.status)
    }

    private var foreground: Color {
        isReviewed
            ? InterfacePalette.actionText(for: colorScheme)
            : InterfacePalette.quietText(for: colorScheme)
    }

    private var background: Color {
        if isReviewed {
            return Color(nsColor: .controlAccentColor).opacity(colorScheme == .dark ? 0.16 : 0.11)
        }
        return InterfacePalette.subtleFill(for: colorScheme)
    }
}

private struct ReplyRow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isRowHovered = false
    let item: AnnotationSnapshot
    let threadRoot: AnnotationSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CommentMarker(symbolName: "text.bubble", size: 22, font: .caption2)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)
                .help("Reply")

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    appState.select(item)
                } label: {
                    replySummary
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                        appState.select(item)
                }

                HStack(spacing: 6) {
                    Text("Reply")
                        .font(.caption2)
                        .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    ReviewStatusChip(item: item)
                    Spacer()
                    CommentReviewRowActions(
                        isVisible: isRowHovered || appState.sidebarReplyParentID == threadRoot.id,
                        onEdit: {
                            appState.edit(item)
                        },
                        onReply: {
                            appState.beginSidebarReply(to: item, inThread: threadRoot)
                        },
                        onDelete: {
                            appState.delete(item)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowFill)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .padding(.top, 4)
        .onHover { isHovered in
            isRowHovered = isHovered
            appState.setCommentHover(item, isHovered: isHovered)
        }
        .contextMenu {
            Button {
                appState.edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                appState.beginSidebarReply(to: item, inThread: threadRoot)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            Button(role: .destructive) {
                appState.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var rowFill: Color {
        if item.id == appState.selectedAnnotationID {
            return InterfacePalette.selectedRowFill(for: colorScheme)
        }
        if isRowHovered {
            return InterfacePalette.subtleFill(for: colorScheme)
        }
        return Color.clear
    }

    private var replySummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.author)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                    .lineLimit(1)
                Spacer()
                Text(dateString(item.modifiedAt ?? item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }

            Text(item.contents.isEmpty ? "No reply text" : item.contents)
                .font(.caption)
                .foregroundStyle(item.contents.isEmpty ? InterfacePalette.quietText(for: colorScheme) : InterfacePalette.primaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dateString(_ date: Date?) -> String {
        guard let date else { return "No date" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct CommentReviewRowActions: View {
    let isVisible: Bool
    let onEdit: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(role: .none, action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .none, action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.12), value: isVisible)
    }
}
