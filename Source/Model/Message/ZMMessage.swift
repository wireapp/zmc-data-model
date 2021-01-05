
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

    @NSManaged
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
    
    @objc(fetchLatestPotentialGapSystemMessageInConversation:)
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

    public override static func entityName() -> String {
        return "SystemMessage"
    }

    override init(nonce: UUID?, managedObjectContext: NSManagedObjectContext?) {
        var entity: NSEntityDescription? = nil
        entity = NSEntityDescription.entity(forEntityName: ZMSystemMessage.entityName(), in: managedObjectContext!)
        super.init(entity: entity!, insertInto: managedObjectContext)
        
        self.nonce = nonce
        relevantForConversationStatus = true //default value
    }

    ///TODO: var
    static let eventTypeToSystemMessageTypeMap: [ZMUpdateEventType : ZMSystemMessageType] = [
            .conversationMemberJoin: .participantsAdded,
            .conversationMemberLeave: .participantsRemoved,
            .conversationRename: .conversationNameChanged
        ]
    
    class func systemMessageType(from type: ZMUpdateEventType) -> ZMSystemMessageType {
        guard let systemMessageType = eventTypeToSystemMessageTypeMap[type] else {
            return .invalid
        }

        return systemMessageType
    }
    
    class func createOrUpdateMessage(
        from updateEvent: ZMUpdateEvent,
        in moc: NSManagedObjectContext,
        prefetchResult: ZMFetchRequestBatchResult?
    ) -> ZMSystemMessage? {
        let type = systemMessageType(from: updateEvent.type)
        if type == .invalid {
            return nil
        }
        
        let conversation = self.conversation(for: updateEvent, in: moc, prefetchResult: prefetchResult)
        
        //TODO:

//        VerifyAction(conversation != nil, return nil)
        
//        #define VerifyAction(assertion, action) \
//        do { \
//            if ( __builtin_expect(!(assertion), 0) ) { \
//                ZMDebugAssertMessage(@"Verify", #assertion, __FILE__, __LINE__, nil); \
//                    action; \
//            } \
//        } while (0)
        // Only create connection request system message if conversation type is valid.
        // Note: if type is not connection request, then it relates to group conversations (see first line of this method).
        // We don't explicitly check for group conversation type b/c if this is the first time we were added to the conversation,
        // then the default conversation type is `invalid` (b/c we haven't fetched from BE yet), so we assume BE sent the
        // update event for a group conversation.
        if conversation?.conversationType == .connection && type != .connectionRequest {
            return nil
        }
        
        let messageText = updateEvent.payload.dictionary(forKey: "data")?.optionalString(forKey: "message")?.removingExtremeCombiningCharacters
        let name = updateEvent.payload.dictionary(forKey: "data")?.optionalString(forKey: "name")?.removingExtremeCombiningCharacters
        
        var usersSet: Set<AnyHashable> = []
        if let payload = (updateEvent.payload.dictionary(forKey: "data") as NSDictionary?)?.optionalArray(forKey: "user_ids") {
            for userId in payload {
                guard let userId = userId as? String else {
                    continue
                }
                let user = ZMUser(remoteID: NSUUID(transport: userId)! as UUID, createIfNeeded: true, in: moc)
                _ = usersSet.insert(user)
            }
        }
        
        let message = ZMSystemMessage(nonce: UUID(), managedObjectContext: moc)
        message.systemMessageType = type
        message.visibleInConversation = conversation
        message.serverTimestamp = updateEvent.timestamp
        
        message.update(with: updateEvent, for: conversation!)
        
        if usersSet != Set<AnyHashable>([message.sender]) {
            usersSet.remove(message.sender)
        }
        
        message.users = usersSet as! Set<ZMUser>
        message.text = messageText ?? name
        
        conversation?.updateTimestampsAfterInsertingMessage( message)
        
        return message
    }
}
