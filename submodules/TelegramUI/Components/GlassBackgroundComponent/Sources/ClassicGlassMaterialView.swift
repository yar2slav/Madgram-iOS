import Foundation
import UIKit
import Display
import ComponentFlow

/// Madgram: the material a glass surface is drawn with under `ClassicDesign.isEnabled`, the way Telegram 12.0
/// drew its bars and panels (`BlurredBackgroundView`): a gaussian blur of the backdrop under a flat fill, with no rim,
/// shadow, highlight, refraction or press effect. Its owner clips it to the glass's shape.
///
/// It lays its two layers out by its own bounds, and lists them in `shapeFollowingViews` so that a keyframed
/// resize (`GlassBackgroundView.animateShape`) can move them along with it.
final class ClassicGlassMaterialView: UIView {
    private static let isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled

    private var effectView: UIVisualEffectView?
    private let colorView: UIView

    private var color: UIColor?

    override init(frame: CGRect) {
        self.colorView = UIView()
        self.colorView.isUserInteractionEnabled = false

        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.layer.cornerCurve = .circular

        self.addSubview(self.colorView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The views laid out to fill this view.
    var shapeFollowingViews: [UIView] {
        var result: [UIView] = []
        if let effectView = self.effectView {
            result.append(effectView)
            result.append(contentsOf: effectView.subviews)
        }
        result.append(self.colorView)
        return result
    }

    func update(size: CGSize, color: UIColor, transition: ComponentTransition) {
        if self.color != color {
            let previousColor = self.color
            self.color = color

            let needsBlur = !ClassicGlassMaterialView.isReduceTransparencyEnabled && color.alpha > .ulpOfOne && color.alpha < 0.95
            let effectiveColor = ClassicGlassMaterialView.isReduceTransparencyEnabled && color.alpha > .ulpOfOne ? color.withAlphaComponent(1.0) : color
            if previousColor == nil {
                self.colorView.backgroundColor = effectiveColor
            } else {
                transition.setBackgroundColor(view: self.colorView, color: effectiveColor)
            }

            if needsBlur {
                if self.effectView == nil {
                    let effectView = ClassicGlassMaterialView.makeBlurView()
                    effectView.frame = CGRect(origin: CGPoint(), size: size)
                    self.effectView = effectView
                    self.insertSubview(effectView, at: 0)
                }
            } else if let effectView = self.effectView {
                self.effectView = nil
                effectView.removeFromSuperview()
            }
        }

        let contentFrame = CGRect(origin: CGPoint(), size: size)
        transition.setFrame(view: self.colorView, frame: contentFrame)
        if let effectView = self.effectView {
            transition.setFrame(view: effectView, frame: contentFrame)
            for subview in effectView.subviews {
                transition.setFrame(view: subview, frame: contentFrame)
            }
        }
    }

    /// The blur 12.0's `BlurredBackgroundView` used: the system light blur with only its saturation and gaussian blur
    /// filters kept, so the fill above it decides the color.
    private static func makeBlurView() -> UIVisualEffectView {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        effectView.isUserInteractionEnabled = false

        for subview in effectView.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }

        if let sublayer = effectView.layer.sublayers?[0], let filters = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false
            let allowedKeys: [String] = [
                "colorSaturate",
                "gaussianBlur"
            ]
            sublayer.filters = filters.filter { filter in
                guard let filter = filter as? NSObject else {
                    return true
                }
                let filterName = String(describing: filter)
                if !allowedKeys.contains(filterName) {
                    return false
                }
                return true
            }
        }

        return effectView
    }
}

extension GlassBackgroundView {
    /// Madgram classic design: the fill of a `.panel` glass, by whether it is dark. The defaults are Telegram 12.0's
    /// day and night `rootController.navigationBar.blurredBackgroundColor`; the app may point this at the current
    /// theme's. Read on every update of a classic glass, so a new value reaches each surface on its next update.
    public static var classicPanelColor: (_ isDark: Bool) -> UIColor = { isDark in
        if isDark {
            return UIColor(rgb: 0x1d1d1d, alpha: 0.9)
        } else {
            return UIColor(rgb: 0xf2f2f2, alpha: 0.9)
        }
    }

    /// The flat fill a classic glass is drawn with (`ClassicGlassMaterialView` blurs below it when it is translucent).
    static func classicMaterialColor(tintColor: TintColor, isDark: Bool) -> UIColor {
        // Clear glass sits over media and wallpapers: 12.0 drew such controls as a dark translucent blur in the dark,
        // and as a bar in the light.
        let clearColor: UIColor = isDark ? UIColor(white: 0.0, alpha: 0.35) : GlassBackgroundView.classicPanelColor(false)
        switch tintColor.kind {
        case .panel, .untinted:
            return GlassBackgroundView.classicPanelColor(isDark)
        case .clear:
            return clearColor
        case let .custom(style, color):
            // A strong color is the surface itself (an accent button); a faint one only tints the glass, so it tints
            // the material that glass stands for.
            if color.alpha >= 0.5 {
                return color
            }
            let base: UIColor
            switch style {
            case .default:
                base = GlassBackgroundView.classicPanelColor(isDark)
            case .clear:
                base = clearColor
            }
            return classicColor(color, over: base)
        }
    }
}

/// `top` composited over `bottom` (source-over).
private func classicColor(_ top: UIColor, over bottom: UIColor) -> UIColor {
    var tr: CGFloat = 0.0, tg: CGFloat = 0.0, tb: CGFloat = 0.0, ta: CGFloat = 0.0
    var br: CGFloat = 0.0, bg: CGFloat = 0.0, bb: CGFloat = 0.0, ba: CGFloat = 0.0
    guard top.getRed(&tr, green: &tg, blue: &tb, alpha: &ta), bottom.getRed(&br, green: &bg, blue: &bb, alpha: &ba) else {
        return bottom
    }
    if ta <= .ulpOfOne {
        return bottom
    }
    let alpha = ta + ba * (1.0 - ta)
    if alpha <= .ulpOfOne {
        return UIColor(white: 0.0, alpha: 0.0)
    }
    func channel(_ t: CGFloat, _ b: CGFloat) -> CGFloat {
        return (t * ta + b * ba * (1.0 - ta)) / alpha
    }
    return UIColor(red: channel(tr, br), green: channel(tg, bg), blue: channel(tb, bb), alpha: alpha)
}
