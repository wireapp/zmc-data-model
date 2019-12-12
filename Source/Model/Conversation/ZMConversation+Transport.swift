//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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


import WireTransport

private let zmLog = ZMSLog(tag: "Conversations")


/// This enum matches the backend convention for type
@objc(ZMBackendConversationType)
public enum BackendConversationType: Int {
    case group = 0
    case `self` = 1
    case oneOnOne = 2
    case connection = 3
    
    public static func clientConversationType(rawValue: Int) -> ZMConversationType {
        guard let backendType = BackendConversationType(rawValue: rawValue) else {
            return .invalid
        }
        switch backendType {
            case .group:
                return .group
            case .oneOnOne:
                return .oneOnOne
            case .connection:
                return .connection
            case .`self`:
                return .`self`
        }
    }
}

extension ZMConversation {
    
    public struct PayloadKeys {
        
        private init() {}
        
        public static let nameKey = "name";
        public static let typeKey = "type";
        public static let IDKey = "id";
        
        public static let othersKey = "others";
        public static let membersKey = "members";
        public static let selfKey = "self";
        public static let creatorKey = "creator";
        public static let teamIdKey = "team";
        public static let accessModeKey = "access";
        public static let accessRoleKey = "access_role";
        public static let messageTimer = "message_timer";
        public static let receiptMode = "receipt_mode";
        
        public static let OTRMutedValueKey = "otr_muted";
        public static let OTRMutedStatusValueKey = "otr_muted_status";
        public static let OTRMutedReferenceKey = "otr_muted_ref";
        public static let OTRArchivedValueKey = "otr_archived";
        public static let OTRArchivedReferenceKey = "otr_archived_ref";
    }
    
    public func updateCleared(fromPostPayloadEvent event: ZMUpdateEvent ) {
        if let timeStamp = event.timeStamp() {
            updateCleared(timeStamp, synchronize: true)
        }
    }
    
    @objc
    public func update(updateEvent: ZMUpdateEvent) {
        if let timeStamp = updateEvent.timeStamp() {
            self.updateServerModified(timeStamp)
        }
    }
    
    @objc
    public func update(transportData: [String: Any], serverTimeStamp: Date?) {
        
        guard let moc = self.managedObjectContext else { return }
        
        if let remoteId = transportData.UUID(fromKey: PayloadKeys.IDKey) {
            require(remoteId == self.remoteIdentifier,
                    "Remote IDs not matching for conversation \(remoteId) vs. \(String(describing: self.remoteIdentifier))")
        }

        if let name = transportData[PayloadKeys.nameKey] as? String {
            self.userDefinedName = name
        }
    
        if let conversationType = (transportData[PayloadKeys.typeKey] as? Int)
            .flatMap(BackendConversationType.clientConversationType)
        {
            self.conversationType = conversationType
        }
        
        if let serverTimeStamp = serverTimeStamp {
            // If the lastModifiedDate is non-nil, e.g. restore from backup, do not update the lastModifiedDate
            if self.lastModifiedDate == nil {
                self.updateLastModified(serverTimeStamp)
            }
            self.updateServerModified(serverTimeStamp)
        }

        if let members = transportData[PayloadKeys.membersKey] as? [String: Any?],
            let selfStatus = members[PayloadKeys.selfKey] as? [String: Any?] {
            self.updateSelfStatus(dictionary: selfStatus, timeStamp: nil, previousLastServerTimeStamp: nil)
        }
        else {
            zmLog.error("Missing self status in conversation data")
        }
    
        if let creatorId = transportData.UUID(fromKey: PayloadKeys.creatorKey) {
            self.creator = ZMUser(remoteID: creatorId, createIfNeeded: true, in: moc)!
        }
        
        if let members = transportData[PayloadKeys.membersKey] as? [String: Any?] {
            self.updateMembers(payload: members)
            self.updatePotentialGapSystemMessagesIfNeeded(users: self.activeParticipants)
        } else {
            zmLog.error("Invalid members in conversation JSON: \(transportData)")
        }

        self.updateTeam(identifier: transportData.UUID(fromKey: PayloadKeys.teamIdKey))
        
        if let receiptMode = transportData[PayloadKeys.receiptMode] as? Int {
            let enabled = receiptMode > 0
            let receiptModeChanged = !self.hasReadReceiptsEnabled && enabled
            self.hasReadReceiptsEnabled = enabled;

            // We only want insert a system message if this is an existing conversation (non empty)
            if (receiptModeChanged && self.lastMessage != nil) {
                self.appendMessageReceiptModeIsOnMessage(timestamp: Date())
            }
        }
        
        self.accessModeStrings = transportData[PayloadKeys.accessModeKey] as? [String]
        self.accessRoleString = transportData[PayloadKeys.accessRoleKey] as? String
        
        if let messageTimerNumber = transportData[PayloadKeys.messageTimer] as? Double {
            // Backend is sending the miliseconds, we need to convert to seconds.
            self.syncedMessageDestructionTimeout = messageTimerNumber / 1000;
        }
    }
    
    private func updateMembers(payload: [String: Any?]) {
        
        guard let usersInfos = payload[PayloadKeys.othersKey] as? [[String: Any?]],
            let moc = self.managedObjectContext else {
                return
        }
        
        let remoteParticipantUUIDs = Set(usersInfos.compactMap { $0.UUID(fromKey: PayloadKeys.IDKey) })
        var remoteParticipants = ZMUser.users(withRemoteIDs: remoteParticipantUUIDs, in: moc)
        
        if remoteParticipants.count != remoteParticipantUUIDs.count {

            // Some users didn't exist so we need create the missing users
            let missingUsers = remoteParticipantUUIDs.subtracting(remoteParticipants.map { $0.remoteIdentifier! } )
            remoteParticipants.formUnion(missingUsers.map {
                ZMUser(remoteID: $0, createIfNeeded: true, in: moc)!
            })
        }

        // the self user is always a part of the conversation if we are in this method
        //backend will never send us the update of conversation where we are not in
        let newParticipants = remoteParticipants.union([ZMUser.selfUser(in: moc)])
        
        let addedParticipants = newParticipants.subtracting(self.localParticipants)
        let removedParticipants = self.localParticipants.subtracting(newParticipants)
  
        let selfUser = ZMUser.selfUser(in: moc)
        self.internalAddParticipants(Array(addedParticipants))
        self.internalRemoveParticipants(Array(removedParticipants), sender: selfUser)
    }
    
    func updateTeam(identifier: UUID?) {
        guard let teamId = identifier,
            let moc = self.managedObjectContext else { return }
        self.teamRemoteIdentifier = teamId
        self.team = Team.fetchOrCreate(with: teamId, create: false, in: moc, created: nil)
    }
    
    @objc func updatePotentialGapSystemMessagesIfNeeded(users: Set<ZMUser>) {
        guard let latestSystemMessage = ZMSystemMessage.fetchLatestPotentialGapSystemMessage(in: self)
            else { return }
        
        let removedUsers = latestSystemMessage.users.subtracting(users)
        let addedUsers = users.subtracting(latestSystemMessage.users)
        
        latestSystemMessage.addedUsers = addedUsers
        latestSystemMessage.removedUsers = removedUsers
        latestSystemMessage.updateNeedsUpdatingUsersIfNeeded()
    }
    
    /// Pass timestamp when the timestamp equals the time of the lastRead / cleared event, otherwise pass nil
    public func updateSelfStatus(dictionary: [String: Any?], timeStamp: Date?, previousLastServerTimeStamp: Date?) {
        self.updateMuted(with: dictionary)
        if  self.updateIsArchived(payload: dictionary) && self.isArchived,
            let previousLastServerTimeStamp = previousLastServerTimeStamp,
            let timeStamp = timeStamp,
            let clearedTimeStamp = self.clearedTimeStamp,
            clearedTimeStamp == previousLastServerTimeStamp
        {
            self.updateCleared(timeStamp, synchronize: false)
        }
    }
    
    private func updateIsArchived(payload: [String: Any?]) -> Bool {
        if let silencedRef = payload.date(fromKey: PayloadKeys.OTRArchivedReferenceKey),
            self.updateArchived(silencedRef, synchronize: false) {
            self.internalIsArchived = (payload[PayloadKeys.OTRArchivedValueKey] as? Int) == 1
            return true
        }
        return false
    }
    
    
    @objc(shouldAddEvent:)
    public func shouldAdd(event: ZMUpdateEvent) -> Bool {
        if let clearedTime = self.clearedTimeStamp, let time = event.timeStamp(),
            clearedTime.compare(time) != .orderedAscending {
            return false
        }
        return self.conversationType != .self
    }

}

fileprivate extension Dictionary where Key == String, Value == Any {
    
    func UUID(fromKey key: String) -> UUID? {
        return (self[key] as? String).flatMap(Foundation.UUID.init)
    }
    
    func date(fromKey key: String) -> Date? {
        return (self as NSDictionary).optionalDate(forKey: key)
    }
}

fileprivate extension Dictionary where Key == String, Value == Any? {
    
    func UUID(fromKey key: String) -> UUID? {
        return (self[key] as? String).flatMap(Foundation.UUID.init)
    }
    
    func date(fromKey key: String) -> Date? {
        return (self as NSDictionary).optionalDate(forKey: key)
    }
}
