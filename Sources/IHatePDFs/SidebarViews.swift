import IHatePDFsCore
import SwiftUI

struct LeftSidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sidebar", selection: $appState.sidebarMode) {
                Text("Pages").tag(SidebarMode.pages)
                Text("Annotations").tag(SidebarMode.annotations)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            Divider()

            switch appState.sidebarMode {
            case .pages:
                PDFThumbnailRepresentedView()
                    .padding(.vertical, 6)
            case .annotations:
                AnnotationListView()
            }
        }
        .background(.bar)
    }
}

private struct AnnotationListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(appState.annotations, selection: $appState.selectedAnnotationID) { item in
            Button {
                appState.select(item)
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.kind.symbolName)
                        .frame(width: 18)
                        .foregroundStyle(iconColor(for: item.kind))
                        .help(item.kind.displayName)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.kind.displayName)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("p. \(item.pageLabel)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(item.firstLine)
                            .font(.caption)
                            .foregroundStyle(item.hasComment ? .primary : .secondary)
                            .lineLimit(2)

                        Text(item.author)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(dateString(item.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.sidebar)
    }

    private func iconColor(for kind: AcademicAnnotationKind) -> Color {
        switch kind {
        case .comment, .highlight, .note:
            return Color(nsColor: .secondaryLabelColor)
        case .underline, .reply:
            return Color(nsColor: .tertiaryLabelColor)
        case .freeText:
            return Color(nsColor: .labelColor)
        case .other:
            return Color(nsColor: .tertiaryLabelColor)
        }
    }

    private func dateString(_ date: Date?) -> String {
        guard let date else { return "No date" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct CommentsReviewSidebar: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsSearch = false
    @State private var showsFilters = false
    @State private var showsAdvancedFilters = false

    private var groupedComments: [(pageIndex: Int, items: [AnnotationSnapshot])] {
        let grouped = Dictionary(grouping: appState.topLevelComments, by: \.pageIndex)
        return grouped
            .map { (pageIndex: $0.key, items: $0.value) }
            .sorted { $0.pageIndex < $1.pageIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            quickComment
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
        HStack(spacing: 9) {
                Image(systemName: "text.bubble.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                .help("Comments")

            Text("Comments")
                .font(.headline)
                .lineLimit(1)

            Text("\(appState.annotations.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                showsSearch.toggle()
            } label: {
                Label("Search Comments", systemImage: showsSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .help("Search Comments")

            Button {
                showsFilters.toggle()
            } label: {
                Label("Filter Comments", systemImage: showsFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .labelStyle(.iconOnly)
            .help("Filter Comments")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private var quickComment: some View {
        Button {
            appState.addComment()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    .help("Comment on selected text")

                Text("On selected text")
                    .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))

                Spacer()
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(InterfacePalette.subtleFill(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .help("Select text, then add a comment")
    }

    private var filters: some View {
        VStack(spacing: 8) {
            if showsSearch {
                TextField("Search comments", text: $appState.commentSearchText)
                    .textFieldStyle(.roundedBorder)
            }

            if showsFilters {
                Picker("Comment filter", selection: $appState.commentFilter) {
                    ForEach(CommentFilter.allCases) { filter in
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
                            ForEach(AcademicAnnotationKind.allCases.filter { $0 != .other }) { kind in
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

    private var commentList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedComments, id: \.pageIndex) { group in
                    PageCommentGroup(
                        pageIndex: group.pageIndex,
                        items: group.items,
                        repliesByParent: appState.repliesByParent,
                        showsPageHeader: appState.pageCount > 1
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct PageCommentGroup: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let pageIndex: Int
    let items: [AnnotationSnapshot]
    let repliesByParent: [String: [AnnotationSnapshot]]
    let showsPageHeader: Bool

    private var isCollapsed: Bool {
        showsPageHeader && appState.collapsedPageIndexes.contains(pageIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsPageHeader {
                Button {
                    if isCollapsed {
                        appState.collapsedPageIndexes.remove(pageIndex)
                    } else {
                        appState.collapsedPageIndexes.insert(pageIndex)
                    }
                } label: {
                    HStack {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .frame(width: 12)
                            .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                        Text("Page \(pageIndex + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                        Spacer()
                        Text("\(items.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 7)
                    .padding(.bottom, 5)
                }
                .buttonStyle(.plain)
                .help(isCollapsed ? "Expand Page Comments" : "Collapse Page Comments")
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
}

private struct CommentRow: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let item: AnnotationSnapshot
    let replies: [AnnotationSnapshot]

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !replies.isEmpty {
                Rectangle()
                    .fill(InterfacePalette.connector(for: colorScheme))
                    .frame(width: 1)
                    .padding(.leading, 14)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InterfacePalette.hairline(for: colorScheme))
                .frame(height: 1)
        }
    }

    private var parentComment: some View {
        HStack(alignment: .top, spacing: 9) {
            CommentMarker(symbolName: item.kind.symbolName, size: 28, font: .caption)
                .padding(.top, 1)
                .help(item.kind == .reply ? "Reply" : "Comment Thread")

            VStack(alignment: .leading, spacing: 6) {
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

                metadataRow(for: item)

                HStack(spacing: 12) {
                    Button("Edit") {
                        appState.edit(item)
                    }
                    Button("Reply") {
                        appState.beginSidebarReply(to: item, inThread: item)
                    }
                    Button("Delete", role: .destructive) {
                        appState.delete(item)
                    }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(InterfacePalette.actionText(for: colorScheme))
            }
        }
        .padding(.vertical, 2)
        .background(item.id == appState.selectedAnnotationID ? InterfacePalette.selectedRowFill(for: colorScheme) : Color.clear)
        .onHover { isHovered in
            appState.setCommentHover(item, isHovered: isHovered)
        }
    }

    private var commentSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
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

    private func metadataRow(for item: AnnotationSnapshot) -> some View {
        HStack {
            ReviewStatusChip(item: item)
        }
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
        .background(.bar)
        .clipShape(Circle())
    }
}

private struct SidebarReplyComposer: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
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
                    TextEditor(text: $appState.sidebarReplyDraft)
                        .font(.callout)
                        .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
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
        .onAppear {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .commitOnPlainReturn {
            if !appState.sidebarReplyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appState.commitSidebarReply()
            }
        }
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
    let item: AnnotationSnapshot
    let threadRoot: AnnotationSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CommentMarker(symbolName: "text.bubble", size: 22, font: .caption2)
                .frame(width: 28, alignment: .center)
                .padding(.top, 7)
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

                replyMetadataRow

                HStack(spacing: 12) {
                    Button("Edit") {
                        appState.edit(item)
                    }
                    Button("Reply") {
                        appState.beginSidebarReply(to: item, inThread: threadRoot)
                    }
                    Button("Delete", role: .destructive) {
                        appState.delete(item)
                    }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(InterfacePalette.actionText(for: colorScheme))
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(item.id == appState.selectedAnnotationID ? InterfacePalette.selectedRowFill(for: colorScheme) : Color.clear)
        .onHover { isHovered in
            appState.setCommentHover(item, isHovered: isHovered)
        }
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

    private var replyMetadataRow: some View {
        HStack {
            ReviewStatusChip(item: item)
        }
    }

    private func dateString(_ date: Date?) -> String {
        guard let date else { return "No date" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
