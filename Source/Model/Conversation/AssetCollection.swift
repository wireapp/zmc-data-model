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

public enum AssetFetchResult : Int {
    case success, failed, cancelled, noAssetsToFetch
}

public protocol AssetCollectionDelegate : NSObjectProtocol {
    /// The AssetCollection calls this when the fetching completes
    /// To get all messages for any category defined in categoriesToFetch, call `assets(for category: MessageCategory)`
    func assetCollectionDidFetch(messages: [MessageCategory: [ZMMessage]])
    
    /// This method is called when all assets in the conversation have been fetched & analyzed / categorized
    func assetCollectionDidFinishFetching(result : AssetFetchResult)
}

public class AssetCollection : NSObject {

    private unowned var delegate : AssetCollectionDelegate
    private var assets : PagedAssetFetchResult?
    private let conversation: ZMConversation
    private let categoriesToFetch : [MessageCategory]
    public static let initialFetchCount = 100
    public static let defaultFetchCount = 500
    public private (set) var doneFetching : Bool = false

    private var tornDown = false {
        didSet {
            doneFetching = true
        }
    }

    private var syncMOC: NSManagedObjectContext? {
        return conversation.managedObjectContext?.zm_sync
    }
    private var uiMOC: NSManagedObjectContext? {
        return conversation.managedObjectContext
    }
    
    /// Returns a collection that automatically fetches the assets in batches
    /// @param categoriesToFetch: The AssetCollection only returns and calls the delegate for these categories
    public init(conversation: ZMConversation, categoriesToFetch : [MessageCategory],  delegate: AssetCollectionDelegate){
        self.conversation = conversation
        self.delegate = delegate
        self.categoriesToFetch = categoriesToFetch
        super.init()
        
        fetchNextIfNotTornDown(limit: AssetCollection.initialFetchCount)
    }
    
    /// Cancels further fetch requests
    public func tearDown() {
        tornDown = true
    }
    
    deinit {
        precondition(tornDown, "Call tearDown to avoid continued fetch requests")
    }
    
    /// Returns all assets that have been fetched thus far
    public func assets(for category: MessageCategory) -> [ZMMessage] {
        return assets?.messagesByFilter[category] ?? []
    }
    
    private static func fetchMessageCount(for conversation: ZMConversation) -> Int {
        let countRequest = NSFetchRequest<ZMAssetClientMessage>(entityName: ZMAssetClientMessage.entityName())
        countRequest.predicate = NSPredicate(format: "visibleInConversation == %@", conversation)
        guard let count = try? conversation.managedObjectContext?.count(for: countRequest) else { return 0 }
        return count ?? 0
    }

    private func fetchNextIfNotTornDown(limit: Int){
        guard !doneFetching else { return }
        guard !tornDown else {
            self.notifyDelegateFetchingIsDone(result: .cancelled)
            return
        }

        syncMOC?.performGroupedBlock { [weak self] in
            guard let `self` = self else { return }
            guard !self.tornDown else {
                self.notifyDelegateFetchingIsDone(result: .cancelled)
                return
            }
            
            guard let syncConversation = (try? self.syncMOC?.existingObject(with: self.conversation.objectID)) as? ZMConversation,
                  let newAssets = PagedAssetFetchResult(conversation: syncConversation,
                                                        startAfter: self.assets?.lastMessage,
                                                        fetchLimit: limit,
                                                        categoriesToFetch: self.categoriesToFetch)
            else {
                self.doneFetching = true
                if self.assets == nil {
                    self.notifyDelegateFetchingIsDone(result: .noAssetsToFetch)
                } else {
                    self.notifyDelegateFetchingIsDone(result: .success)
                }
                return
            }
            
            if let assets = self.assets {
                self.assets = assets.merged(with: newAssets)
            } else {
                self.assets = newAssets
            }
            self.notifyDelegate(newAssets: newAssets.messagesByFilter)
            self.fetchNextIfNotTornDown(limit:  AssetCollection.defaultFetchCount)
        }
    }
    
    private func notifyDelegate(newAssets: [MessageCategory : [ZMAssetClientMessage]]) {
        uiMOC?.performGroupedBlock { [weak self] in
            guard let `self` = self, !self.tornDown else { return }
            
            var uiAssets = [MessageCategory : [ZMMessage]]()
            newAssets.forEach {
                let uiValues = $1.flatMap{ (try? self.uiMOC?.existingObject(with: $0.objectID)) as? ZMMessage}
                uiAssets[$0] = uiValues
            }
            self.delegate.assetCollectionDidFetch(messages: uiAssets)
        }
    }
    
    private func notifyDelegateFetchingIsDone(result: AssetFetchResult){
        self.uiMOC?.performGroupedBlock { [weak self] in
            self?.delegate.assetCollectionDidFinishFetching(result: result)
        }
    }
    
}



struct PagedAssetFetchResult {

    let totalFetchCount : Int = 0
    let lastMessage : ZMAssetClientMessage
    let messagesByFilter : [MessageCategory : [ZMAssetClientMessage]]
    
    init?(conversation: ZMConversation,
          startAfter previousMessage: ZMMessage?,
          fetchLimit: Int,
          categoriesToFetch: [MessageCategory])
    {
        let allMessages = PagedAssetFetchResult.messages(for: conversation, startAfter: previousMessage, fetchLimit: fetchLimit)
        guard let lastMessage = allMessages.last else {return nil}
        
        let messagesByFilter = PagedAssetFetchResult.categorize(messages: allMessages, categoriesToFetch: categoriesToFetch)
        self.init(lastMessage: lastMessage, messagesByFilter: messagesByFilter)
    }
    
    init(lastMessage : ZMAssetClientMessage, messagesByFilter : [MessageCategory : [ZMAssetClientMessage]]){
        self.lastMessage = lastMessage
        self.messagesByFilter = messagesByFilter
    }
    
    static func messages(for conversation: ZMConversation, startAfter previousMessage: ZMMessage?, fetchLimit: Int) -> [ZMAssetClientMessage]  {
        var predicate = NSPredicate(format: "visibleInConversation == %@", conversation)
        if let serverTimestamp = previousMessage?.serverTimestamp {
            let messagePredicate = NSPredicate(format: "serverTimestamp < %@", serverTimestamp as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, messagePredicate])
        }
        let request = NSFetchRequest<ZMAssetClientMessage>(entityName: ZMAssetClientMessage.entityName())
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "serverTimestamp", ascending: false)]
        request.fetchLimit = fetchLimit
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["dataSet"]
        
        guard let result = conversation.managedObjectContext?.fetchOrAssert(request: request) else {return []}
        return result
    }
    
    static func categorize(messages: [ZMAssetClientMessage], categoriesToFetch: [MessageCategory]) -> [MessageCategory : [ZMAssetClientMessage]] {
        // setup dictionary with keys we are interested in
        var sorted = [MessageCategory : [ZMAssetClientMessage]]()
        for category in categoriesToFetch {
            sorted[category] = []
        }
        // loop through all messages and all dictionary keys
        messages.forEach{ message in
            categoriesToFetch.forEach {
                if message.category.contains($0) {
                    sorted[$0]?.append(message)
                }
            }
        }
        return sorted
    }
    
    func merged(with other: PagedAssetFetchResult) -> PagedAssetFetchResult? {
        guard let lastMessageTimestamp = lastMessage.serverTimestamp,
              let otherLastMessageTimestamp = other.lastMessage.serverTimestamp
        else {return nil }
        
        let (newer, older) = (lastMessageTimestamp.compare(otherLastMessageTimestamp) == .orderedAscending) ?
                             (other, self) : (self, other)
        
        var newSortedMessages = [MessageCategory : [ZMAssetClientMessage]]()
        older.messagesByFilter.forEach {
            let newerValues = newer.messagesByFilter[$0] ?? []
            let allValues = newerValues + $1
            newSortedMessages[$0] = allValues
        }
        return PagedAssetFetchResult(lastMessage: older.lastMessage, messagesByFilter: newSortedMessages)
    }
    
}


