//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import WireCryptobox

extension ZMConversation {

    /// Contains current security level of conversation.
    /// Client should check this property to properly annotate conversation.
    @NSManaged public internal(set) var securityLevel: ZMConversationSecurityLevel

    /// Whether the conversation is under legal hold.
    @NSManaged public internal(set) var isUnderLegalHold: Bool

    // MARK: - Events

    /// Should be called when client is trusted.
    /// If the conversation became trusted, it will trigger UI notification and add system message for all devices verified
    @objc(increaseSecurityLevelIfNeededAfterTrustingClients:)
    public func increaseSecurityLevelIfNeededAfterTrusting(clients: Set<UserClient>) {
        applySecurityChanges(cause: .verifiedClients(clients))
    }

    /// Should be called when client is deleted.
    /// If the conversation became trusted, it will trigger UI notification and add system message for all devices verified
    @objc(increaseSecurityLevelIfNeededAfterRemovingClientForUsers:)
    public func increaseSecurityLevelIfNeededAfterRemoving(clients: [ZMUser: Set<UserClient>]) {
        applySecurityChanges(cause: .removedClients(clients))
    }

    /// Should be called when a user is deleted.
    /// If the conversation became trusted, it will trigger UI notification and add system message for all devices verified
    @objc(increaseSecurityLevelIfNeededAfterRemovingUsers:)
    public func increaseSecurityLevelIfNeededAfterRemoving(users: Set<ZMUser>) {
        applySecurityChanges(cause: .removedUsers(users))
    }

    /// Should be called when a new client is discovered
    @objc(decreaseSecurityLevelIfNeededAfterDiscoveringClients:causedByMessage:)
    public func decreaseSecurityLevelIfNeededAfterDiscovering(clients: Set<UserClient>, causedBy message: ZMOTRMessage?) {
        applySecurityChanges(cause: .message(message, clients))
    }
    
    /// Should be called when a new user is added to the conversation
    @objc(decreaseSecurityLevelIfNeededAfterDiscoveringClients:causedByAddedUsers:)
    public func decreaseSecurityLevelIfNeededAfterDiscovering(clients: Set<UserClient>, causedBy users: Set<ZMUser>) {
        applySecurityChanges(cause: .addedUsers(users))
    }

    /// Should be called when a client is ignored
    @objc(decreaseSecurityLevelIfNeededAfterIgnoringClients:)
    public func decreaseSecurityLevelIfNeededAfterIgnoring(clients: Set<UserClient>) {
        applySecurityChanges(cause: .ignoredClients(clients))
    }

    /// Applies the security changes for the set of users.
    private func applySecurityChanges(cause: SecurityChangeCause) {
        // Check legal hold changes
        updateLegalHoldState(cause: cause)

        // Check verification
        if securityLevel == .secure {
            if !allUsersTrusted {
                securityLevel = .secureWithIgnored

                switch cause {
                case .message, .addedUsers:
                    appendNewAddedClientSystemMessage(cause: cause)
                    expireAllPendingMessagesBecauseOfSecurityLevelDegradation()
                case .ignoredClients(let clients):
                    appendIgnoredClientsSystemMessage(ignored: clients)
                default:
                    break
                }
            }
        } else {
            // Check if the conversation becomes trusted
            if allUsersTrusted && allParticipantsHaveClients {
                securityLevel = .secure
                appendNewIsSecureSystemMessage(cause: cause)
                notifyOnUI(name: ZMConversation.isVerifiedNotificationName)
            } else {
                securityLevel = .notSecure
            }
        }
    }

    private func updateLegalHoldState(cause: SecurityChangeCause) {
        switch cause {
        case .addedUsers(let users):
            var isUnderLegalHold = false

            for user in users where user.isUnderLegalHold {
                isUnderLegalHold = true

                appendLegalHoldEnabledSystemMessageIfNeeded(for: user)
            }

            self.isUnderLegalHold = isUnderLegalHold

        case .message(_, let clients):
            var isUnderLegalHold = false

            for client in clients.filter({ $0.deviceClass == .legalhold }) {
                isUnderLegalHold = true

                if let user = client.user {
                    appendLegalHoldEnabledSystemMessageIfNeeded(for: user)
                }
            }

            self.isUnderLegalHold = isUnderLegalHold

        case .removedClients(let userClients):
            for (user, _) in userClients {
                appendLegalHoldDisabledSystemMessageIfNeeded(for: user)
            }

            disableLegalHoldIfNeeded()

        case .removedUsers:
            disableLegalHoldIfNeeded()

        case .verifiedClients, .ignoredClients:
            // no-op: verification does not impact legal hold because no clients are added or removed
            break
        }
    }

    /// When a user is removed, we need to check whether the conversation is still under legal hold.
    private func disableLegalHoldIfNeeded() {
        if !activeParticipants.contains(where: { $0.isUnderLegalHold }) {
            isUnderLegalHold = false
            appendLegalHoldDisabledSystemMessageForConversation()
        }
    }

    // MARK: - Messages

    /// Creates system message that says that you started using this device, if you were not registered on this device
    @objc public func appendStartedUsingThisDeviceMessage() {
        guard ZMSystemMessage.fetchStartedUsingOnThisDeviceMessage(conversation: self) == nil else { return }
        let selfUser = ZMUser.selfUser(in: self.managedObjectContext!)
        guard let selfClient = selfUser.selfClient() else { return }
        self.appendSystemMessage(type: .usingNewDevice,
                                 sender: selfUser,
                                 users: Set(arrayLiteral: selfUser),
                                 clients: Set(arrayLiteral: selfClient),
                                 timestamp: timestampAfterLastMessage())
    }

    /// Creates a system message when a device has previously been used before, but was logged out due to invalid cookie and/ or invalidated client
    @objc public func appendContinuedUsingThisDeviceMessage() {
        let selfUser = ZMUser.selfUser(in: self.managedObjectContext!)
        guard let selfClient = selfUser.selfClient() else { return }
        self.appendSystemMessage(type: .reactivatedDevice,
                                 sender: selfUser,
                                 users: Set(arrayLiteral: selfUser),
                                 clients: Set(arrayLiteral: selfClient),
                                 timestamp: Date())
    }

    /// Creates a system message that inform that there are pontential lost messages, and that some users were added to the conversation
    @objc public func appendNewPotentialGapSystemMessage(users: Set<ZMUser>?, timestamp: Date) {
        
        let previousLastMessage = lastMessage
        let systemMessage = self.appendSystemMessage(type: .potentialGap,
                                                     sender: ZMUser.selfUser(in: self.managedObjectContext!),
                                                     users: users,
                                                     clients: nil,
                                                     timestamp: timestamp)
        systemMessage.needsUpdatingUsers = true
        
        if let previousLastMessage = previousLastMessage as? ZMSystemMessage,
            previousLastMessage.systemMessageType == .potentialGap,
            previousLastMessage.serverTimestamp < timestamp {
            // In case the message before the new system message was also a system message of
            // the type ZMSystemMessageTypePotentialGap, we delete the old one and update the
            // users property of the new one to use old users and calculate the added / removed users
            // from the time the previous one was added
            systemMessage.users = previousLastMessage.users
            self.managedObjectContext?.delete(previousLastMessage)
        }
    }

    /// Creates the message that warns user about the fact that decryption of incoming message is failed
    @objc(appendDecryptionFailedSystemMessageAtTime:sender:client:errorCode:)
    public func appendDecryptionFailedSystemMessage(at date: Date?, sender: ZMUser, client: UserClient?, errorCode: Int) {
        let type = (UInt32(errorCode) == CBOX_REMOTE_IDENTITY_CHANGED.rawValue) ? ZMSystemMessageType.decryptionFailed_RemoteIdentityChanged : ZMSystemMessageType.decryptionFailed
        let clients = client.flatMap { Set(arrayLiteral: $0) } ?? Set<UserClient>()
        let serverTimestamp = date ?? timestampAfterLastMessage()
        self.appendSystemMessage(type: type,
                                 sender: sender,
                                 users: nil,
                                 clients: clients,
                                 timestamp: serverTimestamp)
    }

    /// Adds the user to the list of participants if not already present and inserts a .participantsAdded system message
    @objc(addParticipantIfMissing:date:)
    public func addParticipantIfMissing(_ user: ZMUser, at date: Date = Date()) {
        guard !activeParticipants.contains(user) else { return }
        
        switch conversationType {
        case .group:
            appendSystemMessage(type: .participantsAdded, sender: user, users: Set(arrayLiteral: user), clients: nil, timestamp: date)
            internalAddParticipants(Set(arrayLiteral: user))
        case .oneOnOne, .connection:
            if user.connection == nil {
                user.connection = connection ?? ZMConnection.insertNewObject(in: managedObjectContext!)
            } else if connection == nil {
                connection = user.connection
            }
            
            user.connection?.needsToBeUpdatedFromBackend = true
        default:
            break
        }
        
        // A missing user indicate that we are out of sync with the BE so we'll re-sync the conversation
        needsToBeUpdatedFromBackend = true
    }

    private func appendLegalHoldDisabledSystemMessageForConversation() {

    }

    private func appendLegalHoldEnabledSystemMessageIfNeeded(for user: ZMUser) {
        guard user.isUnderLegalHold else { return }
        self.appendSystemMessage(type: .legalHoldEnabled,
                                 sender: ZMUser.selfUser(in: self.managedObjectContext!),
                                 users: [user],
                                 clients: user.clients,
                                 timestamp: timestampAfterLastMessage())
    }

    private func appendLegalHoldDisabledSystemMessageIfNeeded(for user: ZMUser) {
        guard !user.isUnderLegalHold else { return }

    }
}

// MARK: - Messages resend/expiration
extension ZMConversation {
    
    /// Mark conversation as not secure. This method is expected to be called from the UI context
    @objc public func makeNotSecure() {
        precondition(self.managedObjectContext!.zm_isUserInterfaceContext)
        self.securityLevel = .notSecure
        self.managedObjectContext?.saveOrRollback()
    }
    
    /// Resend last non sent messages. This method is expected to be called from the UI context
    @objc public func resendMessagesThatCausedConversationSecurityDegradation() {
        precondition(self.managedObjectContext!.zm_isUserInterfaceContext)
        self.securityLevel = .notSecure // The conversation needs to be marked as not secure for new messages to be sent
        self.managedObjectContext?.saveOrRollback()
        self.enumerateReverseMessagesThatCausedDegradationUntilFirstSystemMessageOnSyncContext {
            $0.causedSecurityLevelDegradation = false
            $0.resend()
        }
    }
    
    /// Reset those that caused degradation. This method is expected to be called from the UI context
    @objc public func doNotResendMessagesThatCausedDegradation() {
        guard let syncMOC = self.managedObjectContext?.zm_sync else { return }
        syncMOC.performGroupedBlock {
            guard let conversation = (try? syncMOC.existingObject(with: self.objectID)) as? ZMConversation else { return }
            conversation.clearMessagesThatCausedSecurityLevelDegradation()
            syncMOC.saveOrRollback()
        }
    }
    
    /// Enumerates all messages from newest to oldest and apply a block to all ZMOTRMessage encountered, 
    /// halting the enumeration when a system message for security level degradation is found.
    /// This is executed asychronously on the sync context
    private func enumerateReverseMessagesThatCausedDegradationUntilFirstSystemMessageOnSyncContext(block: @escaping (ZMOTRMessage)->()) {
        guard let syncMOC = self.managedObjectContext?.zm_sync else { return }
        syncMOC.performGroupedBlock {
            guard let conversation = (try? syncMOC.existingObject(with: self.objectID)) as? ZMConversation else { return }
            conversation.messagesThatCausedSecurityLevelDegradation.forEach(block)
            syncMOC.saveOrRollback()
        }
    }
    
    /// Expire all pending messages
    fileprivate func expireAllPendingMessagesBecauseOfSecurityLevelDegradation() {
        for message in undeliveredMessages {
            if let clientMessage = message as? ZMClientMessage, let genericMessage = clientMessage.genericMessage, genericMessage.hasConfirmation() {
                // Delivery receipt: just expire it
                message.expire()
            } else {
                // All other messages: expire and mark that it caused security degradation
                message.expire()
                message.causedSecurityLevelDegradation = true
            }
        }
    }
    
    fileprivate var undeliveredMessages: [ZMOTRMessage] {
        guard let managedObjectContext = managedObjectContext else { return [] }
        
        let timeoutLimit = Date().addingTimeInterval(-ZMMessage.defaultExpirationTime())
        let selfUser = ZMUser.selfUser(in: managedObjectContext)
        let undeliveredMessagesPredicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K == NO AND %K > %@",
                                                       ZMMessageConversationKey, self,
                                                       ZMMessageSenderKey, selfUser,
                                                       DeliveredKey,
                                                       ZMMessageServerTimestampKey, timeoutLimit as NSDate)
        
        let fetchRequest = NSFetchRequest<ZMClientMessage>(entityName: ZMClientMessage.entityName())
        fetchRequest.predicate = undeliveredMessagesPredicate
        
        let assetFetchRequest = NSFetchRequest<ZMAssetClientMessage>(entityName: ZMAssetClientMessage.entityName())
        assetFetchRequest.predicate = undeliveredMessagesPredicate
        
        var undeliveredMessages: [ZMOTRMessage] = []
        undeliveredMessages += managedObjectContext.fetchOrAssert(request: fetchRequest) as [ZMOTRMessage]
        undeliveredMessages += managedObjectContext.fetchOrAssert(request: assetFetchRequest) as [ZMOTRMessage]
        
        return undeliveredMessages
    }
    
}

// MARK: - HotFix
extension ZMConversation {

    /// Replaces the first NewClient systemMessage for the selfClient with a UsingNewDevice system message
    @objc public func replaceNewClientMessageIfNeededWithNewDeviceMesssage() {

        let selfUser = ZMUser.selfUser(in: self.managedObjectContext!)
        guard let selfClient = selfUser.selfClient() else { return }
        
        NSOrderedSet(array: lastMessages()).enumerateObjects() { (msg, idx, stop) in
            guard idx <= 2 else {
                stop.initialize(to: true)
                return
            }
            
            guard let systemMessage = msg as? ZMSystemMessage,
                systemMessage.systemMessageType == .newClient,
                systemMessage.sender == selfUser else {
                    return
            }
            
            if systemMessage.clients.contains(selfClient) {
                systemMessage.systemMessageType = .usingNewDevice
                stop.initialize(to: true)
            }
        }
    }
}

// MARK: - Appending system messages
extension ZMConversation {
    
    fileprivate func appendNewIsSecureSystemMessage(cause: SecurityChangeCause) {
        switch cause {
        case .removedUsers(let users):
            appendNewIsSecureSystemMessage(verified: [], for: users)
        case .verifiedClients(let userClients):
            let users = Set(userClients.compactMap { $0.user })
            appendNewIsSecureSystemMessage(verified: userClients, for: users)
        case .removedClients(let userClients):
            let users = Set(userClients.keys)
            let clients = Set(userClients.values.flatMap { $0 })
            appendNewIsSecureSystemMessage(verified: clients, for: users)
        default:
            // no-op: the conversation is not secure in other cases
            return
        }
    }
    
    fileprivate func appendNewIsSecureSystemMessage(verified clients: Set<UserClient>, for users: Set<ZMUser>) {
        guard !users.isEmpty, securityLevel != .secureWithIgnored else {
            return
        }

        appendSystemMessage(type: .conversationIsSecure,
                            sender: ZMUser.selfUser(in: self.managedObjectContext!),
                            users: users,
                            clients: clients,
                            timestamp: timestampAfterLastMessage())
    }
    
    fileprivate enum SecurityChangeCause {
        case message(ZMOTRMessage?, Set<UserClient>)
        case addedUsers(Set<ZMUser>)
        case removedUsers(Set<ZMUser>)
        case verifiedClients(Set<UserClient>)
        case removedClients([ZMUser: Set<UserClient>])
        case ignoredClients(Set<UserClient>)
    }
    
    fileprivate func appendNewAddedClientSystemMessage(cause: SecurityChangeCause) {
        var timestamp : Date?
        var addedUsers: Set<ZMUser> = []
        var addedClients: Set<UserClient> = []
        
        switch cause {
        case .addedUsers(let users):
            addedUsers = users
        case .message(let message, let clients):
            addedClients = clients
            if let message = message, message.conversation == self {
                timestamp = self.timestamp(before: message)
            }
        default:
            // unsupported cause
            return
        }
        
        guard !addedClients.isEmpty || !addedUsers.isEmpty else { return }
        
        self.appendSystemMessage(type: .newClient,
                                 sender: ZMUser.selfUser(in: self.managedObjectContext!),
                                 users: addedUsers,
                                 addedUsers: addedUsers,
                                 clients: addedClients,
                                 timestamp: timestamp ?? timestampAfterLastMessage())
    }
    
    fileprivate func appendIgnoredClientsSystemMessage(ignored clients: Set<UserClient>) {
        guard !clients.isEmpty else { return }
        let users = Set(clients.compactMap { $0.user })
        self.appendSystemMessage(type: .ignoredClient,
                                 sender: ZMUser.selfUser(in: self.managedObjectContext!),
                                 users: users,
                                 clients: clients,
                                 timestamp: timestampAfterLastMessage())
    }
    
    @discardableResult
    func appendSystemMessage(type: ZMSystemMessageType,
                                         sender: ZMUser,
                                         users: Set<ZMUser>?,
                                         addedUsers: Set<ZMUser> = Set(),
                                         clients: Set<UserClient>?,
                                         timestamp: Date,
                                         duration: TimeInterval? = nil,
                                         messageTimer: Double? = nil,
                                         relevantForStatus: Bool = true) -> ZMSystemMessage {
        let systemMessage = ZMSystemMessage(nonce: UUID(), managedObjectContext: managedObjectContext!)
        systemMessage.systemMessageType = type
        systemMessage.sender = sender
        systemMessage.users = users ?? Set()
        systemMessage.addedUsers = addedUsers
        systemMessage.clients = clients ?? Set()
        systemMessage.serverTimestamp = timestamp
        if let duration = duration {
            systemMessage.duration = duration
        }
        
        if let messageTimer = messageTimer {
            systemMessage.messageTimer = NSNumber(value: messageTimer)
        }
        
        systemMessage.relevantForConversationStatus = relevantForStatus
        
        self.append(systemMessage)
        
        return systemMessage
    }
    
    /// Returns a timestamp that is shortly (as short as possible) before the given message,
    /// or the last modified date if the message is nil
    fileprivate func timestamp(before: ZMMessage?) -> Date? {
        guard let timestamp = before?.serverTimestamp ?? self.lastModifiedDate else { return nil }
        return timestamp.previousNearestTimestamp
    }
    
    /// Returns a timestamp that is shortly (as short as possible) after the given message,
    /// or the last modified date if the message is nil
    fileprivate func timestamp(after: ZMMessage?) -> Date? {
        guard let timestamp = after?.serverTimestamp ?? self.lastModifiedDate else { return nil }
        return timestamp.nextNearestTimestamp
    }
    
    // Returns a timestamp that is shortly (as short as possible) after the last message in the conversation,
    // or current time if there's no last message
    fileprivate func timestampAfterLastMessage() -> Date {
        return timestamp(after: lastMessage) ?? Date()
    }
}

// MARK: - Conversation participants status
extension ZMConversation {
    
    /// Returns true if all participants are connected to the self user and all participants are trusted
    @objc public var allUsersTrusted : Bool {
        guard self.lastServerSyncedActiveParticipants.count > 0, self.isSelfAnActiveMember else { return false }
        let hasOnlyTrustedUsers = self.activeParticipants.first { !$0.trusted() } == nil
        return hasOnlyTrustedUsers && !self.containsUnconnectedOrExternalParticipant
    }
    
    fileprivate var containsUnconnectedOrExternalParticipant : Bool {
        guard let managedObjectContext = self.managedObjectContext else {
            return true
        }
        
        let selfUser = ZMUser.selfUser(in: managedObjectContext)
        return (self.lastServerSyncedActiveParticipants.array as! [ZMUser]).first {
            if $0.isConnected {
                return false
            }
            else if $0.isWirelessUser {
                return false
            }
            else {
                return selfUser.team == nil || $0.team != selfUser.team
            }
        } != nil
    }
    
    fileprivate var allParticipantsHaveClients : Bool {
        return self.activeParticipants.first { $0.clients.count == 0 } == nil
    }
    
    /// If true the conversation might still be trusted / ignored
    @objc public var hasUntrustedClients : Bool {
        return self.activeParticipants.first { $0.untrusted() } != nil
    }
}

// MARK: - System messages
extension ZMSystemMessage {

    /// Fetch the first system message in the conversation about "started to use this device"
    fileprivate static func fetchStartedUsingOnThisDeviceMessage(conversation: ZMConversation) -> ZMSystemMessage? {
        guard let selfClient = ZMUser.selfUser(in: conversation.managedObjectContext!).selfClient() else { return nil }
        let conversationPredicate = NSPredicate(format: "%K == %@ OR %K == %@", ZMMessageConversationKey, conversation, ZMMessageHiddenInConversationKey, conversation)
        let newClientPredicate = NSPredicate(format: "%K == %d", ZMMessageSystemMessageTypeKey, ZMSystemMessageType.newClient.rawValue)
        let containsSelfClient = NSPredicate(format: "ANY %K == %@", ZMMessageSystemMessageClientsKey, selfClient)
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [conversationPredicate, newClientPredicate, containsSelfClient])
        
        let fetchRequest = ZMSystemMessage.sortedFetchRequest(with: compound)!
        let result = conversation.managedObjectContext!.executeFetchRequestOrAssert(fetchRequest)!
        return result.first as? ZMSystemMessage
    }
}

extension ZMMessage {
    
    /// True if the message is a "conversation degraded because of new client"
    /// system message
    fileprivate var isConversationNotVerifiedSystemMessage : Bool {
        guard let system = self as? ZMSystemMessage else { return false }
        return system.systemMessageType == .ignoredClient
    }
}

extension Date {
    var nextNearestTimestamp: Date {
        return Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextUp)
    }
    var previousNearestTimestamp: Date {
        return Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextDown)
    }
}

extension NSDate {
    @objc var nextNearestTimestamp: NSDate {
        return NSDate(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextUp)
    }
    @objc var previousNearestTimestamp: NSDate {
        return NSDate(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextDown)
    }
}
