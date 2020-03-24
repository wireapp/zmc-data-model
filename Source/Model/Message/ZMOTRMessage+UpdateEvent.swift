//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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

private let zmLog = ZMSLog(tag: "event-processing")

extension ZMOTRMessage {

    static func createOrUpdateMessage(fromUpdateEvent updateEvent: ZMUpdateEvent,
                                       inManagedObjectContext moc: NSManagedObjectContext,
                                       prefetchResult: ZMFetchRequestBatchResult) -> ZMOTRMessage? {
        let selfUser = ZMUser.selfUser(in: moc)

        guard
            let senderID = updateEvent.senderUUID(),
            let conversation = self.conversation(for: updateEvent, in: moc, prefetchResult: prefetchResult) else {
            return nil
        }

        if conversation.isSelfConversation && senderID != selfUser.remoteIdentifier  {
            return nil // don't process messages in the self conversation not sent from the self user
        }
        
        guard let message = ZMGenericMessage(from: updateEvent) else {
            appendInvalidSystemMessage(forUpdateEvent: updateEvent, toConversation: conversation, inContext: moc)
            return nil
        }
        zmLog.debug("processing:\n\(message.debugDescription)")
        
        // Update the legal hold state in the conversation
        conversation.updateSecurityLevelIfNeededAfterReceiving(message: message, timestamp: updateEvent.timeStamp() ?? Date())
        
        if !message.knownMessage() {
            UnknownMessageAnalyticsTracker.tagUnknownMessage(with: moc.analytics)
        }
        
        // Verify sender is part of conversation
        conversation.verifySender(of: updateEvent, moc: moc)
        
        // Insert the message
        if message.hasLastRead() && conversation.isSelfConversation {
            ZMConversation.updateConversationWithZMLastRead(fromSelfConversation: message.lastRead, in: moc)
        } else if message.hasCleared() && conversation.isSelfConversation {
            ZMConversation.updateConversationWithZMCleared(fromSelfConversation: message.cleared, in: moc)
        } else if message.hasHidden() && conversation.isSelfConversation {
            ZMMessage.removeMessage(withRemotelyHiddenMessage: message.hidden, in: moc)
        } else if message.hasDeleted() {
            ZMMessage.removeMessage(withRemotelyDeletedMessage: message.deleted, in: conversation, senderID: senderID, in: moc)
        } else if message.hasReaction() {
            // if we don't understand the reaction received, discard it
            guard Reaction.validate(unicode: message.reaction.emoji) else {
                return nil
            }
            ZMMessage.add(message.reaction, senderID: senderID, conversation: conversation, in: moc)
        } else if message.hasConfirmation() {
            ZMMessageConfirmation.createMessageConfirmations(message.confirmation, conversation: conversation, updateEvent: updateEvent)
        } else if message.hasEdited() {
            return ZMClientMessage.editMessage(withEdit: message.edited, forConversation: conversation, updateEvent: updateEvent, inContext: moc, prefetchResult: prefetchResult)
        } else if conversation.shouldAdd(event: updateEvent) && !(message.hasClientAction() || message.hasCalling() || message.hasAvailability()) {
            
        }
        return nil
    }
    
    private static func appendInvalidSystemMessage(forUpdateEvent event: ZMUpdateEvent, toConversation conversation: ZMConversation, inContext moc: NSManagedObjectContext) {
        guard let remoteId = event.senderUUID(),
            let sender = ZMUser(remoteID: remoteId, createIfNeeded: false, in: moc) else {
                return
        }
        conversation.appendInvalidSystemMessage(at: event.timeStamp() ?? Date(), sender: sender)
    }
}
