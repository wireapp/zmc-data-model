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
    
    static func changeInfo(for conversation: ZMConversation, changedKeys: [String : NSObject?]) -> ConversationChangeInfo? {
        guard changedKeys.count > 0 else { return nil }
        let changeInfo = ConversationChangeInfo(object: conversation)
        changeInfo.changedKeysAndOldValues = changedKeys
        return changeInfo
    }
    
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
                let changeInfo = note.userInfo?["changeInfo"] as? UserChangeInfo
            else { return }
            
            observer.userDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for user: ZMUser?) {
        NotificationCenter.default.removeObserver(observer, name: .UserChange, object: user)
    }
    
    public static func add(searchUserObserver observer: ZMUserObserver,
                           for user: ZMSearchUser,
                           inManagedObjectContext context: NSManagedObjectContext) -> NSObjectProtocol
    {
        context.searchUserObserverCenter.addSearchUser(user)
        return NotificationCenter.default.addObserver(forName: .SearchUserChange,
                                                      object: user,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? UserChangeInfo
                else { return }
            
            observer.userDidChange(changeInfo)
        }
    }
    
    public static func remove(searchUserObserver observer: NSObjectProtocol,
                              for user: ZMSearchUser)
    {
        // TODO Sabine: how do we remove searchUser that are no longer observed? on searchDirectory teardown?
        NotificationCenter.default.removeObserver(observer, name: .SearchUserChange, object: user)
    }
    
}

extension MessageChangeInfo {
    
    public static func add(observer: ZMMessageObserver, for message: ZMMessage) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .MessageChange,
                                                      object: message,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? MessageChangeInfo
            else { return }
            
            observer.messageDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for message: ZMMessage?) {
        NotificationCenter.default.removeObserver(observer, name: .MessageChange, object: message)
    }
}

extension ObjectChangeInfo {
    
}

extension UserClientChangeInfo {
    
    static func changeInfo(for client: UserClient, changedKeys: [String : NSObject?]) -> UserClientChangeInfo? {
        guard changedKeys.count > 0 else { return nil }
        let changeInfo = UserClientChangeInfo(object: client)
        changeInfo.changedKeysAndOldValues = changedKeys
        return changeInfo
    }
    
    public static func add(observer: UserClientObserver, for client: UserClient) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .UserClientChange,
                                                      object: client,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? UserClientChangeInfo
            else { return }
            
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
                  let changeInfo = note.userInfo?["changeInfo"] as? NewUnreadMessagesChangeInfo
            else { return }
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
                  let changeInfo = note.userInfo?["changeInfo"] as? NewUnreadKnockMessagesChangeInfo
            else { return }
            observer.didReceiveNewUnreadKnockMessages(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer, name: .NewUnreadKnock, object: nil)
    }
}

extension NewUnreadUnsentMessageChangeInfo {
    public static func add(observer: ZMNewUnreadUnsentMessageObserver) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .NewUnreadUnsentMessage,
                                                      object: nil,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? NewUnreadUnsentMessageChangeInfo
            else { return }
            observer.didReceiveNewUnreadUnsentMessages(changeInfo)
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
                let changeInfo = note.userInfo?["changeInfo"] as? VoiceChannelStateChangeInfo
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
                  let changeInfo = note.userInfo?["changeInfo"] as? VoiceChannelParticipantsChangeInfo
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

extension ConversationListChangeInfo {
    
    public static func add(observer: ZMConversationListObserver,for list: ZMConversationList) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .ZMConversationListDidChange,
                                                      object: list,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer, let list = note.object as? ZMConversationList
            else { return }
            
            if let changeInfo = note.userInfo?["conversationListChangeInfo"] as? ConversationListChangeInfo{
                observer.conversationListDidChange(changeInfo)
            }
            if let changeInfo = note.userInfo?["conversationChangeInfo"] as? ConversationChangeInfo {
                observer.conversation?(inside: list, didChange: changeInfo)
            }
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for list: ZMConversationList?) {
        NotificationCenter.default.removeObserver(observer, name: .ZMConversationListDidChange, object: list)
    }
}
