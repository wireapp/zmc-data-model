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
    static
    private var participantRolesKeys: [String] {
        return [ZMConversationParticipantRolesKey,
                "participantRoles.markedForDeletion",
                "participantRoles.markedForInsertion"
        ]
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
    public var nonDeletedActiveParticipants: Set<ZMUser> {
        return Set(participantRoles.compactMap {
            if !$0.markedForDeletion {
                return $0.user
            } else {
                return nil
            }
        })
    }
    
    @objc
    var activeParticipants: Set<ZMUser> {
        guard let managedObjectContext = managedObjectContext else {return Set()}
        
        var activeParticipants: Set<ZMUser> = []
        
        if internalConversationType() != .group {
            activeParticipants.insert(ZMUser.selfUser(in: managedObjectContext))
            if let connectedUser = connectedUser {
                activeParticipants.insert(connectedUser)
            }
        } else if isSelfAnActiveMember {
            activeParticipants.insert(ZMUser.selfUser(in: managedObjectContext))
            activeParticipants.formUnion(nonDeletedActiveParticipants)
        } else {
            activeParticipants.formUnion(nonDeletedActiveParticipants)
        }
        
        return activeParticipants
    }


    @objc
    public var lastServerSyncedActiveParticipants: Set<ZMUser> {
        return Set(participantRoles.compactMap {
            if !$0.markedForDeletion && !$0.markedForInsertion {
             return $0.user
            } else {
                return nil
            }
        })
    }
    
    
    // MARK: - Participant Set operations

    /// union user set to participantRoles
    ///
    /// - Parameter users: users to union
    @objc
    func union(userSet: Set<ZMUser>, moc: NSManagedObjectContext) {
        let currentParticipantSet = lastServerSyncedActiveParticipants
        
        userSet.forEach() { user in
            if !currentParticipantSet.contains(user) {
                add(user: user, moc: moc)
            }

            ///if mark for delete, flip it
            if currentParticipantSet.contains(user) {
                participantRoles.first(where: {$0.markedForDeletion})?.markedForDeletion = false
            }
        }
    }///TODO: test
    
    @objc
    func minus(userSet: Set<ZMUser>, isFromLocal: Bool) {
        
        var removeArray = [ParticipantRole]()
        
        participantRoles.forEach() { participantRole in
            if userSet.contains(participantRole.user) {
                if !participantRole.markedForInsertion {
                    removeArray.append(participantRole)
                }
            }
        }
        
        removeArray.forEach() {
            if isFromLocal {
                $0.markedForDeletion = true
                $0.markedForInsertion = false
            } else {
                participantRoles.remove($0)
            }
        }
    }
    
    @objc
    func add(users: [ZMUser], moc: NSManagedObjectContext) {
        users.forEach() { user in
            add(user: user, moc: moc)
        }
    }
    
    @objc
    func add(user: ZMUser, moc: NSManagedObjectContext) {
        ParticipantRole.create(managedObjectContext: moc, user: user, conversation: self)
        ///TODO: noti is not fired??
    }

    @objc
    func add(user: ZMUser) {
        guard let moc = user.managedObjectContext else { return }
        
        add(user: user, moc: moc)
    }

}
