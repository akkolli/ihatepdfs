import CoreGraphics

struct ReaderAdaptiveLayout: Equatable {
    enum SizeClass: String, CaseIterable {
        case compact
        case regular
        case wide

        init(width: CGFloat) {
            if width < 960 {
                self = .compact
            } else if width < 1280 {
                self = .regular
            } else {
                self = .wide
            }
        }
    }

    struct SidebarWidths: Equatable {
        var left: CGFloat
        var right: CGFloat
    }

    static let minimumWindowWidth: CGFloat = 820
    static let minimumWindowHeight: CGFloat = 620
    static let resizeHandleWidth: CGFloat = 16

    let sizeClass: SizeClass

    init(width: CGFloat) {
        sizeClass = SizeClass(width: width)
    }

    init(sizeClass: SizeClass) {
        self.sizeClass = sizeClass
    }

    var usesCompactToolbar: Bool {
        sizeClass == .compact
    }

    var allowsDualSidebars: Bool {
        sizeClass != .compact
    }

    var leftSidebarMinWidth: CGFloat {
        switch sizeClass {
        case .compact:
            return 208
        case .regular:
            return 196
        case .wide:
            return 220
        }
    }

    var leftSidebarIdealWidth: CGFloat {
        switch sizeClass {
        case .compact:
            return 236
        case .regular:
            return 215
        case .wide:
            return 248
        }
    }

    var leftSidebarMaxWidth: CGFloat {
        switch sizeClass {
        case .compact:
            return 300
        case .regular:
            return 280
        case .wide:
            return 340
        }
    }

    var rightSidebarMinWidth: CGFloat {
        switch sizeClass {
        case .compact:
            return 280
        case .regular:
            return 280
        case .wide:
            return 300
        }
    }

    var rightSidebarIdealWidth: CGFloat {
        switch sizeClass {
        case .compact:
            return 292
        case .regular:
            return 300
        case .wide:
            return 340
        }
    }

    var rightSidebarMaxWidth: CGFloat {
        switch sizeClass {
        case .compact:
            return 340
        case .regular:
            return 360
        case .wide:
            return 420
        }
    }

    var documentMinWidth: CGFloat {
        switch sizeClass {
        case .compact:
            return 320
        case .regular:
            return 420
        case .wide:
            return 560
        }
    }

    func clampedLeftWidth(_ width: CGFloat) -> CGFloat {
        clamped(width, lower: leftSidebarMinWidth, upper: leftSidebarMaxWidth)
    }

    func clampedRightWidth(_ width: CGFloat) -> CGFloat {
        clamped(width, lower: rightSidebarMinWidth, upper: rightSidebarMaxWidth)
    }

    func resolvedSidebarWidths(
        availableWidth: CGFloat,
        requestedLeft: CGFloat,
        requestedRight: CGFloat,
        showLeft: Bool,
        showRight: Bool
    ) -> SidebarWidths {
        let leftHandle = showLeft ? Self.resizeHandleWidth : 0
        let rightHandle = showRight ? Self.resizeHandleWidth : 0
        let maxSidebarTotal = max(0, availableWidth - documentMinWidth - leftHandle - rightHandle)

        var left = showLeft ? clampedLeftWidth(requestedLeft) : 0
        var right = showRight ? clampedRightWidth(requestedRight) : 0

        guard left + right > maxSidebarTotal else {
            return SidebarWidths(left: left, right: right)
        }

        var overflow = left + right - maxSidebarTotal
        if showRight {
            let reduction = min(overflow, max(0, right - rightSidebarMinWidth))
            right -= reduction
            overflow -= reduction
        }

        if showLeft, overflow > 0 {
            let reduction = min(overflow, max(0, left - leftSidebarMinWidth))
            left -= reduction
        }

        return SidebarWidths(left: left, right: right)
    }

    func visibleContentWidth(
        availableWidth: CGFloat,
        leftWidth: CGFloat,
        rightWidth: CGFloat,
        showLeft: Bool,
        showRight: Bool
    ) -> CGFloat {
        let leftHandle = showLeft ? Self.resizeHandleWidth : 0
        let rightHandle = showRight ? Self.resizeHandleWidth : 0
        return availableWidth - leftWidth - rightWidth - leftHandle - rightHandle
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
