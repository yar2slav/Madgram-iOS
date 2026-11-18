import Foundation
import UIKit
import Display

/// Madgram: the colours of the app theme's flat navigation bar (`PresentationTheme.rootController.navigationBar`).
///
/// `NavigationBarTheme` lost the bar's background, separator and blur when every bar became glass, and its button
/// colour is now the glass icon tint. The classic bar takes them from here instead: the app hands over each theme it
/// switches to (`ClassicNavigationBarPaletteSource.update`), and a bar uses the palette whose theme its
/// `NavigationBarTheme` was built from (`NavigationBarTheme(rootControllerTheme:)`). A screen with colours of its own
/// (the media gallery, a mini app's header, the profile over a cover) matches no palette and keeps its own colours.
public struct ClassicNavigationBarPalette: Equatable {
    /// Identify the theme a `NavigationBarTheme` was built from: `NavigationBarTheme(rootControllerTheme:)` copies them.
    public var overallDarkAppearance: Bool
    public var primaryTextColor: UIColor
    /// `theme.chat.inputPanel.panelControlColor`, what `NavigationBarTheme(rootControllerTheme:)` uses as its button colour.
    public var glassButtonColor: UIColor

    public var buttonColor: UIColor
    public var disabledButtonColor: UIColor
    public var backgroundColor: UIColor
    public var separatorColor: UIColor
    public var badgeBackgroundColor: UIColor
    public var badgeTextColor: UIColor

    public init(overallDarkAppearance: Bool, primaryTextColor: UIColor, glassButtonColor: UIColor, buttonColor: UIColor, disabledButtonColor: UIColor, backgroundColor: UIColor, separatorColor: UIColor, badgeBackgroundColor: UIColor, badgeTextColor: UIColor) {
        self.overallDarkAppearance = overallDarkAppearance
        self.primaryTextColor = primaryTextColor
        self.glassButtonColor = glassButtonColor
        self.buttonColor = buttonColor
        self.disabledButtonColor = disabledButtonColor
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeTextColor = badgeTextColor
    }

    func matches(_ theme: NavigationBarTheme) -> Bool {
        if ClassicNavigationBarPalette.isScreenOwnTheme(theme) {
            return false
        }
        return self.overallDarkAppearance == theme.overallDarkAppearance && self.primaryTextColor.argb == theme.primaryTextColor.argb && self.glassButtonColor.argb == theme.buttonColor.argb
    }

    /// A theme a screen built with colours of its own that would otherwise pass for an app theme: the media gallery's
    /// (`GalleryController.darkNavigationTheme`: white buttons and text, no badge) matches a dark app theme whose glass
    /// icon colour is white too, and would then be drawn with that theme's opaque background. Themes built by
    /// `NavigationBarTheme(rootControllerTheme:)` always have `disabledButtonColor == buttonColor * 0.5`, so a
    /// `hideBadge` app theme with white glass icons still matches.
    private static func isScreenOwnTheme(_ theme: NavigationBarTheme) -> Bool {
        let hasClearBadge = theme.badgeBackgroundColor.argb == UIColor.clear.argb
        let hasWhiteButtons = theme.buttonColor.argb == UIColor.white.argb
        let isBuiltFromAppTheme = theme.disabledButtonColor.argb == theme.buttonColor.withMultipliedAlpha(0.5).argb
        return hasClearBadge && hasWhiteButtons && !isBuiltFromAppTheme
    }

    public static func ==(lhs: ClassicNavigationBarPalette, rhs: ClassicNavigationBarPalette) -> Bool {
        if lhs.overallDarkAppearance != rhs.overallDarkAppearance {
            return false
        }
        let lhsColors: [UIColor] = [lhs.primaryTextColor, lhs.glassButtonColor, lhs.buttonColor, lhs.disabledButtonColor, lhs.backgroundColor, lhs.separatorColor, lhs.badgeBackgroundColor, lhs.badgeTextColor]
        let rhsColors: [UIColor] = [rhs.primaryTextColor, rhs.glassButtonColor, rhs.buttonColor, rhs.disabledButtonColor, rhs.backgroundColor, rhs.separatorColor, rhs.badgeBackgroundColor, rhs.badgeTextColor]
        return lhsColors.map(\.argb) == rhsColors.map(\.argb)
    }
}

/// The app's recent theme palettes. The app updates it on the main queue whenever its presentation data changes; the
/// bars re-resolve their colours then, since a screen may hear of a theme change before this source does.
public final class ClassicNavigationBarPaletteSource {
    public static let shared = ClassicNavigationBarPaletteSource()

    /// A bar can be created off the main queue (with its screen), so the palettes and the bars are read under a lock.
    private let lock = NSLock()
    /// Most recent first: a screen keeps the previous theme until it hears of the change.
    private var palettes: [ClassicNavigationBarPalette] = []
    private let bars = NSHashTable<ClassicNavigationBarImpl>.weakObjects()

    private init() {
    }

    public func update(palette: ClassicNavigationBarPalette) {
        assert(Thread.isMainThread)
        self.lock.lock()
        if self.palettes.first == palette {
            self.lock.unlock()
            return
        }
        self.palettes.removeAll(where: { $0 == palette })
        self.palettes.insert(palette, at: 0)
        if self.palettes.count > 4 {
            self.palettes.removeLast(self.palettes.count - 4)
        }
        let bars = self.bars.allObjects
        self.lock.unlock()

        for bar in bars {
            bar.paletteSourceUpdated()
        }
    }

    func palette(matching theme: NavigationBarTheme) -> ClassicNavigationBarPalette? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        for palette in self.palettes {
            if palette.matches(theme) {
                return palette
            }
        }
        return nil
    }

    func register(_ bar: ClassicNavigationBarImpl) {
        self.lock.lock()
        self.bars.add(bar)
        self.lock.unlock()
    }
}

/// What a classic bar draws, resolved from its `NavigationBarTheme` and the app's palettes.
struct ClassicNavigationBarColors: Equatable {
    var buttonColor: UIColor
    var disabledButtonColor: UIColor
    var primaryTextColor: UIColor
    /// Nil: no background and no separator (a screen whose content shows through the bar).
    var backgroundColor: UIColor?
    var separatorColor: UIColor
    /// Whether the background blurs what is under it. The flat bar blurred every translucent background except the
    /// media gallery's (12.0 `GalleryController.darkNavigationTheme`: `enableBackgroundBlur: false`).
    var enableBlur: Bool
    var badgeBackgroundColor: UIColor
    var badgeTextColor: UIColor

    init(theme: NavigationBarTheme, palette: ClassicNavigationBarPalette?) {
        // A clear edge effect is today's spelling of the old `hideBackground: true`
        // (`NavigationBarPresentationData(presentationData:hideBackground:hideBadge:)`).
        var hidesBackground = false
        if let edgeEffectColor = theme.edgeEffectColor, edgeEffectColor.alpha == 0.0 {
            hidesBackground = true
        }
        let hidesBadge = theme.badgeBackgroundColor.alpha == 0.0

        self.primaryTextColor = theme.primaryTextColor
        if let palette {
            self.buttonColor = palette.buttonColor
            self.disabledButtonColor = palette.disabledButtonColor
            self.backgroundColor = hidesBackground ? nil : palette.backgroundColor
            self.separatorColor = hidesBackground ? .clear : palette.separatorColor
            self.enableBlur = !hidesBackground && palette.backgroundColor.alpha < 1.0
            self.badgeBackgroundColor = hidesBadge ? .clear : palette.badgeBackgroundColor
            self.badgeTextColor = hidesBadge ? .clear : palette.badgeTextColor
        } else {
            // Colours of the screen's own (or no palette yet, as in an app extension): its buttons keep their colour,
            // and the background is the one its edge effect fades to. A theme built by
            // `NavigationBarTheme(rootControllerTheme:)` from a theme the app did not hand over (a chat's own theme,
            // or before the first palette arrives) has the glass icon grey as its button colour, which the flat bar
            // never used: it draws in that theme's accent instead (`list.itemCheckColors.fillColor`).
            if theme.disabledButtonColor.argb == theme.buttonColor.withMultipliedAlpha(0.5).argb {
                self.buttonColor = theme.accentButtonColor
                self.disabledButtonColor = theme.accentButtonColor.withMultipliedAlpha(0.5)
            } else {
                self.buttonColor = theme.buttonColor
                self.disabledButtonColor = theme.disabledButtonColor
            }
            if hidesBackground {
                self.backgroundColor = nil
                self.separatorColor = .clear
                self.enableBlur = false
            } else if let edgeEffectColor = theme.edgeEffectColor, theme.overallDarkAppearance, edgeEffectColor.alpha < 1.0, edgeEffectColor.argb & 0x00ffffff == 0 {
                // A dark screen over its own content, fading to translucent black: the media gallery
                // (`GalleryController.darkNavigationTheme`). 12.0 drew it unblurred, with a darker hairline.
                self.backgroundColor = edgeEffectColor
                self.separatorColor = UIColor(white: 0.0, alpha: 0.8)
                self.enableBlur = false
            } else {
                let backgroundColor = theme.edgeEffectColor ?? (theme.overallDarkAppearance ? UIColor(rgb: 0x1c1c1d) : UIColor(rgb: 0xf7f7f7))
                let resolvedBackgroundColor = backgroundColor.alpha < 1.0 ? backgroundColor : backgroundColor.withAlphaComponent(0.94)
                self.backgroundColor = resolvedBackgroundColor
                self.separatorColor = theme.overallDarkAppearance ? UIColor(white: 1.0, alpha: 0.12) : UIColor(rgb: 0xc8c7cc)
                self.enableBlur = resolvedBackgroundColor.alpha < 1.0
            }
            self.badgeBackgroundColor = theme.badgeBackgroundColor
            self.badgeTextColor = theme.badgeTextColor
        }
    }

    static func ==(lhs: ClassicNavigationBarColors, rhs: ClassicNavigationBarColors) -> Bool {
        if (lhs.backgroundColor == nil) != (rhs.backgroundColor == nil) {
            return false
        }
        if let lhsBackground = lhs.backgroundColor, let rhsBackground = rhs.backgroundColor, lhsBackground.argb != rhsBackground.argb {
            return false
        }
        if lhs.enableBlur != rhs.enableBlur {
            return false
        }
        let lhsColors: [UIColor] = [lhs.buttonColor, lhs.disabledButtonColor, lhs.primaryTextColor, lhs.separatorColor, lhs.badgeBackgroundColor, lhs.badgeTextColor]
        let rhsColors: [UIColor] = [rhs.buttonColor, rhs.disabledButtonColor, rhs.primaryTextColor, rhs.separatorColor, rhs.badgeBackgroundColor, rhs.badgeTextColor]
        return lhsColors.map(\.argb) == rhsColors.map(\.argb)
    }
}
