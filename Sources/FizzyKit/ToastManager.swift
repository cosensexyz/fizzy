import AppKit

public enum ToastDirection: Equatable {
    case above, below, left, right
}

public final class ToastManager {
    private var activeToasts: [(id: UUID, panel: ToastPanel)] = []
    private var fadeTimers: [UUID: Timer] = [:]

    public init() {}

    public func show(item: NotificationItem, relativeTo petWindow: NSWindow, onClick: ((NotificationItem) -> Void)? = nil) {
        let panel = ToastPanel(item: item)
        panel.onClick = { [weak self] in
            TerminalActivator.clearPreviewState()
            self?.dismiss(id: item.id)
            onClick?(item)
        }
        panel.onHoverEnter = { [weak self] in
            if TerminalActivator.enterPreview(for: item) {
                self?.cancelFade(id: item.id)
                panel.alphaValue = 1.0
            }
        }
        panel.onHoverExit = { [weak self] in
            if TerminalActivator.inPreview {
                TerminalActivator.exitPreview()
                self?.scheduleFade(id: item.id, panel: panel, delay: 4.0)
            }
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

        activeToasts.append((id: item.id, panel: panel))
        scheduleFade(id: item.id, panel: panel, delay: 4.0)
    }

    private func dismiss(id: UUID) {
        cancelFade(id: id)
        guard let index = activeToasts.firstIndex(where: { $0.id == id }) else { return }
        let panel = activeToasts[index].panel
        activeToasts.remove(at: index)
        panel.orderOut(nil)
    }

    private func scheduleFade(id: UUID, panel: ToastPanel, delay: TimeInterval) {
        cancelFade(id: id)
        fadeTimers[id] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.fadeTimers.removeValue(forKey: id)
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 1.0
                panel.animator().alphaValue = 0.0
            }) {
                panel.orderOut(nil)
                self?.activeToasts.removeAll { $0.id == id }
            }
        }
    }

    private func cancelFade(id: UUID) {
        fadeTimers[id]?.invalidate()
        fadeTimers.removeValue(forKey: id)
    }

    // MARK: - Test helpers

    func scheduleFadeForTest(id: UUID, delay: TimeInterval) {
        let panel = ToastPanel(item: NotificationItem(
            notification: GenericPayload(message: "", cwd: "/tmp")
        ))
        scheduleFade(id: id, panel: panel, delay: delay)
    }

    func hasPendingFade(for id: UUID) -> Bool {
        fadeTimers[id] != nil
    }

    func cancelFadeForTest(id: UUID) {
        cancelFade(id: id)
    }

    // MARK: - Positioning (unchanged)

    public static func bestDirection(petFrame: NSRect, screenFrame: NSRect) -> ToastDirection {
        let above = screenFrame.maxY - petFrame.maxY
        let below = petFrame.minY - screenFrame.minY
        let left = petFrame.minX - screenFrame.minX
        let right = screenFrame.maxX - petFrame.maxX

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
