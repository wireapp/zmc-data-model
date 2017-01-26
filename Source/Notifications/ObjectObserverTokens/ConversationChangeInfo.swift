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
    
    public static var observableKeys : Set<String> {
        return Set(["messages", "lastModifiedDate", "isArchived", "conversationListIndicator", "voiceChannelState", "activeFlowParticipants", "callParticipants", "isSilenced", SecurityLevelKey, "otherActiveVideoCallParticipants", "displayName", "estimatedUnreadCount", "clearedTimeStamp", "otherActiveParticipants", "isSelfAnActiveMember", "relatedConnectionState"])
    }

}


////////////////////
////
//// ConversationObserverToken
//// This can be used for observing only conversation properties
////
////////////////////

@objc public protocol ZMConversationObserver : NSObjectProtocol {
    func conversationDidChange(_ changeInfo: ConversationChangeInfo)
}


@objc public final class ConversationChangeInfo : ObjectChangeInfo {
    
    public var messagesChanged : Bool {
        return changedKeysContain(keys: "messages")
    }

    public var participantsChanged : Bool {
        return changedKeysContain(keys: "otherActiveParticipants", "isSelfAnActiveMember")
    }

    public var nameChanged : Bool {
        return changedKeysContain(keys: "displayName", "userDefinedName")
    }

    public var lastModifiedDateChanged : Bool {
        return changedKeysContain(keys: "lastModifiedDate")
    }

    public var unreadCountChanged : Bool {
        return changedKeysContain(keys: "estimatedUnreadCount")
    }

    public var connectionStateChanged : Bool {
        return changedKeysContain(keys: "relatedConnectionState")
    }

    public var isArchivedChanged : Bool {
        return changedKeysContain(keys: "isArchived")
    }

    public var isSilencedChanged : Bool {
        return changedKeysContain(keys: "isSilenced")
    }

    public var conversationListIndicatorChanged : Bool {
        return changedKeysContain(keys: "conversationListIndicator")
    }

    public var voiceChannelStateChanged : Bool {
        return changedKeysContain(keys: "voiceChannelState")
    }

    public var clearedChanged : Bool {
        return changedKeysContain(keys: "clearedTimeStamp")
    }

    public var securityLevelChanged : Bool {
        return changedKeysContain(keys: SecurityLevelKey)
    }
    
    var callParticipantsChanged : Bool {
        return changedKeysContain(keys:  "activeFlowParticipants", "callParticipants", "otherActiveVideoCallParticipants")
    }
    
    var videoParticipantsChanged : Bool {
        return changedKeysContain(keys: "otherActiveVideoCallParticipants")
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
    
    static func changeInfo(for conversation: ZMConversation, changes: Changes) -> ConversationChangeInfo? {
        guard changes.changedKeys.count > 0 || changes.originalChanges.count > 0 else { return nil }
        let changeInfo = ConversationChangeInfo(object: conversation)
        changeInfo.changedKeysAndOldValues = changes.originalChanges
        changeInfo.changedKeys = changes.changedKeys
        return changeInfo
    }
}



//@objc public protocol ZMConversationObserverOpaqueToken :NSObjectProtocol {}
extension ConversationChangeInfo {

    @objc(addObserver:forConversation:)
    public static func add(observer: ZMConversationObserver, for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .ConversationChange,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? ConversationChangeInfo
                else { return }
            
            observer.conversationDidChange(changeInfo)
        } 
    }
    
    @objc(removeObserver:forConversation:)
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation?) {
        NotificationCenter.default.removeObserver(observer, name: .ConversationChange, object: conversation)
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
        guard self.conversation.didDegradeSecurityLevel else { return nil }
        var foundSystemMessage : ZMSystemMessage? = .none
        var foundDegradingMessage = false
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
            } else if let sentMessage = msg as? ZMMessage , sentMessage.causedSecurityLevelDegradation {
                foundDegradingMessage = true
            }
        }
        return foundDegradingMessage ? foundSystemMessage : .none
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



