import AppKit

struct BubbleSlot {
    let radius: CGFloat
    let strokeWidth: CGFloat
    let opacityMin: CGFloat
    let opacityMax: CGFloat
    let floatAmplitude: CGFloat
    let floatPeriod: CGFloat
    let floatDelay: CGFloat
}

public enum FizzyState: Equatable {
    case idle
    case active(unreadCount: Int)
}

public final class FizzyView: NSView {
    public var state: FizzyState = .idle {
        didSet { stateDidChange() }
    }

    // Intrinsic properties per slot (0=largest → 3=smallest)
    static let bubbleSlots: [BubbleSlot] = [
        BubbleSlot(radius: 8.5, strokeWidth: 1.0,
                   opacityMin: 0.35, opacityMax: 0.50,
                   floatAmplitude: 1.5, floatPeriod: 5.0, floatDelay: 0),
        BubbleSlot(radius: 5.3, strokeWidth: 0.9,
                   opacityMin: 0.21, opacityMax: 0.32,
                   floatAmplitude: 2.25, floatPeriod: 6.0, floatDelay: 0.6),
        BubbleSlot(radius: 3.5, strokeWidth: 0.8,
                   opacityMin: 0.13, opacityMax: 0.21,
                   floatAmplitude: 1.25, floatPeriod: 4.5, floatDelay: 1.2),
        BubbleSlot(radius: 2.1, strokeWidth: 0.7,
                   opacityMin: 0.06, opacityMax: 0.11,
                   floatAmplitude: 1.75, floatPeriod: 5.5, floatDelay: 1.8),
    ]

    // Balanced position layouts indexed by visible count
    private static let layouts: [[(cx: CGFloat, cy: CGFloat)]] = [
        [],
        [(40, 22)],
        [(50, 22), (30, 16)],
        [(50, 24), (28, 16), (42, 8)],
        [(52, 24), (29, 17), (42, 8), (60, 5)],
    ]

    var revealedSlots: [Int] = []
    private var animationTimer: Timer?
    private var lastTickTime: CFTimeInterval = 0
    private var elapsedTime: CGFloat = 0

    public override var isFlipped: Bool { false }
    public override var isOpaque: Bool { false }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { startAnimation() }
    }

    private func stateDidChange() {
        let target: Int
        switch state {
        case .idle: target = 0
        case .active(let n): target = min(max(n - 1, 0), Self.bubbleSlots.count)
        }

        while revealedSlots.count < target {
            guard revealedSlots.count < Self.bubbleSlots.count else { break }
            revealedSlots.append(revealedSlots.count)
        }
        while revealedSlots.count > target {
            revealedSlots.removeLast()
        }

        needsDisplay = true
    }

    private func startAnimation() {
        guard animationTimer == nil else { return }
        lastTickTime = CACurrentMediaTime()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) {
            [weak self] _ in self?.tick()
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        elapsedTime += CGFloat(now - lastTickTime)
        lastTickTime = now
        needsDisplay = true
    }

    private func sinePhase(_ period: CGFloat, _ delay: CGFloat) -> CGFloat {
        (sin(2 * .pi * (elapsedTime + delay) / period) + 1) / 2
    }

    public var bubbleColor: NSColor = NSColor(colorSpace: .sRGB, components: [1, 1, 1, 1], count: 4)

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds

        ctx.saveGState()
        ctx.setBlendMode(.copy)
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.005))
        ctx.fill(bounds)
        ctx.restoreGState()

        let cx = bounds.midX
        let cy: CGFloat = 60
        let mainRadius: CGFloat = 24

        // Main bubble — breathes and floats when active
        let isActive = state != .idle
        let mainOpacity: CGFloat = isActive ? 0.70 + 0.25 * sinePhase(3.0, 0) : 0.80
        let mainFloat: CGFloat = isActive ? (sinePhase(3.0, 0) - 0.5) * 2 * 2.5 : 0
        let mainCy = cy + mainFloat
        let mainRect = NSRect(
            x: cx - mainRadius, y: mainCy - mainRadius,
            width: mainRadius * 2, height: mainRadius * 2
        )
        let mainPath = NSBezierPath(ovalIn: mainRect)
        NSColor.black.withAlphaComponent(mainOpacity * 0.35).setStroke()
        mainPath.lineWidth = 1.7
        mainPath.stroke()
        bubbleColor.withAlphaComponent(mainOpacity).setStroke()
        mainPath.lineWidth = 1.2
        mainPath.stroke()

        // Arc highlight with shimmer — follows main bubble float
        let shimmer = 0.3 + 0.4 * sinePhase(4.0, 0)
        let highlightPath = NSBezierPath()
        highlightPath.move(to: NSPoint(x: 27.2, y: 72.0 + mainFloat))
        highlightPath.curve(
            to: NSPoint(x: 35.2, y: 77.9 + mainFloat),
            controlPoint1: NSPoint(x: 29.2, y: 74.7 + mainFloat),
            controlPoint2: NSPoint(x: 32.0, y: 76.8 + mainFloat)
        )
        NSColor.black.withAlphaComponent(shimmer * 0.35).setStroke()
        highlightPath.lineWidth = 1.7
        highlightPath.lineCapStyle = .round
        highlightPath.stroke()
        bubbleColor.withAlphaComponent(shimmer).setStroke()
        highlightPath.lineWidth = 1.2
        highlightPath.lineCapStyle = .round
        highlightPath.stroke()

        // Revealed bubble slots with dynamic positions
        let count = revealedSlots.count
        guard count > 0 else { return }
        let positions = Self.layouts[count]

        for (i, slotIndex) in revealedSlots.enumerated() {
            let slot = Self.bubbleSlots[slotIndex]
            let pos = positions[i]

            let phase = sinePhase(slot.floatPeriod, slot.floatDelay)
            let yOffset = (phase - 0.5) * 2 * slot.floatAmplitude
            let opacity = slot.opacityMin + (slot.opacityMax - slot.opacityMin) * phase

            let r = slot.radius
            let bubbleRect = NSRect(
                x: pos.cx - r, y: pos.cy + yOffset - r,
                width: r * 2, height: r * 2
            )
            let bubblePath = NSBezierPath(ovalIn: bubbleRect)
            NSColor.black.withAlphaComponent(opacity * 0.35).setStroke()
            bubblePath.lineWidth = slot.strokeWidth + 0.5
            bubblePath.stroke()
            bubbleColor.withAlphaComponent(opacity).setStroke()
            bubblePath.lineWidth = slot.strokeWidth
            bubblePath.stroke()
        }
    }
}
