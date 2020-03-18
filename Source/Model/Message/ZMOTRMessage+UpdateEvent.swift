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
        var message = GenericMessage(from: updateEvent)
        zmLog.debug("processing:\n\(message?.debugDescription)")
        
        guard let conversation = self.conversation(for: updateEvent, in: moc, prefetchResult: prefetchResult) else { return nil }
        let selfUser = ZMUser.selfUser(in: moc)
        
        if conversation.conversationType == .self && updateEvent.senderUUID() != selfUser.remoteIdentifier  {
            return nil // don't process messages in the self conversation not sent from the self user
        }
        
        // Update the legal hold state in the conversation
        conversation.updateSecurityLevelIfNeededAfterReceiving(message: <#T##ZMGenericMessage#>, timestamp: updateEvent.timeStamp() ?? Date())
        
        return nil
    }
}
