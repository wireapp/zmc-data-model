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

private var zmLog = ZMSLog(tag: "ConversationListObserverCenter")

extension Notification.Name {
    static let StartObservingList = Notification.Name("StartObservingListNotification")
    static let ZMConversationListDidChange = Notification.Name("ZMConversationListDidChangeNotification")
}

let ConversationListObserverCenterKey = "ConversationListObserverCenterKey"

extension NSManagedObjectContext {
    
    public var conversationListObserverCenter : ConversationListObserverCenter? {
        guard zm_isUserInterfaceContext else {
            zmLog.warn("ConversationListObserver does not exist in syncMOC")
            return nil
        }
        
        if let observer = self.userInfo[ConversationListObserverCenterKey] as? ConversationListObserverCenter {
            return observer
        }
        
        let newObserver = ConversationListObserverCenter()
        self.userInfo[ConversationListObserverCenterKey] = newObserver
        return newObserver
    }
}

public class ConversationListObserverCenter : NSObject, ZMConversationObserver {
    
    fileprivate var listSnapshots : [String : ConversationListSnapshot] = [:]
    
    var isTornDown : Bool = false
    
    /// Adds a conversationList to the objects to observe
    @objc public func startObservingList(_ conversationList: ZMConversationList) {
        if listSnapshots[conversationList.identifier] == nil {
            listSnapshots[conversationList.identifier] = ConversationListSnapshot(conversationList: conversationList)
        }
    }
    
    @objc public func recreateSnapshot(for conversationList: ZMConversationList) {
        listSnapshots[conversationList.identifier] = ConversationListSnapshot(conversationList: conversationList)
    }
    
    /// Removes the conversationList from the objects to observe
    @objc public func removeConversationList(_ conversationList: ZMConversationList){
        listSnapshots.removeValue(forKey: conversationList.identifier)
    }
    
    // MARK: Forwarding updates
    /// Handles updated conversations, updates lists and notifies observers
    public func conversationDidChange(_ changes: ConversationChangeInfo) {
        guard    changes.nameChanged              || changes.connectionStateChanged  || changes.isArchivedChanged
              || changes.isSilencedChanged        || changes.lastModifiedDateChanged || changes.conversationListIndicatorChanged
              || changes.voiceChannelStateChanged || changes.clearedChanged          || changes.securityLevelChanged
        else { return }
        
        forwardToSnapshots{$0.processConversationChanges(changes)}
    }
    
    /// Processes conversationChanges and removes or insert conversations and notifies observers
    func conversationsChanges(inserted: [ZMConversation], deleted: [ZMConversation], accumulated : Bool) {
        if deleted.count == 0 && inserted.count == 0 { return }
        forwardToSnapshots{$0.conversationsChanges(inserted: inserted, deleted: deleted, accumulated: accumulated)}
    }
    
    /// Applys a function on a token and cleares tokens with deallocated lists
    private func forwardToSnapshots(block: ((ConversationListSnapshot) -> Void)) {
        var snapshotsToRemove = [String]()
        listSnapshots.forEach{ (identifier, snapshot) in
            guard snapshot.conversationList != nil else {
                snapshot.tearDown()
                snapshotsToRemove.append(identifier)
                return
            }
            block(snapshot)
        }
        
        // clean up snapshotlist
        snapshotsToRemove.forEach{listSnapshots.removeValue(forKey: $0)}
    }

    func tearDown() {
        if isTornDown { return }
        isTornDown = true
        
        listSnapshots.values.forEach{$0.tearDown()}
        listSnapshots = [:]
    }
}


class ConversationListSnapshot: NSObject {
    
    fileprivate var state : SetSnapshot
    weak var conversationList : ZMConversationList?
    fileprivate var tornDown = false
    
    init(conversationList: ZMConversationList) {
        self.conversationList = conversationList
        self.state = SetSnapshot(set: conversationList.toOrderedSet(), moveType: .uiCollectionView)
        super.init()
    }
    
    /// Processes conversationChanges and removes or insert conversations and notifies observers
    fileprivate func processConversationChanges(_ changes: ConversationChangeInfo) {
        guard let list = conversationList else { return }
        let conversation = changes.conversation
        if list.contains(conversation) {
            // list contains conversation and needs to be updated
            let didRemoveConversation = updateDidRemoveConversation(list: list, changes: changes)
            recalculateList(changedConversation: conversation, changes: didRemoveConversation ? nil : changes)
        }
        else if list.predicateMatchesConversation(conversation) {
            // list did not contain conversation and now it should
            list.insertConversations(Set(arrayLiteral: conversation))
            recalculateList()
        }
    }
    
    private func updateDidRemoveConversation(list: ZMConversationList, changes: ConversationChangeInfo) -> Bool {
        var didRemoveConversation = false
        if !list.predicateMatchesConversation(changes.conversation) {
            list.removeConversations(Set(arrayLiteral: changes.conversation))
            didRemoveConversation = true
        }
        let a = changes.changedKeys
        if !didRemoveConversation && list.sortingIsAffected(byConversationKeys: a) {
            list.resortConversation(changes.conversation)
        }
        return didRemoveConversation
    }
    
    /// Handles inserted and removed conversations, updates lists and notifies observers
    func conversationsChanges(inserted: [ZMConversation], deleted: [ZMConversation], accumulated : Bool) {
        guard let list = conversationList else { return }
        
        if accumulated {
            list.resort()
            recalculateList()
        } else {
            let conversationsToInsert = Set(inserted.filter { list.predicateMatchesConversation($0)})
            let conversationsToRemove = Set(deleted.filter { list.contains($0)})
            
            list.insertConversations(conversationsToInsert)
            list.removeConversations(conversationsToRemove)
            
            if (!conversationsToInsert.isEmpty || !conversationsToRemove.isEmpty) {
                recalculateList()
            }
        }
    }
    
    func recalculateList(changedConversation: ZMConversation? = nil, changes: ConversationChangeInfo? = nil) {
        guard let conversationList = self.conversationList
        else { tearDown(); return }
        
        var listChange : ConversationListChangeInfo? = nil
        defer {
            notifyObservers(conversationChanges: changes, listChanges: listChange)
        }
        
        let changedSet = (changedConversation == nil) ? NSOrderedSet() : NSOrderedSet(object: changedConversation!)
        guard let newStateUpdate = self.state.updatedState(changedSet, observedObject: conversationList, newSet: conversationList.toOrderedSet())
        else { return }
        
        self.state = newStateUpdate.newSnapshot
        listChange = ConversationListChangeInfo(setChangeInfo: newStateUpdate.changeInfo)
    }
    
    private func notifyObservers(conversationChanges: ConversationChangeInfo?, listChanges: ConversationListChangeInfo?)
    {
        guard listChanges != nil || conversationChanges != nil else { return }
        
        var userInfo = [String : Any]()
        if let changes = conversationChanges {
            userInfo["conversationChangeInfo"] = changes
        }
        if let changes = listChanges {
            userInfo["conversationListChangeInfo"] = changes
        }
        NotificationCenter.default.post(name: .ZMConversationListDidChange, object: self.conversationList, userInfo: userInfo)
    }
    
    func tearDown() {
        state = SetSnapshot(set: NSOrderedSet(), moveType: .none)
        conversationList = nil
        tornDown = true
    }
}
