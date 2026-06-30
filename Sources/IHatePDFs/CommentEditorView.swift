import IHatePDFsCore
import SwiftUI

@MainActor
final class CommentPopoverModel: ObservableObject {
    let context: AnnotationEditorContext

    @Published var text: String
    @Published var author: String

    private weak var appState: AppState?
    private var didFinish = false

    init(context: AnnotationEditorContext, appState: AppState) {
        self.context = context
        self.appState = appState
        self.text = context.initialText
        self.author = context.initialAuthor
    }

    func commit() {
        guard !didFinish else { return }
        didFinish = true
        appState?.saveEditor(context, text: text, author: author)
    }

    func delete() {
        guard !didFinish else { return }
        didFinish = true
        appState?.deleteAnnotations(in: context)
    }

    func updateDraft() {
        guard !didFinish else { return }
        appState?.updateEditorDraft(context, text: text, author: author)
    }

    func reply() {
        guard !didFinish else { return }
        didFinish = true
        appState?.replyFromEditor(context, text: text, author: author)
    }
}

struct CommentEditorView: View {
    @ObservedObject var model: CommentPopoverModel
    @Environment(\.colorScheme) private var colorScheme
    private let editorHorizontalInset: CGFloat = 9
    private let editorVerticalInset: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            commentField
            footer
        }
        .padding(12)
        .frame(width: 340)
        .background(.regularMaterial)
        .onChange(of: model.text) { _ in
            model.updateDraft()
        }
        .onChange(of: model.author) { _ in
            model.updateDraft()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .foregroundStyle(InterfacePalette.secondaryText(for: colorScheme))
                .frame(width: 16)

            Text(title)
                .font(.headline)
                .lineLimit(1)
        }
    }

    private var commentField: some View {
        ZStack(alignment: .topLeading) {
            CommitTextView(
                text: $model.text,
                font: NSFont.preferredFont(forTextStyle: .body),
                onCommit: {
                    model.commit()
                }
            )
                .padding(.horizontal, editorHorizontalInset)
                .padding(.vertical, editorVerticalInset)

            if model.text.isEmpty {
                Text(placeholderText)
                    .font(.body)
                    .foregroundStyle(InterfacePalette.quietText(for: colorScheme))
                    .padding(.leading, editorHorizontalInset + 7)
                    .padding(.top, editorVerticalInset)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 118)
        .background(InterfacePalette.fieldFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            TextField("Author", text: $model.author)
                .textFieldStyle(.plain)
                .foregroundStyle(InterfacePalette.primaryText(for: colorScheme))
                .onSubmit {
                    model.commit()
                }
                .padding(.horizontal, 7)
                .frame(height: 28)
                .background(InterfacePalette.fieldFill(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(InterfacePalette.hairline(for: colorScheme), lineWidth: 1)
                }
                .frame(width: 190)
                .layoutPriority(1)

            Spacer()

            if model.context.allowsReply,
               !model.context.isNewAnnotation,
               model.context.primaryAnnotation != nil {
                Button {
                    model.reply()
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                .labelStyle(.iconOnly)
                .frame(width: 34)
                .help("Reply")
                .accessibilityLabel("Reply")
            }

            if model.context.allowsDelete {
                if model.context.isNewAnnotation {
                    Button {
                        model.delete()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .labelStyle(.iconOnly)
                    .keyboardShortcut(.cancelAction)
                    .frame(width: 34)
                    .help("Cancel")
                } else {
                    Button(role: .destructive) {
                        model.delete()
                    } label: {
                        Label("Delete Annotation", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                    .frame(width: 34)
                    .help("Delete Annotation")
                }
            }
        }
    }

    private var title: String {
        model.context.title.replacingOccurrences(of: " Comment", with: "")
    }

    private var placeholderText: String {
        model.context.allowsReply ? "Add comment" : "Edit text"
    }

    private var symbolName: String {
        guard let annotation = model.context.primaryAnnotation else {
            return "text.bubble"
        }

        let kind = AcademicAnnotationKind(annotation: annotation)
        return kind.symbolName
    }
}
