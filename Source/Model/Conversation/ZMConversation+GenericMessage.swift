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

    public enum AppendMessageError: Error {
        case missingManagedObjectContext
        case malformedNonce
        case failedToProcessMessageData

    }

    /// Appends a new message to the conversation.
    ///
    /// - Parameters:
    ///     - genericMessage: The generic message that should be appended.
    ///     - expires: Whether the message should expire or tried to be send infinitively.
    ///     - hidden: Whether the message should be hidden in the conversation or not
    ///
    /// - Throws:
    ///     - `AppendMessageError` if the message couldn't be appended.

    @discardableResult
    public func appendClientMessage(with genericMessage: GenericMessage,
                                    expires: Bool = true,
                                    hidden: Bool = false) throws -> ZMClientMessage {

        guard let moc = managedObjectContext else {
            throw AppendMessageError.missingManagedObjectContext
        }

        guard let nonce = UUID(uuidString: genericMessage.messageID) else {
            throw AppendMessageError.malformedNonce
        }

        let message = ZMClientMessage(nonce: nonce, managedObjectContext: moc)

        do {
            try message.setUnderlyingMessage(genericMessage)
        } catch {
            moc.delete(message)
            throw AppendMessageError.failedToProcessMessageData
        }

        do {
            try append(message, expires: expires, hidden: hidden)
        } catch {
            moc.delete(message)
            throw error
        }

        return message
    }

    /// Appends a new message to the conversation.
    ///
    /// - Parameters:
    ///     - message: The message that should be appended.
    ///     - expires: Whether the message should expire or tried to be send infinitively.
    ///     - hidden: Whether the message should be hidden in the conversation or not
    ///
    /// - Throws:
    ///     - `AppendMessageError` if the message couldn't be appended.

    public func append(_ message: ZMClientMessage, expires: Bool, hidden: Bool) throws {
        guard let moc = managedObjectContext else {
            throw AppendMessageError.missingManagedObjectContext
        }

        message.sender = ZMUser.selfUser(in: moc)
        
        if expires {
            message.setExpirationDate()
        }
        
        if hidden {
            message.hiddenInConversation = self
        } else {
            append(message)
            unarchiveIfNeeded()
            message.updateCategoryCache()
            message.prepareToSend()
        }
    }
}
