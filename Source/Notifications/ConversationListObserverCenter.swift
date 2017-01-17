//
//  ConversationListObserverCenter.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 17/01/17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation


extension Notification.Name {
    static let StartObservingList = Notification.Name("StartObservingListNotification")
    static let ZMConversationListDidChange = Notification.Name("ZMConversationListDidChangeNotification")
}


final class ConversationListObserverCenter : NSObject, ZMConversationObserver {
    
    fileprivate var internalConversationListObserverTokens : [String : ConversationListSnapshot] = [:]
    
    fileprivate weak var managedObjectContext : NSManagedObjectContext?
    fileprivate var conversationLists : [UnownedObject<ZMConversationList>] = Array()
    
    var isTornDown : Bool = false
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(startObservingList(_:)), name: .StartObservingList, object: nil)
    }
    
    func prepareObservers() {
        
        let lists = conversationLists.flatMap{$0.unbox}
        registerTokensForConversationList(lists)
    }
    
    @objc func startObservingList(_ note: Notification) {
        guard let list = note.object as? ZMConversationList else { return }
        addConversationList(list)
        registerTokensForConversationList([list])
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
        
        for listWrapper in self.conversationLists {
            if let list = listWrapper.unbox {
                if accumulated {
                    self.recomputeListAndNotifyObserver(list)
                } else {
                    self.updateListAndNotifyObservers(list, inserted: inserted, deleted: deleted)
                }
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
    
    func conversationDidChange(_ changeInfo: ConversationChangeInfo) {
        processConversationChanges(changeInfo)
    }
    
    func processConversationChanges(_ changes: ConversationChangeInfo) {
        guard   changes.nameChanged              || changes.connectionStateChanged  || changes.isArchivedChanged
             || changes.isSilencedChanged        || changes.lastModifiedDateChanged || changes.conversationListIndicatorChanged
             || changes.voiceChannelStateChanged || changes.clearedChanged          || changes.securityLevelChanged
        else { return }
        for conversationListWrapper in self.conversationLists
        {
            if let list = conversationListWrapper.unbox {
                let conversation = changes.conversation
                
                if list.contains(conversation)
                {
                    var didRemoveConversation = false
                    if !list.predicateMatchesConversation(conversation) {
                        list.removeConversations(Set(arrayLiteral: conversation))
                        didRemoveConversation = true
                    }
                    let a = changes.changedKeysAndOldValues.keys
                    if !didRemoveConversation && list.sortingIsAffected(byConversationKeys: Set(a)) {
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
    }
    
    fileprivate func notifyTokensForConversationList(_ list: ZMConversationList,
                                                     conversation : ZMConversation?,
                                                     conversationChanges: ConversationChangeInfo?) {
        let listChanges = internalConversationListObserverTokens[list.identifier]?.recalculateList(conversation, changes: conversationChanges)
        guard listChanges != nil || conversationChanges != nil else { return }
        
        let userInfo : [String : Any] = ["conversationChangeInfo": conversationChanges, "conversationListChangeInfo" : listChanges]
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
