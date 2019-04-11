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

import Foundation

/**
 * Represents the possible state of external participants in a conversation.
 */

@objc public enum ZMConversationExternalParticipantsState: Int, CustomStringConvertible {
    /// All the conversation members are connected.
    case none

    /// The conversation contains guests.
    case onlyGuests

    /// The conversation contains services.
    case onlyServices

    /// The conversation contains both guests and services.
    case guestsAndServices

    public var description: String {
        switch self {
        case .none: return "none"
        case .onlyGuests: return "onlyGuests"
        case .onlyServices: return "onlyServices"
        case .guestsAndServices: return "guestsAndServices"
        }
    }
}

extension ZMConversation {

    @objc class func keyPathsForValuesAffectingExternalParticipantsState() -> Set<String> {
        return ["lastServerSyncedActiveParticipants.isServiceUser", "lastServerSyncedActiveParticipants.membership"]
    }

    /// The state of external participants in the conversation.
    @objc public var externalParticipantsState: ZMConversationExternalParticipantsState {
        // Exception 1) We don't consider guests/services as external participants in 1:1 conversations
        guard conversationType == .group else { return .none }

        // Exception 2) If there is only one user in the group and it's a service, we don't consider it as external
        let participants = self.activeParticipants
        let selfUser = ZMUser.selfUser(in: managedObjectContext!)
        let otherUsers = participants.subtracting([selfUser])

        if otherUsers.count == 1, otherUsers.first!.isServiceUser {
            return .none
        }

        // Calculate the external participants state
        let selfUserTeam = selfUser.team
        let canDisplayGuests = selfUserTeam != nil && team == selfUserTeam

        var areServicesPresent: Bool = false
        var areGuestsPresent: Bool = false

        for user in otherUsers {
            if user.isServiceUser {
                areServicesPresent = true
            } else if canDisplayGuests && user.isGuest(in: self) {
                areGuestsPresent = true
            }

            // Early exit to avoid going through all users if we can avoid it
            if areServicesPresent && (areGuestsPresent || !canDisplayGuests) {
                break
            }
        }

        switch (areGuestsPresent, areServicesPresent) {
        case (false, false): return .none
        case (true, false): return .onlyGuests
        case (false, true): return .onlyServices
        case (true, true): return .guestsAndServices
        }
    }

}
