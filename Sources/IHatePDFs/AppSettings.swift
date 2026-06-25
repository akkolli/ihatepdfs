import AppKit
import Foundation
import IHatePDFsCore
import SwiftUI

enum AppSettings {
    static let highlightColorStorageKey = "IHatePDFs.highlightColorRGBA.v1"
    static let commentColorStorageKey = "IHatePDFs.commentColorRGBA.v1"
    static let defaultHighlightColorStorageValue = storageString(for: AcademicAnnotationPalette.highlight)
    static let defaultCommentColorStorageValue = storageString(for: AcademicAnnotationPalette.comment)
    private static let minimumHighlightAlpha: CGFloat = 0.38
    private static let minimumCommentAlpha: CGFloat = 0.12

    static var highlightColor: NSColor {
        get {
            highlightColor(from: UserDefaults.standard.string(forKey: highlightColorStorageKey))
        }
        set {
            UserDefaults.standard.set(storageString(forHighlightColor: newValue), forKey: highlightColorStorageKey)
        }
    }

    static var commentColor: NSColor {
        get {
            commentColor(from: UserDefaults.standard.string(forKey: commentColorStorageKey))
        }
        set {
            UserDefaults.standard.set(storageString(forCommentColor: newValue), forKey: commentColorStorageKey)
        }
    }

    static func highlightColor(from storageValue: String?) -> NSColor {
        AnnotationColorPreference.color(
            from: storageValue,
            fallback: AcademicAnnotationPalette.highlight,
            minimumAlpha: minimumHighlightAlpha
        )
    }

    static func commentColor(from storageValue: String?) -> NSColor {
        AnnotationColorPreference.color(
            from: storageValue,
            fallback: AcademicAnnotationPalette.comment,
            minimumAlpha: minimumCommentAlpha
        )
    }

    static func storageString(for color: NSColor) -> String {
        AnnotationColorPreference.storageString(for: color)
    }

    static func storageString(for color: Color) -> String {
        storageString(for: NSColor(color))
    }

    static func storageString(forHighlightColor color: NSColor) -> String {
        storageString(for: highlightColor(from: storageString(for: color)))
    }

    static func storageString(forHighlightColor color: Color) -> String {
        storageString(forHighlightColor: NSColor(color))
    }

    static func storageString(forCommentColor color: NSColor) -> String {
        storageString(for: commentColor(from: storageString(for: color)))
    }

    static func storageString(forCommentColor color: Color) -> String {
        storageString(forCommentColor: NSColor(color))
    }
}

struct SettingsView: View {
    @AppStorage(AppSettings.highlightColorStorageKey)
    private var storedHighlightColor = AppSettings.defaultHighlightColorStorageValue
    @AppStorage(AppSettings.commentColorStorageKey)
    private var storedCommentColor = AppSettings.defaultCommentColorStorageValue

    var body: some View {
        Form {
            Section("Annotations") {
                ColorPicker(
                    "Highlight color",
                    selection: highlightColor,
                    supportsOpacity: true
                )

                ColorPicker(
                    "Comment color",
                    selection: commentColor,
                    supportsOpacity: true
                )

                Button {
                    storedHighlightColor = AppSettings.defaultHighlightColorStorageValue
                    storedCommentColor = AppSettings.defaultCommentColorStorageValue
                } label: {
                    Label("Reset Annotation Colors", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var highlightColor: Binding<Color> {
        Binding {
            Color(nsColor: AppSettings.highlightColor(from: storedHighlightColor))
        } set: { newValue in
            storedHighlightColor = AppSettings.storageString(forHighlightColor: newValue)
        }
    }

    private var commentColor: Binding<Color> {
        Binding {
            Color(nsColor: AppSettings.commentColor(from: storedCommentColor))
        } set: { newValue in
            storedCommentColor = AppSettings.storageString(forCommentColor: newValue)
        }
    }
}
