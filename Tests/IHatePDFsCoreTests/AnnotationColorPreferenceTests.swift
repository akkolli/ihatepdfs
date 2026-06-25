import XCTest
import AppKit
@testable import IHatePDFsCore

final class AnnotationColorPreferenceTests: XCTestCase {
    func testColorPreferenceRoundTripsRGBAStorage() throws {
        let color = NSColor(deviceRed: 0.25, green: 0.5, blue: 0.75, alpha: 0.4)
        let storage = AnnotationColorPreference.storageString(for: color)
        XCTAssertEqual(storage, "#4080BF66")

        let decoded = AnnotationColorPreference.color(
            from: storage,
            fallback: AcademicAnnotationPalette.highlight
        )
        let components = try rgbaComponents(decoded)

        XCTAssertEqual(components.red, 0x40 / 255, accuracy: 0.001)
        XCTAssertEqual(components.green, 0x80 / 255, accuracy: 0.001)
        XCTAssertEqual(components.blue, 0xBF / 255, accuracy: 0.001)
        XCTAssertEqual(components.alpha, 0x66 / 255, accuracy: 0.001)
    }

    func testColorPreferenceUsesFallbackForInvalidStorage() throws {
        let decoded = AnnotationColorPreference.color(
            from: "not-a-color",
            fallback: AcademicAnnotationPalette.comment
        )

        try XCTAssertColor(decoded, equals: AcademicAnnotationPalette.comment)
    }

    func testColorPreferenceAppliesMinimumAlphaWithoutChangingRGB() throws {
        let decoded = AnnotationColorPreference.color(
            from: "#33669905",
            fallback: AcademicAnnotationPalette.highlight,
            minimumAlpha: 0.3
        )
        let components = try rgbaComponents(decoded)

        XCTAssertEqual(components.red, 0x33 / 255, accuracy: 0.001)
        XCTAssertEqual(components.green, 0x66 / 255, accuracy: 0.001)
        XCTAssertEqual(components.blue, 0x99 / 255, accuracy: 0.001)
        XCTAssertEqual(components.alpha, 0.3, accuracy: 0.001)
    }

    private func XCTAssertColor(
        _ actual: NSColor,
        equals expected: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actualComponents = try rgbaComponents(actual, file: file, line: line)
        let expectedComponents = try rgbaComponents(expected, file: file, line: line)

        XCTAssertEqual(actualComponents.red, expectedComponents.red, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualComponents.green, expectedComponents.green, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualComponents.blue, expectedComponents.blue, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualComponents.alpha, expectedComponents.alpha, accuracy: 0.001, file: file, line: line)
    }

    private func rgbaComponents(
        _ color: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let rgb = try XCTUnwrap(color.usingColorSpace(.deviceRGB), file: file, line: line)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}
