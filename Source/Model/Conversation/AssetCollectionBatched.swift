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


public class AssetCollectionBatched : NSObject, ZMCollection {
    
    private unowned var delegate : AssetCollectionDelegate
    private var assets : CategorizedFetchResult?
    private let conversation: ZMConversation
    private let including : [MessageCategory]
    private let excluding: MessageCategory
    private var allAssetMessages: [ZMAssetClientMessage] = []
    private var allClientMessages: [ZMClientMessage] = []

    enum MessagesToFetch {
        case client, asset
    }
    
    public static let defaultFetchCount = 200
    
    private var tornDown = false
    
    private var syncMOC: NSManagedObjectContext? {
        return conversation.managedObjectContext?.zm_sync
    }
    private var uiMOC: NSManagedObjectContext? {
        return conversation.managedObjectContext
    }
    
    /// Returns true when there are no assets to fetch OR when all assets have been processed OR the collection has been tornDown
    public var doneFetching : Bool {
        return tornDown || (allAssetMessages.count == 0 && allClientMessages.count == 0)
    }
    
    /// Returns a collection that automatically fetches the assets in batches
    /// @param including: The AssetCollection only returns and calls the delegate for these categories
    /// @param excluding: These categories are excluded when fetching messages (e.g if you want files, but not videos)
    public init(conversation: ZMConversation, including : [MessageCategory], excluding: [MessageCategory] = [],  delegate: AssetCollectionDelegate){
        self.conversation = conversation
        self.delegate = delegate
        self.including = including
        self.excluding = excluding.reduce(.none){$0.union($1)}

        super.init()
        
        syncMOC?.performGroupedBlock {
            guard !self.tornDown else { return }
            guard let syncConversation = (try? self.syncMOC?.existingObject(with: self.conversation.objectID)) as? ZMConversation else {
                return
            }
            let categorizedMessages : [ZMMessage] = self.categorizedMessages(for: syncConversation)
            if categorizedMessages.count > 0 {
                self.assets = CategorizedFetchResult(messages: categorizedMessages, including: self.including, excluding: self.excluding)
                self.notifyDelegate(newAssets: self.assets!.messagesByFilter)
            }
            self.allAssetMessages = self.unCategorizedMessages(for: syncConversation)
            self.allClientMessages = self.unCategorizedMessages(for: syncConversation)

            self.categorizeNextBatch(type: .asset)
            self.categorizeNextBatch(type: .client)
        }
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
    
    private func categorizeNextBatch(type: MessagesToFetch){
        guard !tornDown else { return }
        let messages : [ZMMessage] = (type == .asset) ? self.allAssetMessages : self.allClientMessages
        
        let numberToAnalyze = min(messages.count, AssetCollectionBatched.defaultFetchCount)
        if numberToAnalyze == 0 {
            if self.doneFetching {
                self.notifyDelegateFetchingIsDone(result: (self.assets != nil) ? .success : .noAssetsToFetch)
            }
            return
        }
        let messagesToAnalyze = Array(messages[0..<numberToAnalyze])
        let newAssets = CategorizedFetchResult(messages: messagesToAnalyze, including: self.including, excluding: self.excluding)
        
        if type == .asset {
            self.allAssetMessages = Array(self.allAssetMessages.dropFirst(numberToAnalyze))
        } else {
            self.allClientMessages = Array(self.allClientMessages.dropFirst(numberToAnalyze))
        }
        
        if let assets = self.assets {
            self.assets = assets.merging(with: newAssets)
        } else {
            self.assets = newAssets
        }
        self.notifyDelegate(newAssets: newAssets.messagesByFilter)
        if self.doneFetching {
            self.delegate.assetCollectionDidFinishFetching(result: .success)
            return
        }
        
        syncMOC?.performGroupedBlock { [weak self] in
            guard let `self` = self, !self.tornDown else { return }
            self.categorizeNextBatch(type: type)
        }
    }
    
    private func notifyDelegate(newAssets: [MessageCategory : [ZMMessage]]) {
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
            guard let `self` = self else { return }
            self.delegate.assetCollectionDidFinishFetching(result: result)
        }
    }
    
    func categorizedMessages<T : ZMMessage>(for conversation: ZMConversation) -> [T] {
        precondition(conversation.managedObjectContext!.zm_isSyncContext, "Fetch should only be performed on the sync context")
        let request = T.fetchRequestMatching(categories: Set(self.including), excluding: self.excluding, conversation: conversation)
        
        guard let result = conversation.managedObjectContext?.fetchOrAssert(request: request as! NSFetchRequest<T>) else {return []}
        return result
    }
    
    func unCategorizedMessages<T : ZMMessage>(for conversation: ZMConversation) -> [T]  {
        precondition(conversation.managedObjectContext!.zm_isSyncContext, "Fetch should only be performed on the sync context")
        
        let request = NSFetchRequest<T>(entityName: T.entityName())
        request.predicate = NSPredicate(format: "visibleInConversation == %@ && (%K == NULL || %K == %d)", conversation, ZMMessageCachedCategoryKey, ZMMessageCachedCategoryKey, MessageCategory.none.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "serverTimestamp", ascending: false)]
        request.fetchBatchSize = AssetCollectionBatched.defaultFetchCount
        request.relationshipKeyPathsForPrefetching = ["dataSet"]
        
        guard let result = conversation.managedObjectContext?.fetchOrAssert(request: request) else {return []}
        return result
    }
    
}



struct CategorizedFetchResult {
    
    let messagesByFilter : [MessageCategory : [ZMMessage]]
    
    init(messages: [ZMMessage], including: [MessageCategory], excluding: MessageCategory) {
        precondition(messages.count > 0, "messages should contain at least one value")
        let messagesByFilter = CategorizedFetchResult.categorize(messages: messages, including: including, excluding:excluding)
        self.init(messagesByFilter: messagesByFilter)
    }
    
    init(messagesByFilter : [MessageCategory : [ZMMessage]]){
        self.messagesByFilter = messagesByFilter
    }
    
    
    static func categorize(messages: [ZMMessage], including: [MessageCategory], excluding: MessageCategory)
        -> [MessageCategory : [ZMMessage]]
    {
        // setup dictionary with keys we are interested in
        var sorted = [MessageCategory : [ZMMessage]]()
        for category in including {
            sorted[category] = []
        }
        
        let unionIncluding : MessageCategory = including.reduce(.none){$0.union($1)}
        messages.forEach{ message in
            let category = message.cachedCategory
            guard (category.intersection(unionIncluding) != .none) && (category.intersection(excluding) == .none) else { return }

            including.forEach {
                if category.contains($0) {
                    sorted[$0]?.append(message)
                }
            }
        }
        return sorted
    }
    
    func merging(with other: CategorizedFetchResult) -> CategorizedFetchResult? {
        var newSortedMessages = [MessageCategory : [ZMMessage]]()
        
        self.messagesByFilter.forEach {
            var newValues = $1
            if let otherValues = other.messagesByFilter[$0] {
                newValues = newValues + otherValues
            }
            newSortedMessages[$0] = newValues
        }
        
        let notIncluded = Set(other.messagesByFilter.keys).subtracting(Set(other.messagesByFilter.keys))
        notIncluded.forEach{
            if let value = other.messagesByFilter[$0] {
                newSortedMessages[$0] = value
            }
        }
        
        return CategorizedFetchResult(messagesByFilter: newSortedMessages)
    }
    
}


