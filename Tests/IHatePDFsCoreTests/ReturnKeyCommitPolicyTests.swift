import XCTest
@testable import IHatePDFsCore

final class ReturnKeyCommitPolicyTests: XCTestCase {
    func testPlainReturnCommitsInEditableMultilineText() {
        XCTAssertTrue(ReturnKeyCommitPolicy.shouldCommit(
            keyCode: 36,
            shift: false,
            option: false,
            command: false,
            control: false,
            isEditableMultilineText: true
        ))
    }

    func testCommandReturnCommitsWhenCommandReturnOnlyModeEnabled() {
        XCTAssertTrue(ReturnKeyCommitPolicy.shouldCommit(
            keyCode: 36,
            shift: false,
            option: false,
            command: true,
            control: false,
            isEditableMultilineText: true,
            commandReturnOnly: true
        ))
    }

    func testPlainReturnDoesNotCommitWhenCommandReturnOnlyModeEnabled() {
        XCTAssertFalse(ReturnKeyCommitPolicy.shouldCommit(
            keyCode: 36,
            shift: false,
            option: false,
            command: false,
            control: false,
            isEditableMultilineText: true,
            commandReturnOnly: true
        ))
    }

    func testKeypadEnterCommitsInEditableMultilineText() {
        XCTAssertTrue(ReturnKeyCommitPolicy.shouldCommit(
            keyCode: 76,
            shift: false,
            option: false,
            command: false,
            control: false,
            isEditableMultilineText: true
        ))
    }

    func testShiftReturnDoesNotCommitSoTextViewCanInsertNewline() {
        XCTAssertFalse(ReturnKeyCommitPolicy.shouldCommit(
            keyCode: 36,
            shift: true,
            option: false,
            command: false,
            control: false,
            isEditableMultilineText: true
        ))
    }

    func testReturnDoesNotCommitOutsideEditableMultilineText() {
        XCTAssertFalse(ReturnKeyCommitPolicy.shouldCommit(
            keyCode: 36,
            shift: false,
            option: false,
            command: false,
            control: false,
            isEditableMultilineText: false
        ))
    }
}
