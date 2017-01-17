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

extension Notification.Name {
    
    static let ZMConversationMessageWindowScrolled = Notification.Name("ZMConversationMessageWindowScrolledNotification")
    static let ZMConversationMessageWindowCreated = Notification.Name("ZMConversationMessageWindowCreatedNotification")
    static let MessageWindowDidChange = Notification.Name("MessageWindowDidChangeNotification")

}


final class MessageWindowObserverCenter : NSObject {
    
    var windowSnapshot : MessageWindowSnapshot?
    var tornDown = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(MessageWindowObserverCenter.windowDidScroll(_:)), name:  .ZMConversationMessageWindowScrolled, object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MessageWindowObserverCenter.windowWasCreated(_:)), name:  .ZMConversationMessageWindowCreated, object:nil)
    }
    
    func tearDown() {
        NotificationCenter.default.removeObserver(self)
        tornDown = true
    }
    
    deinit {
        assert(tornDown, "Did not tear down MessageWindowObserver")
    }
    
    @objc public func windowDidScroll(_ note: Notification) {
        guard let notifyingWindow = note.object as? ZMConversationMessageWindow else { return }
        if let snapshot = windowSnapshot, snapshot.conversation == notifyingWindow.conversation {
            snapshot.windowDidScroll()
        } else {
            windowSnapshot?.tearDown()
            windowSnapshot = MessageWindowSnapshot(window: notifyingWindow)
        }
    }
    
    // TODO Sabine: this is pretty hacky
    @objc public func windowWasCreated(_ note: Notification) {
        guard let notifyingWindow = note.object as? ZMConversationMessageWindow else { return }
        if let snapshot = windowSnapshot, snapshot.conversation == notifyingWindow.conversation {
            return
        }
        windowSnapshot?.tearDown()
        windowSnapshot = MessageWindowSnapshot(window: notifyingWindow)
    }
    
    func fireNotifications() {
        windowSnapshot?.fireNotifications()
    }
}


class MessageWindowSnapshot : NSObject, ZMConversationObserver, ZMMessageObserver {

    fileprivate var state : SetSnapshot
    // TODO Sabine : we could probably speed things up by forwarding the changeInfos directly
    fileprivate var conversationToken : NSObjectProtocol!
    
    public let conversationWindow : ZMConversationMessageWindow
    fileprivate var conversation : ZMConversation {
        return conversationWindow.conversation
    }
    
    fileprivate var shouldRecalculate : Bool = false
    fileprivate var updatedMessages : [ZMMessage] = []
    fileprivate var messageChangeInfos : [MessageChangeInfo] = []
    
    // TODO Sabine : we could probably speed things up by forwarding the changeInfos directly
    fileprivate var messageTokens: [ZMMessage : NSObjectProtocol] = [:]
    
    public var isTornDown : Bool = false
    
    fileprivate var currentlyFetchingMessages = false
    
    public init(window: ZMConversationMessageWindow) {
        
        self.conversationWindow = window
        self.state = SetSnapshot(set: conversationWindow.messages, moveType: .uiCollectionView)
        
        super.init()
        
        self.conversationToken = ConversationChangeInfo.add(observer: self, for: conversation)
        self.registerObserversForMessages(window.messages)
    }
    
    public func tearDown() {
        ConversationChangeInfo.remove(observer: conversationToken, for: conversation)
        conversationToken = nil
        messageTokens.forEach {
            MessageChangeInfo.remove(observer: $1, for: $0)
        }
        self.messageTokens = [:]
        self.updatedMessages = []
        isTornDown = true
    }
    
    deinit {
        self.tearDown()
    }
    
    public func windowDidScroll() {
        self.computeChanges()
    }
    
    public func fireNotifications() {
        if(self.shouldRecalculate || self.updatedMessages.count > 0) {
            self.computeChanges()
        }
    }
    
    public func conversationDidChange(_ changeInfo: ConversationChangeInfo) {
        if(changeInfo.messagesChanged || changeInfo.clearedChanged) {
            self.shouldRecalculate = true
        }
    }
    
    public func computeChanges() {
        let currentlyUpdatedMessages = self.updatedMessages
        
        self.updatedMessages = []
        self.shouldRecalculate = false
        
        let updatedSet = NSOrderedSet(array: currentlyUpdatedMessages.filter({
            $0.conversation === self.conversationWindow.conversation}))
        
        conversationWindow.recalculateMessages()
        
        var changeInfo : MessageWindowChangeInfo?
        if let newStateUpdate = self.state.updatedState(updatedSet, observedObject: self.conversationWindow, newSet: self.conversationWindow.messages) {
            self.state = newStateUpdate.newSnapshot
            changeInfo = MessageWindowChangeInfo(setChangeInfo: newStateUpdate.changeInfo)
            
            let a = newStateUpdate.insertedObjects
            self.registerObserversForMessages(a)
            let b = newStateUpdate.removedObjects
            self.removeObserverForMessages(b)
        }
        
        var userInfo = [String : Any]()
        if self.messageChangeInfos.count > 0 {
            userInfo["messageChangeInfos"] = self.messageChangeInfos
        }
        if let changeInfo = changeInfo {
            userInfo["messageWindowChangeInfo"] = changeInfo
        }
        NotificationCenter.default.post(name: .MessageWindowDidChange, object: conversationWindow, userInfo: userInfo)
        
        self.messageChangeInfos = []
    }
    
    fileprivate func registerObserversForMessages(_ messages: NSOrderedSet) {
        messages.forEach{
            guard let message = $0 as? ZMMessage, message.managedObjectContext != nil else {return }
            self.messageTokens[message] = MessageChangeInfo.add(observer:self, for: message)
        }
    }
    
    fileprivate func removeObserverForMessages(_ messages: NSOrderedSet) {
        messages.forEach{
            guard let message = $0 as? ZMMessage else {return }
            if let token = self.messageTokens.removeValue(forKey: message) {
                MessageChangeInfo.remove(observer: token, for: message)
            }
        }
    }
    
    public func messageDidChange(_ change: MessageChangeInfo) {
        self.updatedMessages.append(change.message)
        self.messageChangeInfos.append(change)
    }
}

