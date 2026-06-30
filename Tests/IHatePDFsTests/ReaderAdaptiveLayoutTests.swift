import XCTest
@testable import IHatePDFs

final class ReaderAdaptiveLayoutTests: XCTestCase {
    func testSizeClassBreakpointsMatchMacWindowProfiles() {
        XCTAssertEqual(ReaderAdaptiveLayout(width: 759).sizeClass, .compact)
        XCTAssertEqual(ReaderAdaptiveLayout(width: 959).sizeClass, .compact)
        XCTAssertEqual(ReaderAdaptiveLayout(width: 960).sizeClass, .regular)
        XCTAssertEqual(ReaderAdaptiveLayout(width: 1_279).sizeClass, .regular)
        XCTAssertEqual(ReaderAdaptiveLayout(width: 1_280).sizeClass, .wide)
    }

    func testCompactProfileKeepsSingleSidebarAndDocumentReadableAtMinimumWidth() {
        let layout = ReaderAdaptiveLayout(width: ReaderAdaptiveLayout.minimumWindowWidth)
        XCTAssertEqual(layout.sizeClass, .compact)
        XCTAssertFalse(layout.allowsDualSidebars)
        XCTAssertTrue(layout.usesCompactToolbar)

        assertDocumentWidthIsPreserved(
            layout: layout,
            availableWidth: ReaderAdaptiveLayout.minimumWindowWidth,
            requestedLeft: layout.leftSidebarMaxWidth,
            requestedRight: 0,
            showLeft: true,
            showRight: false
        )

        assertDocumentWidthIsPreserved(
            layout: layout,
            availableWidth: ReaderAdaptiveLayout.minimumWindowWidth,
            requestedLeft: 0,
            requestedRight: layout.rightSidebarMaxWidth,
            showLeft: false,
            showRight: true
        )
    }

    func testRegularProfilePreservesDocumentWidthWithBothSidebarsAtBreakpoint() {
        let layout = ReaderAdaptiveLayout(width: 960)
        XCTAssertEqual(layout.sizeClass, .regular)
        XCTAssertTrue(layout.allowsDualSidebars)
        XCTAssertFalse(layout.usesCompactToolbar)

        assertDocumentWidthIsPreserved(
            layout: layout,
            availableWidth: 960,
            requestedLeft: layout.leftSidebarIdealWidth,
            requestedRight: layout.rightSidebarIdealWidth,
            showLeft: true,
            showRight: true
        )
    }

    func testExpandedRegularSidebarsShrinkBeforeTheDocumentDoes() {
        let layout = ReaderAdaptiveLayout(width: 960)

        let widths = layout.resolvedSidebarWidths(
            availableWidth: 960,
            requestedLeft: layout.leftSidebarMaxWidth,
            requestedRight: layout.rightSidebarMaxWidth,
            showLeft: true,
            showRight: true
        )

        XCTAssertGreaterThanOrEqual(widths.left, layout.leftSidebarMinWidth - 0.001)
        XCTAssertGreaterThanOrEqual(widths.right, layout.rightSidebarMinWidth - 0.001)
        XCTAssertLessThanOrEqual(widths.left, layout.leftSidebarMaxWidth + 0.001)
        XCTAssertLessThanOrEqual(widths.right, layout.rightSidebarMaxWidth + 0.001)
        assertDocumentWidthIsPreserved(
            layout: layout,
            availableWidth: 960,
            requestedLeft: layout.leftSidebarMaxWidth,
            requestedRight: layout.rightSidebarMaxWidth,
            showLeft: true,
            showRight: true
        )
    }

    func testWideProfileUsesRoomierSidebarsWhilePreservingDocumentWidth() {
        let layout = ReaderAdaptiveLayout(width: 1_280)
        XCTAssertEqual(layout.sizeClass, .wide)
        XCTAssertGreaterThan(layout.rightSidebarIdealWidth, ReaderAdaptiveLayout(width: 960).rightSidebarIdealWidth)
        XCTAssertGreaterThan(layout.documentMinWidth, ReaderAdaptiveLayout(width: 960).documentMinWidth)

        assertDocumentWidthIsPreserved(
            layout: layout,
            availableWidth: 1_280,
            requestedLeft: layout.leftSidebarIdealWidth,
            requestedRight: layout.rightSidebarIdealWidth,
            showLeft: true,
            showRight: true
        )
    }

    private func assertDocumentWidthIsPreserved(
        layout: ReaderAdaptiveLayout,
        availableWidth: CGFloat,
        requestedLeft: CGFloat,
        requestedRight: CGFloat,
        showLeft: Bool,
        showRight: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let widths = layout.resolvedSidebarWidths(
            availableWidth: availableWidth,
            requestedLeft: requestedLeft,
            requestedRight: requestedRight,
            showLeft: showLeft,
            showRight: showRight
        )
        let documentWidth = layout.visibleContentWidth(
            availableWidth: availableWidth,
            leftWidth: widths.left,
            rightWidth: widths.right,
            showLeft: showLeft,
            showRight: showRight
        )

        XCTAssertGreaterThanOrEqual(documentWidth, layout.documentMinWidth - 0.001, file: file, line: line)
    }
}
