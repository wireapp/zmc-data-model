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
    case success, failed, noAssetsToFetch
}

public protocol ZMCollection : NSObjectProtocol {
    func tearDown()
    func assets(for category: MessageCategory) -> [ZMMessage]
}

public protocol AssetCollectionDelegate : NSObjectProtocol {
    /// The AssetCollection calls this when the fetching completes
    /// To get all messages for any category defined in `including`, call `assets(for category: MessageCategory)`
    func assetCollectionDidFetch(messages: [MessageCategory: [ZMMessage]], hasMore: Bool)
    
    /// This method is called when all assets in the conversation have been fetched & analyzed / categorized
    func assetCollectionDidFinishFetching(result : AssetFetchResult)
}


public class AssetCollection : NSObject, ZMCollection {

    private unowned var delegate : AssetCollectionDelegate
    private var assets : CategorizedFetchResult?
    private var lastFetchedMessage : ZMMessage?
    private let conversation: ZMConversation
    private let including : [MessageCategory]
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
    public init(conversation: ZMConversation, including : [MessageCategory], excluding: [MessageCategory] = [], delegate: AssetCollectionDelegate){
        self.conversation = conversation
        self.delegate = delegate
        self.including = including
        super.init()
        
        fetchNextIfNotTornDown(limit: AssetCollection.initialFetchCount)
    }
    
    /// Cancels further fetch requests
    public func tearDown() {
        tornDown = true
        doneFetching = true
    }
    
    deinit {
        precondition(tornDown, "Call tearDown to avoid continued fetch requests")
    }
    
    /// Returns all assets that have been fetched thus far
    public func assets(for category: MessageCategory) -> [ZMMessage] {
        return assets?.messagesByFilter[category] ?? []
    }

    private func fetchNextIfNotTornDown(limit: Int){
        guard !doneFetching else { return }
        guard !tornDown else {
            return
        }

        syncMOC?.performGroupedBlock { [weak self] in
            guard let `self` = self, !self.tornDown else { return }
            guard let syncConversation = (try? self.syncMOC?.existingObject(with: self.conversation.objectID)) as? ZMConversation
            else {
                self.doneFetching = true
                self.notifyDelegateFetchingIsDone(result: .failed)
                return
            }
            
            let messagesToAnalyze = self.messages(for: syncConversation, startAfter: self.lastFetchedMessage, fetchLimit: limit)
            self.lastFetchedMessage = messagesToAnalyze.last
            if messagesToAnalyze.count == 0 {
                self.doneFetching = true
                self.notifyDelegateFetchingIsDone(result: (self.assets == nil) ? .noAssetsToFetch : .success)
                return
            }
            
            let newAssets = CategorizedFetchResult(messages: messagesToAnalyze, including: self.including, excluding: [])
            if let assets = self.assets {
                self.assets = assets.merging(with: newAssets)
            } else {
                self.assets = newAssets
            }
            self.notifyDelegate(newAssets: newAssets.messagesByFilter)
            self.fetchNextIfNotTornDown(limit:  AssetCollection.defaultFetchCount)
        }
    }
    
    private func notifyDelegate(newAssets: [MessageCategory : [ZMMessage]]) {
        uiMOC?.performGroupedBlock { [weak self] in
            guard let `self` = self, !self.tornDown else { return }
            var uiAssets = [MessageCategory : [ZMMessage]]()
            newAssets.forEach { (category, messages) in
                let uiValues = messages.flatMap{ (try? self.uiMOC?.existingObject(with: $0.objectID)) as? ZMMessage}
                uiAssets[category] = uiValues
            }
            self.delegate.assetCollectionDidFetch(messages: uiAssets, hasMore: !self.doneFetching)
        }
    }
    
    private func notifyDelegateFetchingIsDone(result: AssetFetchResult){
        self.uiMOC?.performGroupedBlock { [weak self] in
            guard let `self` = self, !self.tornDown else { return }
            self.delegate.assetCollectionDidFinishFetching(result: result)
        }
    }
    
    func messages(for conversation: ZMConversation, startAfter previousMessage: ZMMessage?, fetchLimit: Int) -> [ZMAssetClientMessage]  {
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
    
}



