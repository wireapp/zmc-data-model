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
        return Set([ZMConversationIsSelfAnActiveMemberKey,
                    ZMConversationParticipantRolesKey])
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
            activeParticipants.formUnion(nonDeletedParticipants)
        } else {
            activeParticipants.formUnion(nonDeletedParticipants)
        }
        
        return activeParticipants
    }
    
    @objc
    public var nonDeletedParticipants: Set<ZMUser> {
        return Set(participantRoles.compactMap {
            if !$0.markedForDeletion {
                return $0.user
            } else {
                return nil
            }
        })
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
    func minus(userSet: Set<ZMUser>, isFromLocal: Bool) {
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
    func add(users: [ZMUser],
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
    
}
