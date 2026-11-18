import Foundation
import Postbox
import SwiftSignalKit

public extension TelegramEngine.Messages {
    /// Thin forwarder to `updateDeletedMessageArchiveSettingsInteractively(postbox:_:)` for callers
    /// that do not import Postbox.
    func updateDeletedMessageArchiveSettingsInteractively(_ f: @escaping (DeletedMessageArchiveSettings) -> DeletedMessageArchiveSettings) -> Signal<Never, NoError> {
        return TelegramCore.updateDeletedMessageArchiveSettingsInteractively(postbox: self.account.postbox, f)
    }
}
