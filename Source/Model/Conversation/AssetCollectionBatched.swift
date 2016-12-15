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
    private let categoriesToFetch : [MessageCategory]
    private var allMessages: [ZMAssetClientMessage] = []
    public static let defaultFetchCount = 200
    
    private var tornDown = false
    private var currentOffset = 0
    
    private var syncMOC: NSManagedObjectContext? {
        return conversation.managedObjectContext?.zm_sync
    }
    private var uiMOC: NSManagedObjectContext? {
        return conversation.managedObjectContext
    }
    
    /// Returns true when there are no assets to fetch OR when all assets have been fetched OR the collection has been tornDown
    public var doneFetching : Bool {
        return tornDown || allMessages.count == 0
    }
    
    /// Returns a collection that automatically fetches the assets in batches
    /// @param categoriesToFetch: The AssetCollection only returns and calls the delegate for these categories
    public init(conversation: ZMConversation, categoriesToFetch : [MessageCategory],  delegate: AssetCollectionDelegate){
        self.conversation = conversation
        self.delegate = delegate
        self.categoriesToFetch = categoriesToFetch
        super.init()
        
        syncMOC?.performGroupedBlock {
            guard !self.tornDown else { return }
            guard let syncConversation = (try? self.syncMOC?.existingObject(with: self.conversation.objectID)) as? ZMConversation else {
                return
            }
            self.allMessages = AssetCollectionBatched.messages(for: syncConversation)
            self.categorizeNextBatch()
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
    
    private func categorizeNextBatch(){
        guard !tornDown else { return }
        
        let numberToAnalyze = min(self.allMessages.count, AssetCollectionBatched.defaultFetchCount)
        if numberToAnalyze == 0 {
            self.notifyDelegateFetchingIsDone(result: (self.assets != nil) ? .success : .noAssetsToFetch)
            return
        }
        let messagesToAnalyze = Array(self.allMessages[0..<numberToAnalyze])
        let newAssets = CategorizedFetchResult(messages: messagesToAnalyze, categories: self.categoriesToFetch)
        
        self.allMessages = Array(self.allMessages.dropFirst(numberToAnalyze))
        if let assets = self.assets {
            self.assets = assets.merged(with: newAssets)
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
            self.categorizeNextBatch()
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
    
    static func messages(for conversation: ZMConversation) -> [ZMAssetClientMessage]  {
        let request = NSFetchRequest<ZMAssetClientMessage>(entityName: ZMAssetClientMessage.entityName())
        request.predicate = NSPredicate(format: "visibleInConversation == %@", conversation)
        request.sortDescriptors = [NSSortDescriptor(key: "serverTimestamp", ascending: false)]
        request.fetchBatchSize = AssetCollectionBatched.defaultFetchCount
        request.relationshipKeyPathsForPrefetching = ["dataSet"]
        
        guard let result = conversation.managedObjectContext?.fetchOrAssert(request: request) else {return []}
        return result
    }
    
}



struct CategorizedFetchResult {
    
    let totalFetchCount : Int = 0
    let lastMessage : ZMMessage
    let messagesByFilter : [MessageCategory : [ZMMessage]]
    
    init(messages: [ZMMessage], categories: [MessageCategory]) {
        precondition(messages.count > 0, "messages should contain at least one value")
        let messagesByFilter = CategorizedFetchResult.categorize(messages: messages, categoriesToFetch: categories)
        self.init(lastMessage: messages.last!, messagesByFilter: messagesByFilter)
    }
    
    init(lastMessage : ZMMessage, messagesByFilter : [MessageCategory : [ZMMessage]]){
        self.lastMessage = lastMessage
        self.messagesByFilter = messagesByFilter
    }
    
    
    static func categorize(messages: [ZMMessage], categoriesToFetch: [MessageCategory]) -> [MessageCategory : [ZMMessage]] {
        // setup dictionary with keys we are interested in
        var sorted = [MessageCategory : [ZMMessage]]()
        for category in categoriesToFetch {
            sorted[category] = []
        }
        
        let unionCategory : MessageCategory = categoriesToFetch.reduce(.none){$0.union($1)}
        messages.forEach{ message in
            categoriesToFetch.forEach {
                let category = message.category
                guard (category.intersection(unionCategory) != .none) else { return }
                if category.contains($0) {
                    sorted[$0]?.append(message)
                }
            }
        }
        return sorted
    }
    
    func merged(with other: CategorizedFetchResult) -> CategorizedFetchResult? {
        guard let lastMessageTimestamp = lastMessage.serverTimestamp,
            let otherLastMessageTimestamp = other.lastMessage.serverTimestamp
            else {return nil }
        
        let (newer, older) = (lastMessageTimestamp.compare(otherLastMessageTimestamp) == .orderedAscending) ?
            (other, self) : (self, other)
        
        var newSortedMessages = [MessageCategory : [ZMMessage]]()
        older.messagesByFilter.forEach {
            let newerValues = newer.messagesByFilter[$0] ?? []
            let allValues = newerValues + $1
            newSortedMessages[$0] = allValues
        }
        return CategorizedFetchResult(lastMessage: older.lastMessage, messagesByFilter: newSortedMessages)
    }
    
}


