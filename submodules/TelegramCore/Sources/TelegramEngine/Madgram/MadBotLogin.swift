import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
internal import TelegramApi

public enum MadBotLoginError {
    case invalidToken
    case limitExceeded
    case generic
}

public func madAuthorizeWithBotToken(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, apiId: Int32, apiHash: String, token: String) -> Signal<Void, MadBotLoginError> {
    let request = Api.functions.auth.importBotAuthorization(flags: 0, apiId: apiId, apiHash: apiHash, botAuthToken: token)
    let authorization: Signal<(Api.auth.Authorization, UnauthorizedAccount), MadBotLoginError> = account.network.request(request, automaticFloodWait: false)
    |> map { result in
        return (result, account)
    }
    |> `catch` { error -> Signal<(Api.auth.Authorization, UnauthorizedAccount), MadBotLoginError> in
        let description = error.errorDescription ?? ""
        if let range = description.range(of: "MIGRATE_"), let datacenterId = Int32(description[range.upperBound...]) {
            return account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: datacenterId)
            |> castError(MadBotLoginError.self)
            |> mapToSignal { updatedAccount -> Signal<(Api.auth.Authorization, UnauthorizedAccount), MadBotLoginError> in
                return updatedAccount.network.request(request, automaticFloodWait: false)
                |> map { result in
                    return (result, updatedAccount)
                }
                |> mapError { _ -> MadBotLoginError in
                    return .invalidToken
                }
            }
        } else if description.hasPrefix("FLOOD_WAIT") {
            return .fail(.limitExceeded)
        } else if description.contains("TOKEN") {
            return .fail(.invalidToken)
        } else {
            return .fail(.generic)
        }
    }
    return authorization
    |> mapToSignal { result, account -> Signal<Void, MadBotLoginError> in
        return account.postbox.transaction { transaction -> Signal<Void, NoError> in
            switch result {
            case let .authorization(authorizationData):
                let user = TelegramUser(user: authorizationData.user)
                let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil, invalidatedChannels: [])
                initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: false)
                transaction.setState(state)
                return accountManager.transaction { transaction -> Void in
                    switchToAuthorizedAccount(transaction: transaction, account: account, isSupportUser: false)
                }
            case .authorizationSignUpRequired:
                return .complete()
            }
        }
        |> switchToLatest
        |> castError(MadBotLoginError.self)
    }
}
