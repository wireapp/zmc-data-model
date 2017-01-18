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

let MessageWindowObserverCenterKey = "MessageWindowObserverCenterKey"

extension NSManagedObjectContext {
    
    public var messageWindowObserverCenter : MessageWindowObserverCenter {
        if let observer = self.userInfo[MessageWindowObserverCenterKey] as? MessageWindowObserverCenter {
            return observer
        }
        
        let newObserver = MessageWindowObserverCenter()
        self.userInfo[MessageWindowObserverCenterKey] = newObserver
        return newObserver
    }
}

@objc final public class MessageWindowObserverCenter : NSObject {
    
    var windowSnapshot : MessageWindowSnapshot?

    @objc public func windowDidScroll(_ window: ZMConversationMessageWindow) {
        if let snapshot = windowSnapshot, snapshot.conversation == window.conversation {
            snapshot.windowDidScroll()
        } else {
            windowSnapshot?.tearDown()
            windowSnapshot = MessageWindowSnapshot(window: window)
        }
    }
    
    @objc public func windowWasCreated(_ window: ZMConversationMessageWindow) {
        if let snapshot = windowSnapshot, snapshot.conversation == window.conversation {
            return
        }
        windowSnapshot?.tearDown()
        windowSnapshot = MessageWindowSnapshot(window: window)
    }
    
    @objc public func removeMessageWindow(_ window: ZMConversationMessageWindow) {
        if let snapshot = windowSnapshot, snapshot.conversation != window.conversation {
            return
        }
        windowSnapshot?.tearDown()
        windowSnapshot = nil
    }
    
    func conversationDidChange(_ changeInfo: ConversationChangeInfo) {
        windowSnapshot?.conversationDidChange(changeInfo)
    }
    
    func messageDidChange(changeInfo: MessageChangeInfo) {
        windowSnapshot?.messageDidChange(changeInfo)
    }
    
    func fireNotifications() {
        windowSnapshot?.fireNotifications()
    }
}


class MessageWindowSnapshot : NSObject, ZMConversationObserver, ZMMessageObserver {

    fileprivate var state : SetSnapshot
    
    public let conversationWindow : ZMConversationMessageWindow
    fileprivate var conversation : ZMConversation {
        return conversationWindow.conversation
    }
    
    fileprivate var shouldRecalculate : Bool = false
    fileprivate var updatedMessages : [ZMMessage] = []
    fileprivate var messageChangeInfos : [MessageChangeInfo] = []
    
    public var isTornDown : Bool = false
    
    fileprivate var currentlyFetchingMessages = false
    
    public init(window: ZMConversationMessageWindow) {
        self.conversationWindow = window
        self.state = SetSnapshot(set: conversationWindow.messages, moveType: .uiCollectionView)
        super.init()
    }
    
    public func tearDown() {
        if isTornDown { return }
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
        guard changeInfo.conversation == conversationWindow.conversation else { return }
        if(changeInfo.messagesChanged || changeInfo.clearedChanged) {
            self.shouldRecalculate = true
        }
    }
    
    public func messageDidChange(_ change: MessageChangeInfo) {
        guard conversationWindow.messages.contains(change.message) else { return }
        
        self.updatedMessages.append(change.message)
        self.messageChangeInfos.append(change)
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
    
    

}

