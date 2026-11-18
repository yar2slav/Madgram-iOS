import Foundation
import Postbox
import SwiftSignalKit

public extension TelegramEngine.Messages {
    /// Thin forwarder to `updateGhostModeSettingsInteractively(postbox:_:)` for callers that
    /// do not import Postbox.
    func updateGhostModeSettingsInteractively(_ f: @escaping (GhostModeSettings) -> GhostModeSettings) -> Signal<Never, NoError> {
        return TelegramCore.updateGhostModeSettingsInteractively(postbox: self.account.postbox, f)
    }
}
