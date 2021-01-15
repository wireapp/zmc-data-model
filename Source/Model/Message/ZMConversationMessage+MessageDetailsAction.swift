//
// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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

public extension ZMConversationMessage {
    func canBeLiked(selfUser: UserType) -> Bool {
        guard let conversation = self.conversation,
              let selfUser = selfUser as? ZMUser else {
            return false
        }
        
        let participatesInConversation = conversation.localParticipants.contains(selfUser)
        let sentOrDelivered = deliveryState.isOne(of: .sent, .delivered, .read)
        let likableType = isNormal && !isKnock
        return participatesInConversation && sentOrDelivered && likableType && !isObfuscated && !isEphemeral
    }

    var isSentBySelfUser: Bool {
        return senderUser?.isSelfUser ?? false
    }
    
    /// Whether message details are available for this message.
    func areMessageDetailsAvailable(selfUser: UserType) -> Bool {
        guard let conversation = conversation else {
            return false
        }
        
        // Do not show the details of the message if it was not sent
        guard isSent else {
            return false
        }
        
        // There is no message details view in 1:1s.
        guard conversation.conversationType == .group else {
            return false
        }
        
        // Show the message details in Team groups.
        if conversation.teamRemoteIdentifier != nil {
            return canBeLiked(selfUser: selfUser) || isSentBySelfUser
        } else {
            return canBeLiked(selfUser: selfUser)
        }
    }

    /// Whether the user can see the read receipts details for this message.
    func areReadReceiptsDetailsAvailable(selfUser: UserType) -> Bool {
        // Do not show read receipts if details are not available.
        guard areMessageDetailsAvailable(selfUser: selfUser) else {
            return false
        }
        
        // Read receipts are only available in team groups
        guard conversation?.teamRemoteIdentifier != nil else {
            return false
        }
        
        // Only the sender of a message can see read receipts for their messages.
        return isSentBySelfUser
    }

}

