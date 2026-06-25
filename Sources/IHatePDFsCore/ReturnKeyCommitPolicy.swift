import Foundation

public enum ReturnKeyCommitPolicy {
    public static func shouldCommit(
        keyCode: UInt16,
        shift: Bool,
        option: Bool,
        command: Bool,
        control: Bool,
        isEditableMultilineText: Bool
    ) -> Bool {
        guard isEditableMultilineText else { return false }
        guard keyCode == 36 || keyCode == 76 else { return false }
        return !shift && !option && !command && !control
    }
}
