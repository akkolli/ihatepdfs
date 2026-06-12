enum ReviewState {
    static let allStatuses = "All Statuses"
    static let reviewed = "Reviewed"
    static let notReviewed = "Not reviewed"

    static func isReviewed(_ status: String) -> Bool {
        status.localizedCaseInsensitiveCompare("Marked") == .orderedSame
            || status.localizedCaseInsensitiveCompare(reviewed) == .orderedSame
    }

    static func label(for status: String) -> String {
        if isReviewed(status) { return reviewed }
        return status.localizedCaseInsensitiveCompare("Unmarked") == .orderedSame
            ? notReviewed
            : status
    }

    static func matches(_ status: String, filter: String) -> Bool {
        switch filter {
        case allStatuses:
            return true
        case reviewed:
            return isReviewed(status)
        case notReviewed:
            return !isReviewed(status)
        default:
            return status == filter || label(for: status) == filter
        }
    }
}
