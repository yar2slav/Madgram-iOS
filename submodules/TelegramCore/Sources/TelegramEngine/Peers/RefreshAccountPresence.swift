import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

// The generic peer-ingestion paths (updatePeers/updatePeerPresencesClean) intentionally strip the
// account peer's presence, and Account init pins it to a sentinel "online forever" value. This
// fetch bypasses those filters so the UI can show the account's real server-side last-seen
// (e.g. to verify what other users see while ghost mode suppresses going online).
func _internal_refreshAccountPresence(account: Account) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.users.getUsers(id: [.inputUserSelf]))
    |> `catch` { _ -> Signal<[Api.User], NoError> in
        return .single([])
    }
    |> mapToSignal { users -> Signal<Never, NoError> in
        guard let user = users.first, let presence = TelegramUserPresence(apiUser: user) else {
            return .complete()
        }
        return account.postbox.transaction { transaction -> Void in
            transaction.updatePeerPresencesInternal(presences: [account.peerId: presence], merge: { _, updated in return updated })
        }
        |> ignoreValues
    }
}
