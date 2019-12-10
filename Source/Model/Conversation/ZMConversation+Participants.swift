//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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
import WireProtos

extension ZMConversation {
    
    @objc
    public var isSelfAnActiveMember: Bool {
        return self.participantRoles.contains(where: { (role) -> Bool in
            role.user.isSelfUser == true
        })
    }
    // MARK: - keyPathsForValuesAffecting
    
    static private var participantRolesKeys: [String] {
        return [ZMConversationParticipantRolesKey,
                "\(ZMConversationParticipantRolesKey).\(ZMParticipantRoleMarkedForDeletionKey)",
                "\(ZMConversationParticipantRolesKey).\(ZMParticipantRoleMarkedForInsertionKey)"]
    }
    
    @objc
    public class func keyPathsForValuesAffectingLastServerSyncedActiveParticipants () -> Set<String> {
        return Set(ZMConversation.participantRolesKeys)
    }
    
    @objc
    public class func keyPathsForValuesAffectingActiveParticipants() -> Set<String> {
        return Set([ZMConversationParticipantRolesKey])
    }
    
    @objc
    public class func keyPathsForValuesAffectingIsSelfAnActiveMember() -> Set<String> {
        return Set([ZMConversationParticipantRolesKey])
    }
    
    @objc
    public class func keyPathsForValuesAffectingDisplayName() -> Set<String> {
        return Set([ZMConversationConversationTypeKey,
                    "lastServerSyncedActiveParticipants.name",
                    "connection.to.name",
                    "connection.to.availability",
                    ZMConversationUserDefinedNameKey] +
            ZMConversation.participantRolesKeys)
    }
    
    /// List of users that are in the conversation
    @objc
    public var activeParticipants: Set<ZMUser> {
        guard let managedObjectContext = managedObjectContext else {return Set()}
        
        var activeParticipants: Set<ZMUser> = []
        
        if internalConversationType() != .group {
            activeParticipants.insert(ZMUser.selfUser(in: managedObjectContext))
            if let connectedUser = connectedUser {
                activeParticipants.insert(connectedUser)
            }
        } else if isSelfAnActiveMember {
            activeParticipants.insert(ZMUser.selfUser(in: managedObjectContext))
            activeParticipants.formUnion(localParticipants)
        } else {
            activeParticipants.formUnion(localParticipants)
        }
        
        return activeParticipants
    }
    
    /// Participants that are in the conversation, according to the local state
    @objc
    public var localParticipantRoles: Set<ParticipantRole> {
        return participantRoles.filter { !$0.markedForDeletion }
    }
    
    /// Participants that are in the conversation, according to the local state
    @objc
    public var localParticipants: Set<ZMUser> {
        return Set(localParticipantRoles.map { $0.user })
    }
    
    @objc
    public var lastServerSyncedActiveParticipants: Set<ZMUser> {
        return Set(participantRoles.compactMap {
            if !$0.markedForInsertion {
                return $0.user
            } else {
                return nil
            }
        })
    }
    
    
    // MARK: - Participant operations
    
    /// union user set to participantRoles
    ///
    /// - Parameter users: users to union
    @objc
    func union(userSet: Set<ZMUser>,
               isFromLocal: Bool) {
        let currentParticipantSet = lastServerSyncedActiveParticipants
        
        userSet.forEach() { user in
            if !currentParticipantSet.contains(user) {
                add(user: user, isFromLocal: isFromLocal)
            }
            
            ///if mark for delete, flip it
            if currentParticipantSet.contains(user) {
                participantRoles.first(where: {$0.markedForDeletion})?.markedForDeletion = false
            }
        }
    }
    
    @objc
    public func minus(userSet: Set<ZMUser>, isFromLocal: Bool) {
        participantRoles.forEach() {
            if userSet.contains($0.user) {
                switch (isFromLocal, $0.markedForInsertion) {
                case (true, true),
                     (false, _):
                    participantRoles.remove($0)
                    managedObjectContext?.delete($0)
                case (true, false):
                    $0.markedForDeletion = true
                    $0.markedForInsertion = false
                }
            }
        }
    }
    
    @objc
    public func minus(user: ZMUser, isFromLocal: Bool) {
        self.minus(userSet: Set([user]), isFromLocal: isFromLocal)
    }
    
    @objc
    public func add(users: [ZMUser],
             isFromLocal: Bool) {
        users.forEach() { user in
            add(user: user, isFromLocal: isFromLocal)
        }
    }
    
    @objc
    public func add(user: ZMUser,
             isFromLocal: Bool) {
        guard let moc = user.managedObjectContext else { return }
        if let participantRole = user.participantRoles.first(where: {$0.conversation == self}) {
            participantRole.markedForDeletion = false
        } else {
            let participantRole = ParticipantRole.create(managedObjectContext: moc, user: user, conversation: self)
            
            participantRole.markedForInsertion = isFromLocal
        }
    }
    
    // MARK: - Conversation roles
    
    /// List of roles for the conversation whether it's linked with a team or not
    @objc
    public func getRoles() -> Set<Role> {
        return (self.team == nil) ? self.nonTeamRoles : self.team!.roles
    }
}
