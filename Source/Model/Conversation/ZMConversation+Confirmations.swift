//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

extension ZMConversation {
    
    @NSManaged @objc dynamic public var hasReadReceiptsEnabled: Bool
    
    /// Confirm unread received messages as read.
    ///
    /// - parameter until: unread messages received up until this timestamp will be confirmed as read.
    @discardableResult
    func confirmUnreadMessagesAsRead(until timestamp: Date) -> [ZMClientMessage] {
        
        let unreadMessagesNeedingConfirmation = unreadMessages(until: timestamp).filter({ $0.needsReadConfirmation })
        var confirmationMessages: [ZMClientMessage] = []
        
        for messages in unreadMessagesNeedingConfirmation.partition(by: \.sender).values {
            guard !messages.isEmpty else { continue }
            
            let confirmation = ZMConfirmation.confirm(messages: messages.compactMap(\.nonce), type: .READ)
            
            if let confirmationMessage = append(message: confirmation, hidden: true) {
                confirmationMessages.append(confirmationMessage)
            }
        }
        
        return confirmationMessages
    }
    /*
    @discardableResult
    func confirmMessagesAsDelivered() -> [ZMClientMessage] {
        
        let deliveredMessages = messagesThatNeedDeliveryReceipts()
        var confirmationMessages: [ZMClientMessage] = []
        
        let confirmation = ZMConfirmation.confirm(messages: deliveredMessages.compactMap(\.nonce), type: .DELIVERED)
            
        if let confirmationMessage = append(message: confirmation, hidden: true) {
            confirmationMessages.append(confirmationMessage)
        }
        
        return confirmationMessages
    }*/
    
    
    public static func confirmDeliveredMessages(_ messages: NSMutableSet, in conversations: NSMutableSet, with managedObjectContext: NSManagedObjectContext) {
        
        for conversationID in conversations {
            guard let conversationID = conversationID as? UUID,
                let convo = ZMConversation(remoteID: conversationID, createIfNeeded: false, in: managedObjectContext)
                else { continue }

            convo.appendConfirmationMessage(for: messages, in: managedObjectContext)
        }
    }
    
    func appendConfirmationMessage(for messages: NSMutableSet, in managedObjectContext: NSManagedObjectContext) {
        guard messages.count > 0 else { return }
        
        var deliveredMessages: [ZMMessage] = []
        
        for messageID in messages {
            guard let messageID = messageID as? UUID,
                let message = ZMMessage.fetch(withNonce: messageID, for: self, in: managedObjectContext)
                else { continue }
            deliveredMessages.append(message)
        }
        
        appendClientMessage(with:
            ZMGenericMessage.message(content:
                ZMConfirmation.confirm(messages: deliveredMessages.compactMap(\.nonce), type: .DELIVERED)),
                            expires: false,
                            hidden: true)
    }
    
    /*
    internal func messagesThatNeedDeliveryReceipts(nonces: [Any]) -> [ZMMessage] {
        
        var messages: [ZMMessage] = []
        
        for item in nonces {
            guard let item = item as? UUID else { continue }
            let message = ZMMessage(nonce: item, managedObjectContext: syncMOC)
            
            if message.deliveryState != .delivered && message.deliveryState != .read {
                messages.append(message)
            }
        }
        
        return messages
    }*/
    
    
    @discardableResult @objc
    public func appendMessageReceiptModeChangedMessage(fromUser user: ZMUser, timestamp: Date, enabled: Bool) -> ZMSystemMessage {
        let message = appendSystemMessage(
            type: enabled ? .readReceiptsEnabled : .readReceiptsDisabled,
            sender: user,
            users: [],
            clients: nil,
            timestamp: timestamp
        )
        
        if isArchived && mutedMessageTypes == .none {
            isArchived = false
        }
        
        return message
    }
    
    @discardableResult @objc
    public func appendMessageReceiptModeIsOnMessage(timestamp: Date) -> ZMSystemMessage {
        let message = appendSystemMessage(
            type: .readReceiptsOn,
            sender: creator,
            users: [],
            clients: nil,
            timestamp: timestamp
        )
        
        return message
    }
    
}
