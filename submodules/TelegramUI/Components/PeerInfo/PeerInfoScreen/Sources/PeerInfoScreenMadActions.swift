import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import UndoUI
import PromptUI
import MadLockUI

extension PeerInfoScreenNode {
    func madToast(_ text: String) {
        guard let controller = self.controller else {
            return
        }
        controller.present(UndoOverlayController(presentationData: self.presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
    }

    func madOpenLocalName() {
        guard let controller = self.controller, let peer = self.data?.peer else {
            return
        }
        let more = self.presentationData.strings.localFeatures.more
        let peerId = peer.id.toInt64()
        let current = MadStores.peerAliases.current[peerId]
        let prompt = promptController(context: self.context, text: more.localName, titleFont: .bold, subtitle: more.localNameInfo, value: current ?? "", placeholder: more.localNamePlaceholder, characterLimit: 64, apply: { value in
            guard let value else {
                return
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            MadStores.peerAliases.update { aliases in
                var aliases = aliases
                if trimmed.isEmpty {
                    aliases.removeValue(forKey: peerId)
                } else {
                    aliases[peerId] = trimmed
                }
                return aliases
            }
        })
        controller.present(prompt, in: .window(.root))
    }

    func madToggleChatLock() {
        guard let peer = self.data?.peer else {
            return
        }
        let strings = self.presentationData.strings
        let more = strings.localFeatures.more
        let peerId = peer.id.toInt64()
        if MadStores.lockedChats.current.contains(peerId) {
            MadLock.requireUnlock(strings: strings, completion: { [weak self] success in
                guard success else {
                    return
                }
                MadStores.lockedChats.update { value in
                    var value = value
                    value.remove(peerId)
                    return value
                }
                self?.madToast(more.unlockChat)
            })
            return
        }
        let lock = { [weak self] in
            MadStores.lockedChats.update { value in
                var value = value
                value.insert(peerId)
                return value
            }
            MadChatLockSession.shared.markUnlocked(peerId: peerId)
            self?.madToast(more.lockChat)
        }
        if MadLock.hasPassword {
            lock()
        } else {
            MadLock.presentSetup(strings: strings, completion: { success in
                if success {
                    lock()
                }
            })
        }
    }

    func madTogglePresenceWatch() {
        guard let peer = self.data?.peer else {
            return
        }
        let more = self.presentationData.strings.localFeatures.more
        let peerId = peer.id.toInt64()
        var isOn = false
        MadStores.presenceWatched.update { value in
            var value = value
            if value.contains(peerId) {
                value.remove(peerId)
            } else {
                value.insert(peerId)
                isOn = true
            }
            return value
        }
        self.madToast(isOn ? more.notifyPresenceOn : more.notifyPresenceOff)
    }
}
