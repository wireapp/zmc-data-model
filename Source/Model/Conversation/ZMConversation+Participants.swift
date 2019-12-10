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
    
    static var participantRolesKeys: [String] {
        return [#keyPath(ZMConversation.participantRoles),
                #keyPath(ZMConversation.participantRoles.markedForDeletion),
                #keyPath(ZMConversation.participantRoles.markedForInsertion)]
    }
    
    @objc
    public class func keyPathsForValuesAffectingActiveParticipants() -> Set<String> {
        return Set([ZMConversationIsSelfAnActiveMemberKey] + participantRolesKeys)
    }
    
    @objc
    public class func keyPathsForValuesAffectingLocalParticipants() -> Set<String> {
        return Set(participantRolesKeys)
    }
    
    @objc
    public class func keyPathsForValuesAffectingLocalParticipantRoles() -> Set<String> {
        return Set(participantRolesKeys)
    }
    
    @objc
    public class func keyPathsForValuesAffectingDisplayName() -> Set<String> {
        return Set([ZMConversationConversationTypeKey,
                    "participantRoles.user.name",
                    "connection.to.name",
                    "connection.to.availability",
                    ZMConversationUserDefinedNameKey] +
                   ZMConversation.participantRolesKeys)
    }
    
    @objc
    public class func keyPathsForValuesAffectingLocalParticipantsExcludingSelf() -> Set<String> {
        return Set(ZMConversation.participantRolesKeys)
    }
    
    //MARK: - Participants methods
    
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
    
    /// Participants that are in the conversation, according to the local state,
    /// even if that state is not yet synchronized with the backend
    @objc
    public var localParticipantRoles: Set<ParticipantRole> {
        return participantRoles.filter { !$0.markedForDeletion }
    }
    
    /// Participants that are in the conversation, according to the local state
    /// even if that state is not yet synchronized with the backend
    @objc
    public var localParticipants: Set<ZMUser> {
        return Set(localParticipantRoles.map { $0.user })
    }
    
    /// Participants that are in the conversation, according to the local state
    /// even if that state is not yet synchronized with the backend

    @objc
    public var localParticipantsExcludingSelf: Set<ZMUser> {
        return self.localParticipants.filter { !$0.isSelfUser }
    }
    
    // MARK: - Participant operations
    
    /// union user set to participantRoles
    ///
    /// - Parameter users: users to union
    @objc
    func union(userSet: Set<ZMUser>,
               isFromLocal: Bool) {
        // TODO:
        // Split in two: one that adds from remote, one that adds from UI
        // use the method that also upgrades/degrades the conversation
        let currentParticipantSet = self.participantRoles.map { $0.user }
        
        userSet.forEach() { user in
            if !currentParticipantSet.contains(user) {
                add(user: user, isFromLocal: isFromLocal)
            }
            
            ///if marked for delete, set it to non-deleted
            if currentParticipantSet.contains(user) {
                participantRoles.first(where: {$0.markedForDeletion})?.markedForDeletion = false
            }
        }
    }
    
    @objc
    func minus(userSet: Set<ZMUser>, isFromLocal: Bool) {
        // TODO:
        // Split in two: one that removes from remote, one that removes from UI
        // use the method that also upgrades/degrades the conversation
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
    public func add(users: [ZMUser],
             isFromLocal: Bool) {
        // TODO:
        // Split in two: one that adds from remote, one that adds from UI
        // use the method that also upgrades/degrades the conversation
        users.forEach() { user in
            add(user: user, isFromLocal: isFromLocal)
        }
    }
    
    @objc
    public func add(user: ZMUser,
             isFromLocal: Bool) {
        // TODO:
        // Split in two: one that adds from remote, one that adds from UI
        // use the method that also upgrades/degrades the conversation
        guard let moc = user.managedObjectContext else { return }
        if let participantRole = user.participantRoles.first(where: {$0.conversation == self}) {
            participantRole.markedForDeletion = false
        } else {
            let participantRole = ParticipantRole.create(managedObjectContext: moc, user: user, conversation: self)
            
            participantRole.markedForInsertion = isFromLocal
        }
    }
    
}
