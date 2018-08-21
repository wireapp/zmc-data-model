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

extension ZMConversation {
    public class func existingConversation(in moc: NSManagedObjectContext, with service: ServiceUser, in team: Team?) -> ZMConversation? {
        guard let team = team else { return nil }
        guard let serviceID = service.serviceIdentifier else { return nil }
        let sameTeam = predicateForConversations(in: team)
        let groupConversation = NSPredicate(format: "%K == %d", ZMConversationConversationTypeKey, ZMConversationType.group.rawValue)
        let selfIsActiveMember = NSPredicate(format: "isSelfAnActiveMember == YES")
        let onlyOneOtherParticipant = NSPredicate(format: "%K.@count == 1", ZMConversationLastServerSyncedActiveParticipantsKey)
        let hasParticipantWithServiceIdentifier = NSPredicate(format: "ANY %K.%K == %@", ZMConversationLastServerSyncedActiveParticipantsKey, #keyPath(ZMUser.serviceIdentifier), serviceID)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [sameTeam, groupConversation, selfIsActiveMember, onlyOneOtherParticipant, hasParticipantWithServiceIdentifier])

        let fetchRequest = sortedFetchRequest(with: predicate)
        fetchRequest?.fetchLimit = 1
        let result = moc.executeFetchRequestOrAssert(fetchRequest)
        return result?.first as? ZMConversation
    }
}
