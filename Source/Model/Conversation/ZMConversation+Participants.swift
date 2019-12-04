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
    public class func keyPathsForValuesAffectingLastServerSyncedActiveParticipants () -> Set<String>{
        return Set([ZMConversationParticipantRolesKey,
                    "participantRoles.markedForDeletion" //,
//                    "participantRoles.markedForInsertion"
            ])
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
    func minus(userSet: Set<ZMUser>) {
        
        var removeArray = [ParticipantRole]()
        
        participantRoles.forEach() { participantRole in
            if userSet.contains(participantRole.user) {
                if !participantRole.markedForInsertion {
                    removeArray.append(participantRole)
                }
            }
        }
        
        removeArray.forEach() {
//            participantRoles.remove($0) ///FIXME: test for entity is removed
            $0.markedForDeletion = true
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
