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

//////////////////////////
///
/// NewUnreadMessage
///
//////////////////////////



public final class NewUnreadMessagesChangeInfo : ObjectChangeInfo  {
    
    public convenience init(messages: [ZMConversationMessage]) {
        self.init(object: messages as NSObject)
    }
    
    public var messages : [ZMConversationMessage] {
        return object as? [ZMConversationMessage] ?? []
    }
    
    @objc(addNewMessageObserver:)
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
    
    @objc(removeNewMessageObserver:)
    public static func remove(observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer, name: .NewUnreadMessage, object: nil)
    }
}



//////////////////////////
///
/// NewUnreadKnockMessage
///
//////////////////////////


@objc public final class NewUnreadKnockMessagesChangeInfo : ObjectChangeInfo {
    
    public convenience init(messages: [ZMConversationMessage]) {
        self.init(object: messages as NSObject)
    }
    
    public var messages : [ZMConversationMessage] {
        return object as? [ZMConversationMessage] ?? []
    }
    
    @objc(addNewKnockObserver:)
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
    
    @objc(removeNewKnockObserver:)
    public static func remove(observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer, name: .NewUnreadKnock, object: nil)
    }
}



//////////////////////////
///
/// NewUnreadUndeliveredMessage
///
//////////////////////////


@objc public final class NewUnreadUnsentMessageChangeInfo : ObjectChangeInfo {
    
    public required convenience init(messages: [ZMConversationMessage]) {
        self.init(object: messages as NSObject)
    }
    
    public var messages : [ZMConversationMessage] {
        return  object as? [ZMConversationMessage] ?? []
    }
    
    @objc(addNewUnreadUnsentMessageObserver:)
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
    
    @objc(removeNewUnreadUnsentMessageObserver:)
    public static func remove(observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer, name: .NewUnreadKnock, object: nil)
    }
}

