//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

fileprivate extension ZMConversationMessage {
    
    var serverTimestampIncludingChildMessages: Date? {
        
        if let systemMessage = self as? ZMSystemMessage {
            return systemMessage.lastChildMessageDate
        }
        
        return serverTimestamp
    }
    
}

extension ZMConversation {
    
    // MARK: - Timestamps
    
    func updatePendingLastRead(_ timestamp: Date) {
        if timestamp > pendingLastReadServerTimestamp {
            pendingLastReadServerTimestamp = timestamp
        }
    }
    
    @objc
    func updateLastRead(_ timestamp: Date, synchronize: Bool = false) {
        guard let managedObjectContext = managedObjectContext else { return }
        
        if timestamp > lastReadServerTimeStamp {
            lastReadServerTimeStamp = timestamp
            
            // modified keys are set "automatically" on the uiMOC
            if managedObjectContext.zm_isSyncContext {
                setLocallyModifiedKeys(Set([ZMConversationLastReadServerTimeStampKey]))
            }
            
            NotificationInContext(name: ZMConversation.lastReadDidChangeNotificationName, context: managedObjectContext.notificationContext, object: self, userInfo: nil).post()
        }
    }
    
    @objc
    public func updateLastModified(_ timestamp: Date) {
        if timestamp > lastModifiedDate {
            lastModifiedDate = timestamp
        }
    }
    
    @objc
    func updateServerModified(_ timestamp: Date) {
        if timestamp > lastServerTimeStamp {
            lastServerTimeStamp = timestamp
        }
    }
    
    func updateLastUnreadKnock(_ timestamp: Date?) {
        guard let timestamp = timestamp else { return lastUnreadKnockDate = nil }
        
        if timestamp > lastUnreadKnockDate {
            lastUnreadKnockDate = timestamp
        }
    }
    
    func updateLastUnreadMissedCall(_ timestamp: Date?) {
        guard let timestamp = timestamp else { return lastUnreadMissedCallDate = nil }
        
        if timestamp > lastUnreadMissedCallDate {
            lastUnreadMissedCallDate = timestamp
        }
    }
    
    // MARK: - Update timestamps on messages events
    
    /// Update timetamps after an message has been updated or created from an update event
    @objc
    func updateTimestampsAfterUpdatingMessage(_ message: ZMMessage) {
        if let timestamp = message.serverTimestamp {
            print("Setting converation server timestamp = \(timestamp) (\(timestamp.transportString())")
            updateServerModified(timestamp)
        }
        
        updateTimestampsAfterInsertingMessage(message)
    }
    
    /// Update timetamps after an message has been inserted locally by the self user
    @objc
    func updateTimestampsAfterInsertingMessage(_ message: ZMMessage) {
        guard let timestamp = message.serverTimestamp else { return }
        
        if message.shouldGenerateUnreadCount() {
            updateLastModified(timestamp)
        }

        if let sender = message.sender, sender.isSelfUser {
            // if the message was sent by the self user we don't want to send a lastRead event, since we consider this message to be already read
            updateLastRead(timestamp, synchronize: false)
        }

        calculateLastUnreadMessages()
    }
    
    /// Update timetamps after an message has been deleted
    @objc
    func updateTimestampsAfterDeletingMessage() {
        // If an unread message is deleted we must re-calculate the unread messages.
        calculateLastUnreadMessages()
    }
    
    // MARK: - Mark as read
    
    @objc(markMessagesAsReadFrom:to:)
    public func markMessagesAsRead(from: ZMConversationMessage, to: ZMConversationMessage) {
        
        guard let timestamp = [from.serverTimestampIncludingChildMessages, to.serverTimestampIncludingChildMessages].compactMap({ $0 }).max() else { return }
        
        enqueueUpdateLastRead(timestamp)
        
        // Any unsent unread message is cleared when entering a conversation
        if hasUnreadUnsentMessage {
            hasUnreadUnsentMessage = false
        }
    }
    
    /// Update the last read timestamp.
    ///
    /// NOTE: This method only has an effect when called from the UI context and it's throttled so it's fine to call it repeatedly.
    func enqueueUpdateLastRead(_ timestamp: Date) {
        guard let managedObjectContext = managedObjectContext, managedObjectContext.zm_isUserInterfaceContext else { return }
        
        updatePendingLastRead(timestamp)
        lastReadTimestampUpdateCounter += 1
        let currentCount: Int64 = lastReadTimestampUpdateCounter
        let groups = managedObjectContext.enterAllGroups()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + lastReadTimestampSaveDelay) { [weak self] in
            guard currentCount == self?.lastReadTimestampUpdateCounter else { return managedObjectContext.leaveAllGroups(groups) }
            
            self?.savePendingLastRead()
            managedObjectContext.leaveAllGroups(groups)
        }
    }
    
    @objc
    func savePendingLastRead() {
        guard let timestamp = pendingLastReadServerTimestamp else { return }
        updateLastRead(timestamp, synchronize: false)
        pendingLastReadServerTimestamp = nil
        lastReadTimestampUpdateCounter = 0
        managedObjectContext?.enqueueDelayedSave()
    }
    
    /// Mark all messages in the conversation as read
    @objc
    public func markAsRead() {
        guard let timestamp = lastServerTimeStamp else { return }
        
        enqueueUpdateLastRead(timestamp)
    }
    
    /// Calculates the the last unread knock, missed call and total unread unread count. This should be re-calculated
    /// when the last read timetamp changes or a message is inserted / deleted.
    @objc
    func calculateLastUnreadMessages() {
        guard let managedObjectContext = managedObjectContext else { return }
        guard managedObjectContext.zm_isSyncContext else { return } // We only calculate unread message on the sync MOC
        
        // TODO jacob handle child messages which are hidden
        
        let lastReadServerTimestamp = lastReadServerTimeStamp ?? Date.distantPast
        let selfUser = ZMUser.selfUser(in: managedObjectContext)
        let fetchRequest = NSFetchRequest<ZMMessage>(entityName: ZMMessage.entityName())
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K != %@ AND %K > %@",
                                             ZMMessageConversationKey, self,
                                             ZMMessageSenderKey, selfUser,
                                             ZMMessageServerTimestampKey, lastReadServerTimestamp as NSDate)
        fetchRequest.sortDescriptors = ZMMessage.defaultSortDescriptors()
        
        let messages = managedObjectContext.fetchOrAssert(request: fetchRequest)
        var lastKnockDate: Date? = nil
        var lastMissedCallDate: Date? = nil
        var unreadCount: Int64 = 0
        
        for message in messages {
            if message.isKnock {
                lastKnockDate = message.serverTimestamp
            }
            
            if message.isSystem, let systemMessage = message as? ZMSystemMessage, systemMessage.systemMessageType == .missedCall {
                lastMissedCallDate = message.serverTimestamp
            }
            
            if message.shouldGenerateUnreadCount() {
                unreadCount += 1
            }
        }
        
        updateLastUnreadKnock(lastKnockDate)
        updateLastUnreadMissedCall(lastMissedCallDate)
        internalEstimatedUnreadCount = unreadCount
    }
    
    @objc
    public var firstUnreadMessage: ZMConversationMessage? {
        guard let managedObjectContext = managedObjectContext else { return nil }
        
        // TODO jacob this code is duplicated in calculateLastUnreadMessages
        let lastReadServerTimestamp = lastReadServerTimeStamp ?? Date.distantPast
        let selfUser = ZMUser.selfUser(in: managedObjectContext)
        let fetchRequest = NSFetchRequest<ZMMessage>(entityName: ZMMessage.entityName())
        fetchRequest.predicate = NSPredicate(format: "(%K == %@ OR %K == %@) AND %K != %@ AND %K > %@",
                                             ZMMessageConversationKey, self,
                                             ZMMessageHiddenInConversationKey, self,
                                             ZMMessageSenderKey, selfUser,
                                             ZMMessageServerTimestampKey, lastReadServerTimestamp as NSDate)
        fetchRequest.sortDescriptors = ZMMessage.defaultSortDescriptors()
        
        let replaceChildWithParent: (ZMMessage) -> ZMMessage = { message in
            if let systemMessage = message as? ZMSystemMessage, let parentMessage = systemMessage.parentMessage as? ZMMessage {
                return parentMessage
            } else {
                return message
            }
        }
        
        let messages = managedObjectContext.fetchOrAssert(request: fetchRequest)
        return messages.lazy.map(replaceChildWithParent).filter({ $0.visibleInConversation != nil }).first(where: { $0.shouldGenerateUnreadCount() })
    }
    
    @objc
    public var unreadMessages: [ZMConversationMessage] {
        guard let managedObjectContext = managedObjectContext else { return [] }
        
        let lastReadServerTimestamp = lastReadServerTimeStamp ?? Date.distantPast
        let fetchRequest = NSFetchRequest<ZMMessage>(entityName: ZMMessage.entityName())
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K > %@", ZMMessageConversationKey, self, ZMMessageServerTimestampKey, lastReadServerTimestamp as NSDate)
        fetchRequest.sortDescriptors = ZMMessage.defaultSortDescriptors()
        
        return managedObjectContext.fetchOrAssert(request: fetchRequest)
    }
    
}
