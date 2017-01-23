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
    static let StartObservingList = Notification.Name("StartObservingListNotification")
    static let ZMConversationListDidChange = Notification.Name("ZMConversationListDidChangeNotification")
}

let ConversationListObserverCenterKey = "ConversationListObserverCenterKey"

extension NSManagedObjectContext {
    
    public var conversationListObserverCenter : ConversationListObserverCenter {
        if let observer = self.userInfo[ConversationListObserverCenterKey] as? ConversationListObserverCenter {
            return observer
        }
        
        let newObserver = ConversationListObserverCenter()
        self.userInfo[ConversationListObserverCenterKey] = newObserver
        return newObserver
    }
}

public class ConversationListObserverCenter : NSObject, ZMConversationObserver {
    
    fileprivate var internalConversationListObserverTokens : [String : ConversationListSnapshot] = [:]
    fileprivate var conversationLists : [UnownedObject<ZMConversationList>] = Array()
    
    var isTornDown : Bool = false
    
    func prepareObservers() {
        let lists = conversationLists.flatMap{$0.unbox}
        registerTokensForConversationList(lists)
    }
    
    @objc public func startObservingList(_ conversationList: ZMConversationList) {
        addConversationList(conversationList)
        registerTokensForConversationList([conversationList])
    }
    
    // adding and removing lists
    func addConversationList(_ conversationList: ZMConversationList) {
        if !self.isObservingConversationList(conversationList) {
            self.conversationLists.append(UnownedObject(conversationList))
        }
    }
    
    func removeConversationList(_ conversationList: ZMConversationList) {
        self.conversationLists = self.conversationLists.filter { $0.unbox != conversationList}
    }
    
    fileprivate func registerTokensForConversationList(_ lists : [ZMConversationList]) {
        for conversationList in lists {
            if internalConversationListObserverTokens[conversationList.identifier] == nil {
                internalConversationListObserverTokens[conversationList.identifier] = ConversationListSnapshot(conversationList: conversationList)
            }
        }
    }
    
    // handling object changes
    func conversationsChanges(inserted: [ZMConversation], deleted: [ZMConversation], accumulated : Bool) {
        if deleted.count == 0 && inserted.count == 0 { return }
        
        self.conversationLists.forEach {
            guard let list = $0.unbox else { return }
            if accumulated {
                self.recomputeListAndNotifyObserver(list)
            } else {
                self.updateListAndNotifyObservers(list, inserted: inserted, deleted: deleted)
            }
        }
    }
    
    fileprivate func updateListAndNotifyObservers(_ list: ZMConversationList, inserted: [ZMConversation], deleted: [ZMConversation]){
        let conversationsToInsert = Set(inserted.filter { list.predicateMatchesConversation($0)})
        let conversationsToRemove = Set(deleted.filter { list.contains($0)})
        
        list.insertConversations(conversationsToInsert)
        list.removeConversations(conversationsToRemove)
        
        if (!conversationsToInsert.isEmpty || !conversationsToRemove.isEmpty) {
            self.notifyTokensForConversationList(list, conversation: nil, conversationChanges: nil)
        }
    }
    
    fileprivate func recomputeListAndNotifyObserver(_ list: ZMConversationList) {
        list.resort()
        self.notifyTokensForConversationList(list, conversation: nil, conversationChanges: nil)
    }
    
    public func conversationDidChange(_ changeInfo: ConversationChangeInfo) {
        processConversationChanges(changeInfo)
    }
    
    fileprivate func conversationChangeRequiresRecalculation(changes: ConversationChangeInfo) -> Bool {
        return    changes.nameChanged              || changes.connectionStateChanged  || changes.isArchivedChanged
               || changes.isSilencedChanged        || changes.lastModifiedDateChanged || changes.conversationListIndicatorChanged
               || changes.voiceChannelStateChanged || changes.clearedChanged          || changes.securityLevelChanged
    }
    
    fileprivate func processConversationChanges(_ changes: ConversationChangeInfo) {
        guard conversationChangeRequiresRecalculation(changes: changes) else { return }
        
        self.conversationLists.forEach{
            guard let list = $0.unbox else { return }
            
            let conversation = changes.conversation
            if list.contains(conversation)
            {
                var didRemoveConversation = false
                if !list.predicateMatchesConversation(conversation) {
                    list.removeConversations(Set(arrayLiteral: conversation))
                    didRemoveConversation = true
                }
                let a = changes.changedKeys
                if !didRemoveConversation && list.sortingIsAffected(byConversationKeys: a) {
                    list.resortConversation(conversation)
                }
                self.notifyTokensForConversationList(list, conversation:conversation, conversationChanges: didRemoveConversation ? nil : changes)
            }
            else if list.predicateMatchesConversation(conversation) // list did not contain conversation and now it should
            {
                list.insertConversations(Set(arrayLiteral: conversation))
                self.notifyTokensForConversationList(list, conversation:nil, conversationChanges:nil)
            }
        }
    }
    
    fileprivate func notifyTokensForConversationList(_ list: ZMConversationList,
                                                     conversation : ZMConversation?,
                                                     conversationChanges: ConversationChangeInfo?) {
        let listChanges = internalConversationListObserverTokens[list.identifier]?.recalculateList(conversation, changes: conversationChanges)
        guard listChanges != nil || conversationChanges != nil else { return }
        
        var userInfo = [String : Any]()
        if let changes = conversationChanges {
            userInfo["conversationChangeInfo"] = changes
        }
        if let changes = listChanges {
            userInfo["conversationListChangeInfo"] = changes
        }
        NotificationCenter.default.post(name: .ZMConversationListDidChange, object: list, userInfo: userInfo)
    }
    
    fileprivate func isObservingConversationList(_ conversationList: ZMConversationList) -> Bool {
        return self.conversationLists.filter({$0.unbox === conversationList}).count > 0
    }
    
    func tearDown() {
        if isTornDown { return }
        isTornDown = true
        
        internalConversationListObserverTokens.values.forEach{$0.tearDown()}
        internalConversationListObserverTokens = [:]
        
        conversationLists = []
    }
}

class ConversationListSnapshot: NSObject {
    
    fileprivate var state : SetSnapshot
    weak var conversationList : ZMConversationList?
    
    init(conversationList: ZMConversationList) {
        self.conversationList = conversationList
        self.state = SetSnapshot(set: conversationList.toOrderedSet(), moveType: .uiCollectionView)
        super.init()
    }
    
    func recalculateList(_ changedConversation: ZMConversation?, changes: ConversationChangeInfo?) -> ConversationListChangeInfo? {
        guard let conversationList = self.conversationList
        else {
            tearDown();
            return nil
        }
        
        let changedSet = (changedConversation == nil) ? NSOrderedSet() : NSOrderedSet(object: changedConversation!)
        guard let newStateUpdate = self.state.updatedState(changedSet, observedObject: conversationList, newSet: conversationList.toOrderedSet())
        else { return nil }
        
        self.state = newStateUpdate.newSnapshot
        return ConversationListChangeInfo(setChangeInfo: newStateUpdate.changeInfo)
    }
    
    func tearDown() {
        state = SetSnapshot(set: NSOrderedSet(), moveType: .none)
        conversationList = nil
    }
}
