import Foundation
import UIKit
import Display
import TelegramUIPreferences

private func mix(_ lhs: (CGFloat, CGFloat, CGFloat), _ rhs: (CGFloat, CGFloat, CGFloat), _ t: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
    return (lhs.0 + (rhs.0 - lhs.0) * t, lhs.1 + (rhs.1 - lhs.1) * t, lhs.2 + (rhs.2 - lhs.2) * t)
}

private func fraction(_ value: CGFloat) -> CGFloat {
    return value - floor(value)
}

public struct PeerNameStyleAppearance: Equatable {
    public let colors: [UInt32]
    public let effect: PeerNameEffect?

    public init(colors: [UInt32], effect: PeerNameEffect?) {
        self.colors = colors
        self.effect = effect
    }

    public init?(style: PeerNameStyle?) {
        guard let style else {
            return nil
        }
        let colors = style.rgbColors
        if colors.isEmpty {
            return nil
        }
        self.init(colors: colors, effect: style.parsedEffect)
    }

    public var isAnimated: Bool {
        return self.effect != nil
    }

    public var isSolid: Bool {
        return self.effect == nil && self.colors.count == 1
    }

    public var firstColor: UIColor {
        return UIColor(rgb: self.colors[0])
    }

    private var components: [(CGFloat, CGFloat, CGFloat)] {
        return self.colors.map { (CGFloat(($0 >> 16) & 0xff) / 255.0, CGFloat(($0 >> 8) & 0xff) / 255.0, CGFloat($0 & 0xff) / 255.0) }
    }

    public var period: Double {
        switch self.effect {
        case .flow:
            return 2.6
        case .rainbow:
            return 3.2
        case .shimmer, .pulse:
            return 2.4
        case .none:
            return 1.0
        }
    }

    private func along(_ colors: [(CGFloat, CGFloat, CGFloat)], _ x: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        if colors.count == 1 {
            return colors[0]
        }
        let position = max(0.0, min(1.0, x)) * CGFloat(colors.count - 1)
        let index = min(colors.count - 2, Int(floor(position)))
        return mix(colors[index], colors[index + 1], position - CGFloat(index))
    }

    private func loop(_ colors: [(CGFloat, CGFloat, CGFloat)], _ x: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        if colors.count == 1 {
            return colors[0]
        }
        let position = fraction(x) * CGFloat(colors.count)
        let index = Int(floor(position)) % colors.count
        return mix(colors[index], colors[(index + 1) % colors.count], position - floor(position))
    }

    public func color(x: CGFloat, phase: CGFloat) -> UIColor {
        let colors = self.components
        let white: (CGFloat, CGFloat, CGFloat) = (1.0, 1.0, 1.0)
        let result: (CGFloat, CGFloat, CGFloat)
        switch self.effect {
        case .flow:
            result = self.loop(colors, x - phase)
        case .rainbow:
            return UIColor(hue: fraction(x * 0.75 - phase), saturation: 0.72, brightness: 0.96, alpha: 1.0)
        case .shimmer:
            let base = self.along(colors, x)
            let center = -0.35 + 1.7 * phase
            let glow = max(1.0 - abs(x - center) / 0.22, 0.0)
            result = mix(base, white, 0.7 * glow * glow)
        case .pulse:
            if colors.count > 1 {
                result = self.loop(colors, phase + 0.15 * x)
            } else {
                result = mix(colors[0], white, 0.38 * (0.5 - 0.5 * cos(2.0 * .pi * phase)))
            }
        case .none:
            result = self.along(colors, x)
        }
        return UIColor(red: result.0, green: result.1, blue: result.2, alpha: 1.0)
    }

    public func gradientColors(phase: CGFloat, stops: Int = 24) -> [CGColor] {
        return (0 ... stops).map { self.color(x: CGFloat($0) / CGFloat(stops), phase: phase).cgColor }
    }

    public func staticTextColor(width: CGFloat) -> UIColor {
        if self.colors.count == 1 && self.effect != .rainbow && self.effect != .pulse {
            return self.firstColor
        }
        let imageWidth = max(8.0, ceil(width))
        let image = generateImage(CGSize(width: imageWidth, height: 1.0), opaque: true, rotatedContext: { size, context in
            let steps = Int(size.width)
            for step in 0 ..< steps {
                context.setFillColor(self.color(x: CGFloat(step) / max(1.0, size.width - 1.0), phase: 0.0).cgColor)
                context.fill(CGRect(x: CGFloat(step), y: 0.0, width: 1.0, height: size.height))
            }
        })
        guard let image else {
            return self.firstColor
        }
        return UIColor(patternImage: image)
    }

    public static var animationsAllowed: Bool {
        return !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

private final class PeerNameDisplayLinkTarget: NSObject {
    weak var layer: PeerNameEffectLayer?

    init(layer: PeerNameEffectLayer) {
        self.layer = layer
    }

    @objc func tick() {
        self.layer?.tick()
    }
}

public final class PeerNameEffectLayer: CALayer {
    private let gradientLayer = CAGradientLayer()
    private var displayLink: CADisplayLink?
    private var startTime = CACurrentMediaTime()

    public var appearance: PeerNameStyleAppearance? {
        didSet {
            if self.appearance != oldValue {
                self.updateRunning()
                self.render()
            }
        }
    }

    public var isActive: Bool = true {
        didSet {
            if self.isActive != oldValue {
                self.updateRunning()
            }
        }
    }

    override public init() {
        super.init()
        self.gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        self.addSublayer(self.gradientLayer)
    }

    override public init(layer: Any) {
        super.init(layer: layer)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
    }

    override public func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.gradientLayer.frame = self.bounds
        CATransaction.commit()
    }

    private func updateRunning() {
        let shouldRun = self.isActive && (self.appearance?.isAnimated ?? false) && PeerNameStyleAppearance.animationsAllowed
        if shouldRun {
            if self.displayLink == nil {
                let displayLink = CADisplayLink(target: PeerNameDisplayLinkTarget(layer: self), selector: #selector(PeerNameDisplayLinkTarget.tick))
                displayLink.preferredFramesPerSecond = 30
                displayLink.add(to: .main, forMode: .common)
                self.displayLink = displayLink
            }
        } else if let displayLink = self.displayLink {
            self.displayLink = nil
            displayLink.invalidate()
        }
    }

    fileprivate func tick() {
        self.render()
    }

    private func render() {
        guard let appearance = self.appearance else {
            return
        }
        var phase: CGFloat = 0.0
        if self.displayLink != nil {
            let period = appearance.period
            phase = CGFloat((CACurrentMediaTime() - self.startTime).truncatingRemainder(dividingBy: period) / period)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.gradientLayer.colors = appearance.gradientColors(phase: phase)
        CATransaction.commit()
    }
}
