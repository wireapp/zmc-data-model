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

extension ZMMessage {

    /// Sets the destruction date to the current date plus the timeout
    /// After this date the message "self-destructs", e.g. gets deleted from all sender & receiver devices or obfuscated if the sender is the selfUser
    @objc func startDestructionIfNeeded() -> Bool {

        if destructionDate != nil || !isEphemeral {
            return false
        }
        let isSelfUser: Bool
        if let sender = sender {
            isSelfUser = sender.isSelfUser
        } else {
            isSelfUser = false
        }

        if isSelfUser && managedObjectContext?.zm_isSyncContext ?? false {
            destructionDate = Date(timeIntervalSinceNow: deletionTimeout)

            if let timer: ZMMessageDestructionTimer = managedObjectContext?.zm_messageObfuscationTimer {
                timer.startObfuscationTimer(message: self, timeout: deletionTimeout)

                ///Do not start time if deliveryState is not ready
                switch deliveryState {
                case .pending,
                     .invalid,
                     .failedToSend:
                    return false
                default:
                    return true
                }
            } else {
                return false
            }
        } else if !isSelfUser && managedObjectContext?.zm_isUserInterfaceContext ?? false {
            if let timer: ZMMessageDestructionTimer = managedObjectContext?.zm_messageDeletionTimer {
                let matchedTimeInterval = timer.startDeletionTimer(message: self, timeout: deletionTimeout)
                destructionDate = Date(timeIntervalSinceNow: matchedTimeInterval)
                return true
            } else {
                return false
            }
        }
        return false
    }
}
