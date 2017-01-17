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


extension ConversationChangeInfo {
    
    public static func add(observer: ZMConversationObserver, for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .ConversationChange,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let object = note.object as? ZMConversation,
                let changedKeysAndValues = note.userInfo?[ChangedKeysAndNewValuesKey] as? [String : NSObject?]
                else { return }
            
            let changeInfo = ConversationChangeInfo(object: object)
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            observer.conversationDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation?) {
        NotificationCenter.default.removeObserver(observer, name: .ConversationChange, object: conversation)
    }
}

extension UserChangeInfo {
    
    public static func add(observer: ZMUserObserver, for user: ZMUser) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .UserChange,
                                                      object: user,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let object = note.object as? ZMUser,
                let changes = note.userInfo?[ChangedKeysAndNewValuesKey] as? [String : NSObject?]
                else { return }
            
            var changedKeysAndValues = changes
            let clientChanges = changedKeysAndValues.removeValue(forKey: "clientChanges") as? [NSObject : [String : Any]]
            
            var userClientChangeInfo : UserClientChangeInfo?
            if let clientChanges = clientChanges {
                clientChanges.forEach {
                    userClientChangeInfo = UserClientChangeInfo(object: $0)
                    userClientChangeInfo?.changedKeysAndOldValues = $1 as! [String : NSObject?]
                }
            }
            guard userClientChangeInfo != nil || changedKeysAndValues.count > 0 else { return }
            
            let changeInfo = UserChangeInfo(object: object)
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            changeInfo.userClientChangeInfo = userClientChangeInfo
            observer.userDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for user: ZMUser?) {
        NotificationCenter.default.removeObserver(observer, name: .UserChange, object: user)
    }
}

extension MessageChangeInfo {
    
    public static func add(observer: ZMMessageObserver, for message: ZMMessage) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .MessageChange,
                                                      object: message,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let object = note.object as? ZMMessage,
                let changes = note.userInfo?[ChangedKeysAndNewValuesKey] as? [String : NSObject?]
                else { return }
            var changedKeysAndValues = changes
            let userChanges = changedKeysAndValues.removeValue(forKey: "userChanges") as? [NSObject : [String : Any]]
            let clientChanges = changedKeysAndValues.removeValue(forKey: "reactionChanges") as? [NSObject : [String : Any]]
            
            var reactionChangeInfo : ReactionChangeInfo?
            if let clientChanges = clientChanges {
                clientChanges.forEach {
                    reactionChangeInfo = ReactionChangeInfo(object: $0)
                    reactionChangeInfo?.changedKeysAndOldValues = $1 as! [String : NSObject?]
                }
            }
            var userChangeInfo : UserChangeInfo?
            if let userChanges = userChanges {
                userChanges.forEach {
                    userChangeInfo = UserChangeInfo(object: $0)
                    userChangeInfo?.changedKeysAndOldValues = $1 as! [String : NSObject?]
                }
            }
            guard reactionChangeInfo != nil || userChangeInfo != nil || changedKeysAndValues.count > 0 else { return }
            
            let changeInfo = MessageChangeInfo(object: object)
            changeInfo.reactionChangeInfo = reactionChangeInfo
            changeInfo.userChangeInfo = userChangeInfo
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            observer.messageDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for message: ZMMessage?) {
        NotificationCenter.default.removeObserver(observer, name: .MessageChange, object: message)
    }
}



extension UserClientChangeInfo {
    
    public static func add(observer: UserClientObserver, for client: UserClient) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .UserClientChange,
                                                      object: client,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let object = note.object as? UserClient,
                let changedKeysAndValues = note.userInfo?[ChangedKeysAndNewValuesKey] as? [String : NSObject?]
                else { return }
            
            let changeInfo = UserClientChangeInfo(object: object)
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            observer.userClientDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for client: UserClient?) {
        NotificationCenter.default.removeObserver(observer, name: .UserClientChange, object: client)
    }
}

extension NewUnreadMessagesChangeInfo {
    public static func add(observer: ZMNewUnreadMessagesObserver) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .NewUnreadMessage,
                                                      object: nil,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                  let object = note.object as? [ZMConversationMessage]
            else { return }
            
            let changeInfo = NewUnreadMessagesChangeInfo(messages: object)
            observer.didReceiveNewUnreadMessages(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer, name: .NewUnreadMessage, object: nil)
    }
}

extension NewUnreadKnockMessagesChangeInfo {
    public static func add(observer: ZMNewUnreadKnocksObserver) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .NewUnreadKnock,
                                                      object: nil,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                  let object = note.object as? [ZMConversationMessage]
            else { return }
            
            let changeInfo = NewUnreadKnockMessagesChangeInfo(messages: object)
            observer.didReceiveNewUnreadKnockMessages(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer, name: .NewUnreadKnock, object: nil)
    }
}

extension VoiceChannelStateChangeInfo {
    public static func add(observer: ZMVoiceChannelStateObserver, for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .VoiceChannelStateChange,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["voiceChannelStateChangeInfo"] as? VoiceChannelStateChangeInfo
            else { return }
            
            observer.voiceChannelStateDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation?) {
        NotificationCenter.default.removeObserver(observer, name: .VoiceChannelStateChange, object: conversation)
    }
}

extension VoiceChannelParticipantsChangeInfo {
    public static func add(observer: ZMVoiceChannelParticipantsObserver,for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .VoiceChannelParticipantStateChange,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                  let changeInfo = note.userInfo?["voiceChannelParticipantsChangeInfo"] as? VoiceChannelParticipantsChangeInfo
            else { return }
            observer.voiceChannelParticipantsDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation?) {
        NotificationCenter.default.removeObserver(observer, name: .VoiceChannelParticipantStateChange, object: conversation)
    }
}


extension MessageWindowChangeInfo {
    public static func add(observer: ZMConversationMessageWindowObserver,for window: ZMConversationMessageWindow) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .MessageWindowDidChange,
                                                      object: window,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer
            else { return }
            if let changeInfo = note.userInfo?["messageWindowChangeInfo"] as? MessageWindowChangeInfo{
                observer.conversationWindowDidChange(changeInfo)
            }
            if let messageChangeInfos = note.userInfo?["messageChangeInfos"] as? [MessageChangeInfo] {
                observer.messages?(insideWindowDidChange: messageChangeInfos)
            }
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for window: ZMConversationMessageWindow?) {
        NotificationCenter.default.removeObserver(observer, name: .MessageWindowDidChange, object: window)
    }
}
