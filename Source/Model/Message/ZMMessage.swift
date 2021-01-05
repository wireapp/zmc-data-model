
//  ZMMessage.swift
//  WireDataModel
//
//  Created by bill on 05.01.21.
//  Copyright © 2021 Wire Swiss GmbH. All rights reserved.
//

import Foundation

@objc
public class ZMSystemMessage: ZMMessage, ZMSystemMessageData {
//    @dynamic systemMessageType;
//    @dynamic users;
//    @dynamic clients;
//    @dynamic addedUsers;
//    @dynamic removedUsers;
//    @dynamic needsUpdatingUsers;
//    @dynamic duration;
//    @dynamic childMessages;
//    @dynamic parentMessage;
//    @dynamic messageTimer;
//    @dynamic relevantForConversationStatus;

    @NSManaged
    public var childMessages: Set<AnyHashable>
    
    @NSManaged
    public var systemMessageType: ZMSystemMessageType
    public var users: Set<ZMUser> = []
    public var clients: Set<AnyHashable> = []
    public var addedUsers: Set<ZMUser> = [] // Only filled for ZMSystemMessageTypePotentialGap and ZMSystemMessageTypeIgnoredClient
    public var removedUsers: Set<ZMUser> = [] // Only filled for ZMSystemMessageTypePotentialGap
    public var text: String?
    public var needsUpdatingUsers = false
    public var duration: TimeInterval = 0.0 // Only filled for .performedCall
    weak public var parentMessage: ZMSystemMessageData? // Only filled for .performedCall & .missedCall
    private(set) public var userIsTheSender = false // Set to true if sender is the only user in users array. E.g. when a wireless user joins conversation
    public var messageTimer: NSNumber? // Only filled for .messageTimerUpdate
    
    @objc
    var relevantForConversationStatus = false // If true (default), the message is considered to be shown inside the conversation list

    class func fetchLatestPotentialGapSystemMessage(in conversation: ZMConversation) -> ZMSystemMessage? {
        return nil
    }

    @objc
    func updateNeedsUpdatingUsersIfNeeded() {
    }
    
    //MARK: - internal
    @objc
    class func doesEventTypeGenerateSystemMessage(_ type: ZMUpdateEventType) -> Bool {
        return true
    }
    
    class func createOrUpdateMessage(from updateEvent: ZMUpdateEvent, in moc: NSManagedObjectContext) -> Self? {
        return nil
    }
    
    class func predicateForSystemMessagesInsertedLocally() -> NSPredicate {
        return NSPredicate()
    }

}
