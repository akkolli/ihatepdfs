import AppKit
import Foundation

public enum AnnotationColorPreference {
    public static func color(
        from storageValue: String?,
        fallback: NSColor,
        minimumAlpha: CGFloat = 0
    ) -> NSColor {
        guard let storageValue,
              let color = color(from: storageValue)
        else {
            return normalized(fallback, fallback: fallback, minimumAlpha: minimumAlpha)
        }

        return normalized(color, fallback: fallback, minimumAlpha: minimumAlpha)
    }

    public static func storageString(for color: NSColor, fallback: String = "#FFD11F85") -> String {
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return fallback
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(
            format: "#%02X%02X%02X%02X",
            byte(red),
            byte(green),
            byte(blue),
            byte(alpha)
        )
    }

    private static func color(from storageValue: String) -> NSColor? {
        var raw = storageValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") {
            raw.removeFirst()
        }

        guard raw.count == 8,
              let value = UInt32(raw, radix: 16)
        else {
            return nil
        }

        let red = CGFloat((value >> 24) & 0xFF) / 255
        let green = CGFloat((value >> 16) & 0xFF) / 255
        let blue = CGFloat((value >> 8) & 0xFF) / 255
        let alpha = CGFloat(value & 0xFF) / 255
        return NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }

    private static func normalized(
        _ color: NSColor,
        fallback: NSColor,
        minimumAlpha: CGFloat
    ) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return fallback
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return NSColor(
            deviceRed: red,
            green: green,
            blue: blue,
            alpha: max(alpha, minimumAlpha)
        )
    }

    private static func byte(_ value: CGFloat) -> Int {
        max(0, min(255, Int((value * 255).rounded())))
    }
}
