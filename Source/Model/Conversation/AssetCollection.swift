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

public enum AssetFilter : Int16 {
    case none, links, files, images
}

public protocol AssetCollectionDelegate : NSObjectProtocol {
    /// The AssetCollection calls this when the fetching completes
    func assetCollectionDidFetch(messages: [AssetFilter: [ZMMessage]], hasMore: Bool)
}

public class AssetCollection {

    private unowned var delegate : AssetCollectionDelegate
    private var assets : PagedAssetFetchResult?
    private let conversation: ZMConversation
    private var assetCount: Int
    public static let initialFetchCount = 100
    public static let defaultFetchCount = 500
    
    private var tornDown = false

    private var syncMOC: NSManagedObjectContext? {
        return conversation.managedObjectContext?.zm_sync
    }
    private var uiMOC: NSManagedObjectContext? {
        return conversation.managedObjectContext
    }
    
    public var doneFetching : Bool {
        return tornDown || assetCount == 0 || currentAssetCount == assetCount
    }

    private var currentAssetCount : Int {
        guard let assets = assets else {return 0}
        return assets.messagesByFilter.values.reduce(0){$0+$1.count}
    }
    
    public init(conversation: ZMConversation, delegate: AssetCollectionDelegate){
        self.conversation = conversation
        self.delegate = delegate
        self.assetCount = AssetCollection.fetchMessageCount(for: conversation)
        
        if assetCount == 0 {
            delegate.assetCollectionDidFetch(messages: [:], hasMore: false)
        } else {
            fetchNextIfNotTornDown(limit: min(assetCount, AssetCollection.initialFetchCount))
        }
    }
    
    public func tearDown() {
        tornDown = true
    }
    
    public func assets(for filter: AssetFilter) -> [ZMMessage] {
        return assets?.messagesByFilter[filter] ?? []
    }
    
    private static func fetchMessageCount(for conversation: ZMConversation) -> Int {
        let countRequest = NSFetchRequest<ZMAssetClientMessage>(entityName: ZMAssetClientMessage.entityName())
        countRequest.predicate = NSPredicate(format: "visibleInConversation == %@", conversation)
        guard let count = try? conversation.managedObjectContext?.count(for: countRequest) else { return 0 }
        return count ?? 0
    }

    private func fetchNextIfNotTornDown(limit: Int){
        guard !tornDown && !doneFetching else { return }

        syncMOC?.performGroupedBlock { [weak self] in
            guard let `self` = self, !self.tornDown,
                  let syncConversation = (try? self.syncMOC?.existingObject(with: self.conversation.objectID)) as? ZMConversation
            else { return }
            
            guard let newAssets = PagedAssetFetchResult(conversation: syncConversation,
                                                  startAfter: self.assets?.lastMessage,
                                                  fetchLimit: limit)
            else {
                self.notifyDelegate(newAssets: [:])
                return
            }
            
            if let assets = self.assets {
                self.assets = assets.merged(with: newAssets)
            } else {
                self.assets = newAssets
            }
            self.notifyDelegate(newAssets: newAssets.messagesByFilter)
            print(self.currentAssetCount)
            self.fetchNextIfNotTornDown(limit:  min(self.assetCount - self.currentAssetCount, AssetCollection.defaultFetchCount))
        }
    }
    
    private func notifyDelegate(newAssets: [AssetFilter : [ZMAssetClientMessage]]) {
        uiMOC?.performGroupedBlock { [weak self] in
            guard let `self` = self else { return }
            
            if newAssets.count == 0 {
                self.delegate.assetCollectionDidFetch(messages: [:], hasMore: false)
            }
            else {
                var uiAssets = [AssetFilter : [ZMMessage]]()
                newAssets.forEach {
                    let uiValues = $1.flatMap{ (try? self.uiMOC?.existingObject(with: $0.objectID)) as? ZMMessage}
                    uiAssets[$0] = uiValues
                }
                self.delegate.assetCollectionDidFetch(messages: uiAssets, hasMore: !self.doneFetching)
            }
        }
    }
    
}



struct PagedAssetFetchResult {

    public let lastMessage : ZMAssetClientMessage
    public let messagesByFilter : [AssetFilter : [ZMAssetClientMessage]]
    
    init?(conversation: ZMConversation, startAfter previousMessage: ZMMessage?, fetchLimit: Int) {
        let allMessages = PagedAssetFetchResult.messages(for: conversation, startAfter: previousMessage, fetchLimit: fetchLimit)
        guard let lastMessage = allMessages.last else {return nil}
        
        let messagesByFilter = PagedAssetFetchResult.categorize(messages: allMessages)
        self.init(lastMessage: lastMessage, messagesByFilter: messagesByFilter)
    }
    
    init(lastMessage : ZMAssetClientMessage, messagesByFilter : [AssetFilter : [ZMAssetClientMessage]]){
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
        request.sortDescriptors = [NSSortDescriptor(key: "serverTimestamp", ascending: false)]
        request.fetchLimit = fetchLimit
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["dataSet"]
        
        guard let result = conversation.managedObjectContext?.fetchOrAssert(request: request) else {return []}
        return result
    }
    
    static func categorize(messages: [ZMAssetClientMessage]) -> [AssetFilter : [ZMAssetClientMessage]] {
        var sorted = [AssetFilter : [ZMAssetClientMessage]]()
        messages.forEach{
            var filter : AssetFilter = .none
            if $0.imageMessageData != nil {
                filter = .images
            }
            
            var items = sorted[filter] ?? []
            items.append($0)
            sorted[filter] = items
        }
        return sorted
    }
    
    func merged(with other: PagedAssetFetchResult) -> PagedAssetFetchResult? {
        guard let lastMessageTimestamp = lastMessage.serverTimestamp,
              let otherLastMessageTimestamp = other.lastMessage.serverTimestamp
        else {return nil }
        
        let (newer, older) = (lastMessageTimestamp.compare(otherLastMessageTimestamp) == .orderedAscending) ?
                             (other, self) : (self, other)
        
        var newSortedMessages = [AssetFilter : [ZMAssetClientMessage]]()
        older.messagesByFilter.forEach {
            let newerValues = newer.messagesByFilter[$0] ?? []
            let allValues = newerValues + $1
            newSortedMessages[$0] = allValues
        }
        return PagedAssetFetchResult(lastMessage: older.lastMessage, messagesByFilter: newSortedMessages)
    }
    
}


