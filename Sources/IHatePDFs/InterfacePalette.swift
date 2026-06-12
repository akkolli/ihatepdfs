import AppKit
import SwiftUI

enum InterfacePalette {
    static func primaryText(for scheme: ColorScheme) -> Color {
        Color(nsColor: .labelColor).opacity(scheme == .dark ? 0.88 : 0.86)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        Color(nsColor: .secondaryLabelColor).opacity(scheme == .dark ? 0.92 : 0.88)
    }

    static func quietText(for scheme: ColorScheme) -> Color {
        Color(nsColor: .tertiaryLabelColor).opacity(scheme == .dark ? 0.92 : 0.9)
    }

    static func actionText(for scheme: ColorScheme) -> Color {
        Color(nsColor: .controlAccentColor).opacity(scheme == .dark ? 0.78 : 0.72)
    }

    static func subtleFill(for scheme: ColorScheme) -> Color {
        Color(nsColor: overlayBase(for: scheme).withAlphaComponent(scheme == .dark ? 0.045 : 0.026))
    }

    static func fieldFill(for scheme: ColorScheme) -> Color {
        Color(nsColor: overlayBase(for: scheme).withAlphaComponent(scheme == .dark ? 0.055 : 0.032))
    }

    static func hairline(for scheme: ColorScheme) -> Color {
        Color(nsColor: overlayBase(for: scheme).withAlphaComponent(scheme == .dark ? 0.12 : 0.095))
    }

    static func connector(for scheme: ColorScheme) -> Color {
        Color(nsColor: overlayBase(for: scheme).withAlphaComponent(scheme == .dark ? 0.14 : 0.11))
    }

    static func markerFill(for scheme: ColorScheme) -> Color {
        Color(nsColor: overlayBase(for: scheme).withAlphaComponent(scheme == .dark ? 0.055 : 0.035))
    }

    static func markerStroke(for scheme: ColorScheme) -> Color {
        Color(nsColor: overlayBase(for: scheme).withAlphaComponent(scheme == .dark ? 0.16 : 0.13))
    }

    static func selectedRowFill(for scheme: ColorScheme) -> Color {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
            .opacity(scheme == .dark ? 0.38 : 0.48)
    }

    private static func overlayBase(for scheme: ColorScheme) -> NSColor {
        scheme == .dark ? .white : .black
    }
}
