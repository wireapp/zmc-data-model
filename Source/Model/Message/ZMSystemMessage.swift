
//  ZMMessage.swift
//  WireDataModel
//
//  Created by bill on 05.01.21.
//  Copyright © 2021 Wire Swiss GmbH. All rights reserved.
//

import Foundation

@objc
public class ZMSystemMessage: ZMMessage, ZMSystemMessageData {

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

    @NSManaged
    public var messageTimer: NSNumber? // Only filled for .messageTimerUpdate
    
    @NSManaged
    var relevantForConversationStatus: Bool // If true (default), the message is considered to be shown inside the conversation list
            
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
    
//    func usersReaction() -> [String : [ZMUser]]? {
//        return [:]
//    }
    
    @objc(fetchLatestPotentialGapSystemMessageInConversation:)
    class func fetchLatestPotentialGapSystemMessage(in conversation: ZMConversation) -> ZMSystemMessage? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: self.entityName())
        request.sortDescriptors = [
            NSSortDescriptor(key: ZMMessageServerTimestampKey, ascending: false)
        ]
        request.fetchBatchSize = 1
        request.predicate = self.predicateForPotentialGapSystemMessagesNeedingUpdatingUsers(in: conversation)
        let result = conversation.managedObjectContext!.executeFetchRequestOrAssert(request)
        return result.first as? ZMSystemMessage
    }
    
    class func predicateForPotentialGapSystemMessagesNeedingUpdatingUsers(in conversation: ZMConversation) -> NSPredicate {
        let conversationPredicate = NSPredicate(format: "%K == %@", ZMMessageConversationKey, conversation)
        let missingMessagesTypePredicate = NSPredicate(format: "%K == %@", ZMMessageSystemMessageTypeKey, ZMSystemMessageType.potentialGap.rawValue)
        let needsUpdatingUsersPredicate = NSPredicate(format: "%K == YES", ZMMessageNeedsUpdatingUsersKey)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            conversationPredicate,
            missingMessagesTypePredicate,
            needsUpdatingUsersPredicate
        ])
    }

    class func predicateForSystemMessagesInsertedLocally() -> NSPredicate? {
        return NSPredicate(block: { msg,_ in
            guard let msg = msg as? ZMSystemMessage else {
                return false
            }
            
            switch msg.systemMessageType {
            case .newClient, .potentialGap, .ignoredClient, .performedCall, .usingNewDevice, .decryptionFailed, .reactivatedDevice, .conversationIsSecure, .messageDeletedForEveryone, .decryptionFailed_RemoteIdentityChanged, .teamMemberLeave, .missedCall, .readReceiptsEnabled, .readReceiptsDisabled, .readReceiptsOn, .legalHoldEnabled, .legalHoldDisabled:
                return true
            case .invalid, .conversationNameChanged, .connectionRequest, .connectionUpdate, .newConversation, .participantsAdded, .participantsRemoved, .messageTimerUpdate:
                return false
            @unknown default:
                return false
            }
        })
    }

    @objc
    func updateNeedsUpdatingUsersIfNeeded() {
        if systemMessageType == .potentialGap && needsUpdatingUsers {
            let matchUnfetchedUserBlock: (ZMUser?) -> Bool = { user in
                return user?.name == nil
            }
    
            needsUpdatingUsers = addedUsers.any(matchUnfetchedUserBlock) || removedUsers.any(matchUnfetchedUserBlock)
        }
    }
    
    //MARK: - internal
    @objc
    class func doesEventTypeGenerateSystemMessage(_ type: ZMUpdateEventType) -> Bool {
        return eventTypeToSystemMessageTypeMap.keys.contains(type)
    }
    
    func systemMessageData() -> ZMSystemMessageData? {
        return self
    }

    
    public override func shouldGenerateUnreadCount() -> Bool {
        switch systemMessageType {
        case .participantsRemoved, .participantsAdded:
            let selfUser = ZMUser.selfUser(in: managedObjectContext!)
                return users.contains(selfUser) && false == sender?.isSelfUser
        case .newConversation:
            return sender?.isSelfUser == false
        case .missedCall:
            return relevantForConversationStatus
        default:
            return false
        }
    }
    
    /// Set to true if sender is the only user in users array. E.g. when a wireless user joins conversation
    public var userIsTheSender: Bool {
        let onlyOneUser = users.count == 1
        let isSender: Bool
        if let sender = sender {
            isSender = users.contains(sender)
        } else {
            isSender = false
        }
        return onlyOneUser && isSender
    }
    
    override func updateQuoteRelationships() {
        // System messages don't support quotes at the moment
    }
}
