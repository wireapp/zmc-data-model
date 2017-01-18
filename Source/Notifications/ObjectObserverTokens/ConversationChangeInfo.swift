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


extension ZMConversation : ObjectInSnapshot {
    
    public static var observableKeys : [String] {
        return ["messages", "lastModifiedDate", "isArchived", "conversationListIndicator", "voiceChannelState", "activeFlowParticipants", "callParticipants", "isSilenced", SecurityLevelKey, "otherActiveVideoCallParticipants", "displayName", "estimatedUnreadCount", "clearedTimeStamp", "otherActiveParticipants", "isSelfAnActiveMember", "relatedConnectionState"]
    }

}




////////////////////
////
//// ConversationObserverToken
//// This can be used for observing only conversation properties
////
////////////////////

@objc public final class ConversationChangeInfo : ObjectChangeInfo {
    
    public var messagesChanged : Bool {
        return changedKeysAndOldValues.keys.contains("messages")
    }

    public var participantsChanged : Bool {
        return !Set(arrayLiteral: "otherActiveParticipants", "isSelfAnActiveMember").isDisjoint(with: changedKeysAndOldValues.keys)
    }

    public var nameChanged : Bool {
        return changedKeysAndOldValues.keys.contains{$0 == "displayName" || $0 == "userDefinedName"}
    }

    public var lastModifiedDateChanged : Bool {
        return changedKeysAndOldValues.keys.contains("lastModifiedDate")
    }

    public var unreadCountChanged : Bool {
        return changedKeysAndOldValues.keys.contains("estimatedUnreadCount")
    }

    public var connectionStateChanged : Bool {
        return changedKeysAndOldValues.keys.contains("relatedConnectionState")
    }

    public var isArchivedChanged : Bool {
        return changedKeysAndOldValues.keys.contains("isArchived")
    }

    public var isSilencedChanged : Bool {
        return changedKeysAndOldValues.keys.contains("isSilenced")
    }

    public var conversationListIndicatorChanged : Bool {
        return changedKeysAndOldValues.keys.contains("conversationListIndicator")
    }

    public var voiceChannelStateChanged : Bool {
        return changedKeysAndOldValues.keys.contains("voiceChannelState")
    }

    public var clearedChanged : Bool {
        return changedKeysAndOldValues.keys.contains("clearedTimeStamp")
    }

    public var securityLevelChanged : Bool {
        return changedKeysAndOldValues.keys.contains(SecurityLevelKey)
    }
    
    var callParticipantsChanged : Bool {
        return changedKeysAndOldValues.keys.contains{$0 == "activeFlowParticipants" || $0 == "callParticipants" || $0 == "otherActiveVideoCallParticipants"}
    }
    
    var videoParticipantsChanged : Bool {
        return changedKeysAndOldValues.keys.contains("otherActiveVideoCallParticipants")
    }
    
    public var conversation : ZMConversation { return self.object as! ZMConversation }
    
    public override var description : String { return self.debugDescription }
    public override var debugDescription : String {
        return "messagesChanged: \(messagesChanged)," +
        "participantsChanged: \(participantsChanged)," +
        "nameChanged: \(nameChanged)," +
        "unreadCountChanged: \(unreadCountChanged)," +
        "lastModifiedDateChanged: \(lastModifiedDateChanged)," +
        "connectionStateChanged: \(connectionStateChanged)," +
        "isArchivedChanged: \(isArchivedChanged)," +
        "isSilencedChanged: \(isSilencedChanged)," +
        "conversationListIndicatorChanged \(conversationListIndicatorChanged)," +
        "voiceChannelStateChanged \(voiceChannelStateChanged)," +
        "clearedChanged \(clearedChanged)," +
        "securityLevelChanged \(securityLevelChanged),"
    }
    
    public required init(object: NSObject) {
        super.init(object: object)
    }
}


/// Conversation degraded
extension ConversationChangeInfo {

    /// Gets the last system message with new clients in the conversation.
    /// If last system message is of the wrong type, it returns nil.
    /// It will search past non-security related system messages, as someone
    /// might have added a participant or renamed the conversation (causing a
    /// system message to be inserted)
    fileprivate var recentNewClientsSystemMessageWithExpiredMessages : ZMSystemMessage? {
        let previousSecurityLevel = (self.previousValueForKey(SecurityLevelKey) as? NSNumber).flatMap { ZMConversationSecurityLevel(rawValue: $0.int16Value) }
        if(!self.securityLevelChanged || self.conversation.securityLevel != .secureWithIgnored || previousSecurityLevel == nil) {
            return .none;
        }
        var foundSystemMessage : ZMSystemMessage? = .none
        var foundExpiredMessage = false
        self.conversation.messages.enumerateObjects(options: NSEnumerationOptions.reverse) { (msg, _, stop) -> Void in
            if let systemMessage = msg as? ZMSystemMessage {
                if systemMessage.systemMessageType == .newClient {
                    foundSystemMessage = systemMessage
                }
                if systemMessage.systemMessageType == .newClient ||
                    systemMessage.systemMessageType == .ignoredClient ||
                    systemMessage.systemMessageType == .conversationIsSecure {
                        stop.pointee = true
                }
            } else if let sentMessage = msg as? ZMMessage , sentMessage.isExpired {
                foundExpiredMessage = true
            }
        }
        return foundExpiredMessage ? foundSystemMessage : .none
    }
    
    /// True if the conversation was just degraded
    public var didDegradeSecurityLevelBecauseOfMissingClients : Bool {
        return self.recentNewClientsSystemMessageWithExpiredMessages != .none
    }
    
    /// Users that caused the conversation to degrade
    public var usersThatCausedConversationToDegrade : Set<ZMUser> {
        if let message = self.recentNewClientsSystemMessageWithExpiredMessages {
            return message.users
        }
        return Set<ZMUser>()
    }
}



