//
//  ZMOTRMessage+UpdateEvent.swift
//  WireDataModel
//
//  Created by David Henner on 16.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

private let zmLog = ZMSLog(tag: "event-processing")

extension ZMOTRMessage {
    func update(withGenericMessage message: GenericMessage, updateEvent: ZMUpdateEvent, initialUpdate: Bool) {
        
    }
    
    static func createOrUpdateMessage(fromUpdateEvent updateEvent: ZMUpdateEvent,
                               inManagedObjectContext moc: NSManagedObjectContext,
                               prefetchResult: ZMFetchRequestBatchResult) -> ZMOTRMessage? {
        
        guard let conversation = self.conversation(for: updateEvent, in: moc, prefetchResult: prefetchResult) else { return nil }
        let selfUser = ZMUser.selfUser(in: moc)
        
        if conversation.conversationType == .self && updateEvent.senderUUID() != selfUser.remoteIdentifier  {
            return nil // don't process messages in the self conversation not sent from the self user
        }
        
        guard let message = GenericMessage(from: updateEvent), let content = message.content else {
            appendInvalidSystemMessage(forUpdateEvent: updateEvent, toConversation: conversation, inContext: moc)
            return nil
        }
        zmLog.debug("processing:\n\(message.debugDescription)")
        
        // Update the legal hold state in the conversation
        conversation.updateSecurityLevelIfNeededAfterReceiving(message: message, timestamp: updateEvent.timeStamp() ?? Date())
        
        // Verify sender is part of conversation
        conversation.verifySender(of: updateEvent, moc: moc)
        
        // Insert the message
        switch content {
        case .lastRead where conversation.conversationType == .self:
            ZMConversation.updateConversation(withLastRead: message.lastRead, inContext: moc)
        case .cleared where conversation.conversationType == .self:
            
        default:
            
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
