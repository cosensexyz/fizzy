import AppKit

public enum ToastDirection: Equatable {
    case above, below, left, right
}

public final class ToastManager {
    private var activeToasts: [(id: UUID, panel: ToastPanel)] = []

    public init() {}

    public func show(item: NotificationItem, relativeTo petWindow: NSWindow, onClick: ((NotificationItem) -> Void)? = nil) {
        let panel = ToastPanel(item: item)
        panel.onClick = { [weak self] in
            self?.dismiss(id: item.id)
            onClick?(item)
        }

        let petFrame = petWindow.frame
        let screenFrame = petWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let direction = Self.bestDirection(petFrame: petFrame, screenFrame: screenFrame)
        let index = activeToasts.count
        let origin = Self.toastOrigin(
            petFrame: petFrame, screenFrame: screenFrame,
            toastSize: panel.frame.size, index: index, direction: direction
        )

        panel.setFrameOrigin(origin)
        panel.alphaValue = 1.0
        panel.orderFront(nil)

        let entry = (id: item.id, panel: panel)
        activeToasts.append(entry)

        scheduleFade(id: item.id, panel: panel, delay: 4.0)
    }

    private func dismiss(id: UUID) {
        guard let index = activeToasts.firstIndex(where: { $0.id == id }) else { return }
        let panel = activeToasts[index].panel
        activeToasts.remove(at: index)
        panel.orderOut(nil)
    }

    private func scheduleFade(id: UUID, panel: ToastPanel, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 1.0
                panel.animator().alphaValue = 0.0
            }) {
                panel.orderOut(nil)
                self?.activeToasts.removeAll { $0.id == id }
            }
        }
    }

    public static func bestDirection(petFrame: NSRect, screenFrame: NSRect) -> ToastDirection {
        let above = screenFrame.maxY - petFrame.maxY
        let below = petFrame.minY - screenFrame.minY
        let left = petFrame.minX - screenFrame.minX
        let right = screenFrame.maxX - petFrame.maxX

        // Prefer vertical placement (below > above); fall back to horizontal (left > right)
        let minToastHeight: CGFloat = 60
        if below >= minToastHeight || above >= minToastHeight {
            return below >= above ? .below : .above
        }
        return left >= right ? .left : .right
    }

    public static func toastOrigin(
        petFrame: NSRect, screenFrame: NSRect,
        toastSize: NSSize, index: Int, direction: ToastDirection
    ) -> NSPoint {
        let gap: CGFloat = 8
        let isHorizontal = direction == .left || direction == .right
        let stride = isHorizontal ? toastSize.width : toastSize.height
        let stackOffset = CGFloat(index) * (stride + gap)

        switch direction {
        case .below:
            let x = petFrame.midX - toastSize.width / 2
            let y = petFrame.minY - toastSize.height - gap - stackOffset
            return clamp(NSPoint(x: x, y: y), size: toastSize, within: screenFrame)
        case .above:
            let x = petFrame.midX - toastSize.width / 2
            let y = petFrame.maxY + gap + stackOffset
            return clamp(NSPoint(x: x, y: y), size: toastSize, within: screenFrame)
        case .left:
            let x = petFrame.minX - toastSize.width - gap - stackOffset
            let y = petFrame.midY - toastSize.height / 2
            return clamp(NSPoint(x: x, y: y), size: toastSize, within: screenFrame)
        case .right:
            let x = petFrame.maxX + gap + stackOffset
            let y = petFrame.midY - toastSize.height / 2
            return clamp(NSPoint(x: x, y: y), size: toastSize, within: screenFrame)
        }
    }

    private static func clamp(_ origin: NSPoint, size: NSSize, within screen: NSRect) -> NSPoint {
        var p = origin
        p.x = Swift.max(screen.minX, Swift.min(p.x, screen.maxX - size.width))
        p.y = Swift.max(screen.minY, Swift.min(p.y, screen.maxY - size.height))
        return p
    }
}
