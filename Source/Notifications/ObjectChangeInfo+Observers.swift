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
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.ConversationChangeNotification,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changedKeysAndValues = note.userInfo?[ChangedKeysAndNewValuesKey] as? [String : NSObject?]
                else { return }
            
            let changeInfo = ConversationChangeInfo(object: conversation)
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            observer.conversationDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation?) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.ConversationChangeNotification, object: conversation)
    }
}

extension UserChangeInfo {
    
    public static func add(observer: ZMUserObserver, for user: ZMUser) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.UserChangeNotification,
                                                      object: user,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changedKeysAndValues = note.userInfo?[ChangedKeysAndNewValuesKey] as? [String : NSObject?]
                else { return }
            
            let changeInfo = UserChangeInfo(object: user)
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            if let clientChanges = changedKeysAndValues["clientChanges"] as? [NSObject : [String : Any]] {
                clientChanges.forEach {
                    let userClientInfo = UserClientChangeInfo(object: $0)
                    userClientInfo.changedKeysAndOldValues = $1 as! [String : NSObject?]
                    changeInfo.userClientChangeInfo = userClientInfo
                }
            }
            observer.userDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for user: ZMUser?) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.UserChangeNotification, object: user)
    }
}

extension MessageChangeInfo {
    
    public static func add(observer: ZMMessageObserver, for message: ZMMessage) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.MessageChangeNotification,
                                                      object: message,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
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
                    let changeInfo = UserChangeInfo(object: $0)
                    changeInfo.changedKeysAndOldValues = $1 as! [String : NSObject?]
                    if (changeInfo.nameChanged            || changeInfo.accentColorValueChanged ||
                        changeInfo.imageMediumDataChanged || changeInfo.imageSmallProfileDataChanged)
                    {
                        userChangeInfo = changeInfo
                    }
                }
            }
            guard reactionChangeInfo != nil || userChangeInfo != nil || changedKeysAndValues.count > 0 else { return }
            
            let changeInfo = MessageChangeInfo(object: message)
            changeInfo.reactionChangeInfo = reactionChangeInfo
            changeInfo.userChangeInfo = userChangeInfo
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            observer.messageDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for message: ZMMessage?) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.MessageChangeNotification, object: message)
    }
}



extension UserClientChangeInfo {
    
    public static func add(observer: UserClientObserver, for client: UserClient) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.UserClientChangeNotification,
                                                      object: client,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changedKeysAndValues = note.userInfo?[ChangedKeysAndNewValuesKey] as? [String : NSObject?]
                else { return }
            
            let changeInfo = UserClientChangeInfo(object: client)
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            observer.userClientDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for client: UserClient?) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.UserClientChangeNotification, object: client)
    }
}

extension NewUnreadMessagesChangeInfo {
    public static func add(observer: ZMNewUnreadMessagesObserver) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.NewUnreadMessageNotification,
                                                      object: nil,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer else { return }
            
            let changeInfo = NewUnreadMessagesChangeInfo(messages: note.object as! [ZMConversationMessage])
            observer.didReceiveNewUnreadMessages(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.NewUnreadMessageNotification, object: nil)
    }
}

extension NewUnreadKnockMessagesChangeInfo {
    public static func add(observer: ZMNewUnreadKnocksObserver) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.NewUnreadKnockNotification,
                                                      object: nil,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer else { return }
            
            let changeInfo = NewUnreadKnockMessagesChangeInfo(object: note.object as! NSObject)
            observer.didReceiveNewUnreadKnockMessages(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.NewUnreadKnockNotification, object: nil)
    }
}

extension VoiceChannelStateChangeInfo {
    public static func add(observer: ZMVoiceChannelStateObserver, for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.VoiceChannelStateChangeNotification,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["voiceChannelStateChangeInfo"] as? VoiceChannelStateChangeInfo
            else { return }
            
            observer.voiceChannelStateDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.VoiceChannelStateChangeNotification, object: conversation)
    }
}

extension VoiceChannelParticipantsChangeInfo {
    public static func add(observer: ZMVoiceChannelParticipantsObserver,for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.VoiceChannelParticipantStateChangeNotification,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                  let changeInfo = note.userInfo?["voiceChannelParticipantsChangeInfo"] as? VoiceChannelParticipantsChangeInfo
            else { return }
            observer.voiceChannelParticipantsDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.VoiceChannelParticipantStateChangeNotification, object: conversation)
    }
}
