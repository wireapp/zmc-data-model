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
        if let observer = userInfo[MessageWindowObserverCenterKey] as? MessageWindowObserverCenter {
            return observer
        }
        
        let newObserver = MessageWindowObserverCenter()
        userInfo[MessageWindowObserverCenterKey] = newObserver
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
    
    func userDidChange(changeInfo: UserChangeInfo) {
        windowSnapshot?.userDidChange(changeInfo: changeInfo)
    }
    
    func fireNotifications() {
        windowSnapshot?.fireNotifications()
    }
}


class MessageWindowSnapshot : NSObject, ZMConversationObserver, ZMMessageObserver {

    fileprivate var state : SetSnapshot
    
    public weak var conversationWindow : ZMConversationMessageWindow?
    fileprivate var conversation : ZMConversation? {
        return conversationWindow?.conversation
    }
    
    fileprivate var shouldRecalculate : Bool = false
    fileprivate var updatedMessages : [ZMMessage] = []
    fileprivate var messageChangeInfos : [MessageChangeInfo] = []
    fileprivate var userChanges: [NSManagedObjectID : UserChangeInfo] = [:]
    fileprivate var userIDsInWindow : Set<NSManagedObjectID> = Set()
    
    var isTornDown : Bool = false
    
    fileprivate var currentlyFetchingMessages = false
    
    init(window: ZMConversationMessageWindow) {
        self.conversationWindow = window
        self.state = SetSnapshot(set: window.messages, moveType: .uiCollectionView)
        super.init()
    }
    
    func tearDown() {
        if isTornDown { return }
        updatedMessages = []
        isTornDown = true
    }
    
    deinit {
        tearDown()
    }
    
    func windowDidScroll() {
        computeChanges()
    }
    
    func fireNotifications() {
        if(shouldRecalculate || updatedMessages.count > 0) {
            computeChanges()
        }
        userChanges = [:]
    }
    
    func conversationDidChange(_ changeInfo: ConversationChangeInfo) {
        guard let conversation = conversation, changeInfo.conversation == conversation else { return }
        if(changeInfo.messagesChanged || changeInfo.clearedChanged) {
            shouldRecalculate = true
        }
    }
    
    func messageDidChange(_ change: MessageChangeInfo) {
        guard let window = conversationWindow, window.messages.contains(change.message) else { return }
        
        updatedMessages.append(change.message)
        messageChangeInfos.append(change)
    }

    func userDidChange(changeInfo: UserChangeInfo) {
        guard let user = changeInfo.user as? ZMUser,
             (changeInfo.nameChanged || changeInfo.accentColorValueChanged || changeInfo.imageMediumDataChanged || changeInfo.imageSmallProfileDataChanged)
        else { return }
        
        guard userIDsInWindow.contains(user.objectID) else { return }
        
        userChanges[user.objectID] = changeInfo
        shouldRecalculate = true
    }
    
    func computeChanges() {
        guard let window = conversationWindow else { return }

        let currentlyUpdatedMessages = updatedMessages
        
        updatedMessages = []
        shouldRecalculate = false
        
        let updatedSet = NSOrderedSet(array: currentlyUpdatedMessages.filter({$0.conversation === window.conversation}))
        window.recalculateMessages()
        
        userIDsInWindow = (window.messages.array as? [ZMMessage] ?? []).reduce(Set()){$0.union($1.allUserIDs)}
        
        var changeInfo : MessageWindowChangeInfo?
        if let newStateUpdate = state.updatedState(updatedSet, observedObject: window, newSet: window.messages) {
            state = newStateUpdate.newSnapshot
            changeInfo = MessageWindowChangeInfo(setChangeInfo: newStateUpdate.changeInfo)
        }
        
        messageChangeInfos.forEach{
            if let user = $0.message.sender, let userChange = userChanges.removeValue(forKey:user.objectID) {
                $0.changedKeysAndOldValues["userChanges"] = userChange
            }
        }
        if userChanges.count > 0, let messages = window.messages.array as? [ZMMessage] {
            let messagesToUserIDs = messages.mapToDictionary{$0.allUserIDs}

            userChanges.forEach{ (objectID, change) in
                let messages : [ZMMessage] = messagesToUserIDs.reduce([]){$1.value.contains(objectID) ? ($0 + [$1.key]) : $0}
                messages.forEach{
                    let changeInfo = MessageChangeInfo(object: $0)
                    changeInfo.changedKeysAndOldValues["userChanges"] = change
                    messageChangeInfos.append(changeInfo)
                }
            }
        }
        
        var userInfo = [String : Any]()
        if messageChangeInfos.count > 0 {
            userInfo["messageChangeInfos"] = messageChangeInfos
        }
        if let changeInfo = changeInfo {
            userInfo["messageWindowChangeInfo"] = changeInfo
        }
        NotificationCenter.default.post(name: .MessageWindowDidChange, object: window, userInfo: userInfo)
        
        messageChangeInfos = []
    }
}

extension ZMSystemMessage {

    override var allUserIDs : Set<NSManagedObjectID> {
        let allIDs = super.allUserIDs
        return allIDs.union((users.union(addedUsers).union(removedUsers)).map{$0.objectID})
    }
}

extension ZMMessage {
    
    var allUserIDs : Set<NSManagedObjectID> {
        guard let sender = sender else { return Set()}
        return Set([sender.objectID])
    }
}

