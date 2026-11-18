import Foundation

/// Madgram: the "Классический дизайн" switch, the pre-Liquid-Glass look of Telegram 12.0.
///
/// Set once at launch, before any UI is built, from `InterfaceTuningSettings.classicDesign`
/// (TelegramUIPreferences, which low-level UI modules cannot import). Components capture their
/// style when they are created, so a change takes effect after a restart.
public enum ClassicDesign {
    public static var isEnabled: Bool = false
}
