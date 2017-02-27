//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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

@objc public enum MessageReaction: UInt16 {
    case like

    public var unicodeValue: String {
        switch self {
        case .like: return "❤️"
        }
    }
}

extension ZMMessage {
    
    static func appendReaction(_ unicodeValue: String?, toMessage message: ZMConversationMessage) {
        guard let message = message as? ZMMessage, let context = message.managedObjectContext else { return }
        guard message.deliveryState == ZMDeliveryState.sent || message.deliveryState == ZMDeliveryState.delivered else { return }
        
        let emoji = unicodeValue ?? ""
        
        let genericMessage = ZMGenericMessage(
            emojiString: emoji,
            messageID: message.nonce.transportString(),
            nonce: NSUUID().transportString()
        )
    
        _ = message.conversation?.append(genericMessage, expires: false, hidden: true)
        message.addReaction(unicodeValue, forUser: .selfUser(in: context))
    }
    
    public static func addReaction(_ reaction: MessageReaction, toMessage message: ZMConversationMessage) {
        // confirmation that we understand the emoji
        // the UI should never send an emoji we dont handle
        if Reaction.transportReaction(from: reaction.unicodeValue) == .none{
            fatal("We can't append this reaction \(reaction.unicodeValue), this is a programmer error.")
        }
        
        appendReaction(reaction.unicodeValue, toMessage: message)
    }
    
    public static func removeReaction(onMessage message:ZMConversationMessage) {
        appendReaction(nil, toMessage: message)
    }
    
    @objc public func addReaction(_ unicodeValue: String?, forUser user:ZMUser) {
        removeReaction(forUser:user)
        if let unicodeValue = unicodeValue , unicodeValue.characters.count > 0 {
            for reaction in self.reactions {
                if reaction.unicodeValue! == unicodeValue {
                    reaction.mutableSetValue(forKey: ZMReactionUsersValueKey).add(user)
                    return
                }
            }
            
            //we didn't find a reaction, need to add a new one
            let newReaction = Reaction.insertReaction(unicodeValue, users: [user], inMessage: self)
            self.mutableSetValue(forKey: "reactions").add(newReaction)
        }
        updateCategoryCache()
    }
    
    fileprivate func removeReaction(forUser user: ZMUser) {
        for reaction in self.reactions {
            if reaction.users.contains(user) {
                reaction.mutableSetValue(forKey: ZMReactionUsersValueKey).remove(user)
                break;
            }
        }
    }

    @objc public func clearAllReactions() {
        reactions.removeAll()
        guard let moc = managedObjectContext else { return }
        reactions.forEach(moc.delete)
    }
    
}


public extension ZMConversationMessage {

    var canBeLiked: Bool {
        guard let conversation = self.conversation, let moc = (self as? ZMMessage)?.managedObjectContext else {
            return false
        }

        let participatesInConversation = conversation.activeParticipants.contains(ZMUser.selfUser(in: moc))
        let sentOrDelivered = [ZMDeliveryState.sent, ZMDeliveryState.delivered].contains(deliveryState)
        let likableType = Message.isNormal(self) && !Message.isKnock(self)
        return participatesInConversation && sentOrDelivered && likableType && !isObfuscated && !isEphemeral
    }

    var liked: Bool {
        set {
            if newValue {
                ZMMessage.addReaction(.like, toMessage: self)
            }
            else {
                ZMMessage.removeReaction(onMessage: self)
            }
        }

        get {
            guard let moc = (self as? ZMMessage)?.managedObjectContext else { return false }
            return likers().contains(.selfUser(in: moc))
        }
    }

    func hasReactions() -> Bool {
        return self.usersReaction.map { (_, users) in
            return users.count
            }.reduce(0, +) > 0
    }

    func likers() -> [ZMUser] {
        return usersReaction.filter { (reaction, _) -> Bool in
            reaction == MessageReaction.like.unicodeValue
            }.map { (_, users) in
                return users
            }.first ?? []
    }
    
}
