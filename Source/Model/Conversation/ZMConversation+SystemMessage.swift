////
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

public extension ZMConversation {

    private func groupNameMessage(in moc: NSManagedObjectContext, with name: String) -> ZMSystemMessage {
        let message = ZMSystemMessage.insertNewObject(in: moc)
        message.systemMessageType = .newConversationWithName
        message.sender = self.creator
        message.nonce = UUID()
        message.text = name
        // We need to make sure this is the first message and displayed before `.newConversation` system message
        message.serverTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        return message
    }

    private func groupParticipantsMessage(in moc: NSManagedObjectContext, with participants: Set<ZMUser>, name: String?) -> ZMSystemMessage {
        let message = ZMSystemMessage.insertNewObject(in: moc)
        message.systemMessageType = .newConversation
        message.sender = self.creator
        message.nonce = UUID()
        message.users = participants
        // Name might be nil although we don't support it anymore on iOS. It could be created on older versions of the app or other clients.
        // When the name is there it will be displayed below the `.newConversationWithName` system message and will have slighly different layout.
        message.text = name
        // This should be first message in conversation unless we also have group name
        message.serverTimestamp = Date(timeIntervalSinceReferenceDate: 1)
        return message
    }

    @objc(appendNewConversationSystemMessageWithName:)
    public func appendNewConversationSystemMessage(with name: String?) {
        guard let moc = self.managedObjectContext else { return }

        if let name = name {
            let nameMessage = groupNameMessage(in: moc, with: name)
            sortedAppendMessage(nameMessage)
            nameMessage.visibleInConversation = self
        }

        // If the conversation contains more people than just selfUser
        // append a message with participants
        if self.activeParticipants.count > 1 {
            let participants = self.activeParticipants.flatMap { $0 as? ZMUser }
            let participantsMessage = groupParticipantsMessage(in: moc, with: Set(participants), name: name)
            sortedAppendMessage(participantsMessage)
            participantsMessage.visibleInConversation = self
        }
    }
}
