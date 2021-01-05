
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

    @NSManaged
    public var users: Set<ZMUser>

    @NSManaged
    public var clients: Set<AnyHashable>

    @NSManaged
    public var addedUsers: Set<ZMUser> // Only filled for ZMSystemMessageTypePotentialGap and ZMSystemMessageTypeIgnoredClient
    @NSManaged
    public var removedUsers: Set<ZMUser> // Only filled for ZMSystemMessageTypePotentialGap
    public var text: String?

    @NSManaged
    public var needsUpdatingUsers: Bool

    @NSManaged
    public var duration: TimeInterval // Only filled for .performedCall

    @NSManaged
    weak public var parentMessage: ZMSystemMessageData? // Only filled for .performedCall & .missedCall
    private(set) public var userIsTheSender = false // Set to true if sender is the only user in users array. E.g. when a wireless user joins conversation

    @NSManaged
    public var messageTimer: NSNumber? // Only filled for .messageTimerUpdate
    
    @NSManaged
    var relevantForConversationStatus: Bool // If true (default), the message is considered to be shown inside the conversation list

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
