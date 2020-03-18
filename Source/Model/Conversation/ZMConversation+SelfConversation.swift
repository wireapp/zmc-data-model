//
//  ZMConversation+SelfConversation.swift
//  WireDataModel
//
//  Created by David Henner on 18.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation


//@implementation ZMConversation (SelfConversation)
//
//+ (ZMClientMessage *)appendSelfConversationWithGenericMessage:(ZMGenericMessage * )genericMessage managedObjectContext:(NSManagedObjectContext *)moc;
//{
//    VerifyReturnNil(genericMessage != nil);
//
//    ZMConversation *selfConversation = [ZMConversation selfConversationInContext:moc];
//    VerifyReturnNil(selfConversation != nil);
//
//    ZMClientMessage *clientMessage = [selfConversation appendClientMessageWithGenericMessage:genericMessage expires:NO hidden:NO];
//    return clientMessage;
//    }
//
//
//
//
//    + (ZMClientMessage *)appendSelfConversationWithClearedOfConversation:(ZMConversation *)conversation
//{
//    NSUUID *convID = conversation.remoteIdentifier;
//    NSDate *cleared = conversation.clearedTimeStamp;
//    if (convID == nil || cleared == nil || [convID isEqual:[ZMConversation selfConversationIdentifierInContext:conversation.managedObjectContext]]) {
//        return nil;
//    }
//
//    NSUUID *nonce = [NSUUID UUID];
//    ZMGenericMessage *message = [ZMGenericMessage messageWithContent:[ZMCleared clearedWithTimestamp:cleared conversationRemoteID:convID] nonce:nonce];
//    VerifyReturnNil(message != nil);
//
//    return [self appendSelfConversationWithGenericMessage:message managedObjectContext:conversation.managedObjectContext];
//    }
//
    + (void)updateConversationWithZMClearedFromSelfConversation:(ZMCleared *)cleared inContext:(NSManagedObjectContext *)context
{
    double newTimeStamp = cleared.clearedTimestamp;
    NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:(newTimeStamp/1000)];
    NSUUID *conversationID = [NSUUID uuidWithTransportString:cleared.conversationId];

    if (conversationID == nil || timestamp == nil) {
        return;
    }

    ZMConversation *conversation = [ZMConversation conversationWithRemoteID:conversationID createIfNeeded:YES inContext:context];
    [conversation updateCleared:timestamp synchronize:NO];
}
//
//    + (void)updateConversationWithZMLastReadFromSelfConversation:(ZMLastRead *)lastRead inContext:(NSManagedObjectContext *)context
//{
//    double newTimeStamp = lastRead.lastReadTimestamp;
//    NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:(newTimeStamp/1000)];
//    NSUUID *conversationID = [NSUUID uuidWithTransportString:lastRead.conversationId];
//    if (conversationID == nil || timestamp == nil) {
//        return;
//    }
//
//    ZMConversation *conversationToUpdate = [ZMConversation conversationWithRemoteID:conversationID createIfNeeded:YES inContext:context];
//    [conversationToUpdate updateLastRead:timestamp synchronize:NO];
//}
//@end

extension ZMConversation {
    static func updateConversation(withLastReadFromSelfConversation lastRead: LastRead, inContext moc: NSManagedObjectContext) {
        let newTimeStamp = Double(integerLiteral: lastRead.lastReadTimestamp)
        let timestamp = Date(timeIntervalSince1970: newTimeStamp/1000)
        guard let conversationID = UUID(uuidString: lastRead.conversationID) else {
            return
        }
        let conversation = ZMConversation(remoteID: conversationID, createIfNeeded: false, in: moc)
        conversation?.updateLastRead(timestamp, synchronize: false)
    }
    
    static func updateConversation(withClearedFromSelfConversation cleared: Cleared, inContext moc: NSManagedObjectContext) {
        let newTimeStamp = Double(integerLiteral: cleared.clearedTimestamp)
        let timestamp = Date(timeIntervalSince1970: newTimeStamp/1000)
        guard let conversationID = UUID(uuidString: cleared.conversationID) else {
            return
        }
        let conversation = ZMConversation(remoteID: conversationID, createIfNeeded: false, in: moc)
        conversation?.updateCleared(timestamp, synchronize: false)
        
    }
}
