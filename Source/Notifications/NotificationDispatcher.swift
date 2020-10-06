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
import CoreData


/// The `NotificationDispatcher` listens for changes to observable entities (e.g message, users, and conversations),
/// extracts information about those changes (e.g which properties changed), and posts notifications about those
/// changes.
///
/// Changes are only observed on the main UI managed object context and are triggered by automatically by
/// Core Data notifications or manually for non Core Data changes.

@objcMembers public class NotificationDispatcher: NSObject, TearDownCapable {

    static var log = ZMSLog(tag: "notifications")

    // MARK: - Public properties

    /// The mode in which the dispatcher operates.
    ///
    /// Setting this value will affect the detail and frequency of notifications.

    public var operationMode = OperationMode.normal {
        didSet {
            switch (oldValue, operationMode) {
            case (.economical, .normal):
                // TODO: [John] test
                fireAllNotifications()
            case (.normal, .economical):
                // TODO: [John] test
                snapshotCenter.clearAllSnapshots()
            default:
                break
            }
        }
    }

    /// Whether the dispatcher is enabled.
    ///
    /// If set to `false`, all pending changes are discarded and no new notifications are posted.

    public var isEnabled = true {
        didSet {
            guard oldValue != isEnabled else { return }
            isEnabled ? startObserving() : stopObserving()
        }
    }

    // MARK: - Properties

    private unowned var managedObjectContext: NSManagedObjectContext

    private var notificationCenterTokens = [Any]()

    private let snapshotCenter: SnapshotCenter

    private let affectingKeysStore: DependencyKeyStore

    private var isTornDown = false

    private var changeInfoConsumers = [UnownedNSObject]()

    private var allChangeInfoConsumers: [ChangeInfoConsumer] {
        var consumers = changeInfoConsumers.compactMap{$0.unbox as? ChangeInfoConsumer}
        consumers.append(searchUserObserverCenter)
        consumers.append(conversationListObserverCenter)
        return consumers
    }

    private var conversationListObserverCenter: ConversationListObserverCenter {
        return managedObjectContext.conversationListObserverCenter
    }

    private var searchUserObserverCenter: SearchUserObserverCenter {
        return managedObjectContext.searchUserObserverCenter
    }
    
    private var allChanges = [ZMManagedObject: Changes]()
    private var unreadMessages = UnreadMessages()


    // MARK: - Life cycle
    
    public init(managedObjectContext: NSManagedObjectContext) {
        assert(
            managedObjectContext.zm_isUserInterfaceContext,
            "NotificationDispatcher needs to be initialized with uiMOC"
        )

        self.managedObjectContext = managedObjectContext

        let classIdentifiers = [
            ZMConversation.classIdentifier,
            ZMUser.classIdentifier,
            ZMConnection.classIdentifier,
            UserClient.classIdentifier,
            ZMMessage.classIdentifier,
            ZMClientMessage.classIdentifier,
            ZMAssetClientMessage.classIdentifier,
            ZMSystemMessage.classIdentifier,
            Reaction.classIdentifier,
            ZMGenericMessageData.classIdentifier,
            Team.classIdentifier,
            Member.classIdentifier,
            Label.classIdentifier,
            ParticipantRole.classIdentifier
        ]

        affectingKeysStore = DependencyKeyStore(classIdentifiers: classIdentifiers)
        snapshotCenter = SnapshotCenter(managedObjectContext: managedObjectContext)
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(NotificationDispatcher.objectsDidChange),
            name:.NSManagedObjectContextObjectsDidChange,
            object: managedObjectContext
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(NotificationDispatcher.contextDidSave),
            name:.NSManagedObjectContextDidSave,
            object: managedObjectContext
        )

        let token = NotificationInContext.addObserver(
            name: .NonCoreDataChangeInManagedObject,
            context: managedObjectContext.notificationContext,
            using: { [weak self] note in self?.nonCoreDataChange(note) }
        )

        notificationCenterTokens.append(token)
    }

    public func tearDown() {
        NotificationCenter.default.removeObserver(self)
        notificationCenterTokens.forEach(NotificationCenter.default.removeObserver)
        notificationCenterTokens = []
        conversationListObserverCenter.tearDown()
        isTornDown = true
    }

    deinit {
        assert(isTornDown)
    }

    // MARK: - Callbacks

    /// Call this when the application enters the background to stop sending notifications and clear current changes.

    @objc func applicationDidEnterBackground() {
        isEnabled = false
    }
    
    /// Call this when the application will enter the foreground to start sending notifications again.

    @objc func applicationWillEnterForeground() {
        isEnabled = true
    }

    // Called when objects in the context change, it may be called several times between saves.

    @objc func objectsDidChange(_ note: Notification) {
        guard isEnabled else { return }
        forwardChangesToConversationListObserver(note: note)
        process(note: note)
    }

    @objc func contextDidSave(_ note: Notification) {
        guard isEnabled else { return }
        fireAllNotifications()
    }
    
    /// This will be called if a change to an object does not cause a change in Core Data, e.g. downloading the asset and adding it to the cache.

    func nonCoreDataChange(_ note: NotificationInContext) {
        guard
            isEnabled,
            let changedKeys = note.changedKeys,
            let object = note.object as? ZMManagedObject
        else {
            return
        }
        
        let change = Changes(changedKeys: Set(changedKeys))
        let objectAndChangedKeys = [object: change]

        allChanges = allChanges.merged(with: objectAndChangedKeys)

        if managedObjectContext.zm_hasChanges {
            // Fire notifications via a save.
            managedObjectContext.enqueueDelayedSave()
        } else {
            fireAllNotifications()
        }
    }

    // MARK: - Methods

    // FIXME: [John] This is only used in Swift test. Either make non objc or remove entirely.
    /// Add the given consumer to receive forwarded `ChangeInfo`s.

    @objc public func addChangeInfoConsumer(_ consumer: ChangeInfoConsumer) {
        let boxed = UnownedNSObject(consumer as! NSObject)
        changeInfoConsumers.append(boxed)
    }

    /// Call this AFTER merging the changes from syncMOC into uiMOC.

    public func didMergeChanges(_ changedObjectIDs: Set<NSManagedObjectID>) {
        guard isEnabled else { return }

        let changedObjects = changedObjectIDs.compactMap {
            try? managedObjectContext.existingObject(with: $0) as? ZMManagedObject
        }

        extractChanges(from: Set(changedObjects))
        fireAllNotifications()
    }

    /// This can safely be called from any thread as it will switch to uiContext internally.

    public static func notifyNonCoreDataChanges(objectID: NSManagedObjectID, changedKeys: [String], uiContext: NSManagedObjectContext) {
        uiContext.performGroupedBlock {
            guard let uiMessage = try? uiContext.existingObject(with: objectID) else { return }

            NotificationInContext(
                name: .NonCoreDataChangeInManagedObject,
                context: uiContext.notificationContext,
                object: uiMessage,
                changedKeys: changedKeys
            ).post()
        }
    }

    private func stopObserving() {
        unreadMessages = UnreadMessages()
        allChanges = [:]
        snapshotCenter.clearAllSnapshots()
        allChangeInfoConsumers.forEach { $0.stopObserving() }
    }

    private func startObserving() {
        allChangeInfoConsumers.forEach { $0.startObserving() }
    }

    private func forwardChangesToConversationListObserver(note: Notification) {
        guard let userInfo = note.userInfo as? [String: Any] else { return }
        
        let insertedLabels = (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.compactMap{$0 as? Label} ?? []
        let deletedLabels = (userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>)?.compactMap{$0 as? Label} ?? []
        conversationListObserverCenter.folderChanges(inserted: insertedLabels, deleted: deletedLabels)
        
        let insertedConversations = (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.compactMap{$0 as? ZMConversation} ?? []
        let deletedConversations = (userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>)?.compactMap{$0 as? ZMConversation} ?? []
        conversationListObserverCenter.conversationsChanges(inserted: insertedConversations, deleted: deletedConversations)
    }

    private func process(note: Notification) {
        guard let objects = ExtractedObjects(notification: note) else { return }

        snapshotCenter.createSnapshots(for: objects.inserted)

        extractChanges(from: objects.updated.union(objects.refreshed))
        extractChangesCausedByInsertionOrDeletion(of: objects.inserted)
        extractChangesCausedByInsertionOrDeletion(of: objects.deleted)

        checkForUnreadMessages(insertedObjects: objects.inserted, updatedObjects: objects.updated)
    }

    private func extractChanges(from changedObjects: Set<ZMManagedObject>) {
        
        func getChangedKeysSinceLastSave(object: ZMManagedObject) -> Set<String> {
            var changedKeys = Set(object.changedValues().keys)

            if changedKeys.isEmpty || object.isFault  {
                // If the object is a fault, calling changedValues() will return an empty set.
                // Luckily we created a snapshot of the object before the merge happend which
                // we can use to compare the values.
                changedKeys = snapshotCenter.extractChangedKeysFromSnapshot(for: object)
            } else {
                snapshotCenter.updateSnapshot(for: object)
            }

            return changedKeys
        }
        
        // Check for changed keys and affected keys.
        let changes: [ZMManagedObject: Changes] = changedObjects.mapToDictionary{ object in
            // (1) Get all the changed keys since last Save.
            let changedKeys = getChangedKeysSinceLastSave(object: object)
            guard changedKeys.isNotEmpty else { return nil }
            
            // (2) Get affected changes.
            extractChangesCausedByChangeInObjects(updatedObject: object, knownKeys: changedKeys)
            
            // (3) Map the changed keys to affected keys, remove the ones that we are not reporting.
            let affectedKeys = changedKeys
                .map { affectingKeysStore.observableKeysAffectedByValue(object.classIdentifier, key: $0) }
                .reduce(Set()) { $0.union($1) }

            guard affectedKeys.isNotEmpty else { return nil }
            return Changes(changedKeys: affectedKeys)
        }

        // (4) Merge the changes with the other ones.
        allChanges = allChanges.merged(with: changes)
    }

    private func extractChangesCausedByChangeInObjects(updatedObject: ZMManagedObject, knownKeys: Set<String>) {
        // (1) All Updates in other objects resulting in changes on others,
        // e.g. changing a users name affects the conversation displayName.
        guard let object = updatedObject as? SideEffectSource else { return }
        let changedObjectsAndKeys = object.affectedObjectsAndKeys(keyStore: affectingKeysStore, knownKeys: knownKeys)
        allChanges = allChanges.merged(with: changedObjectsAndKeys)
    }

    private func extractChangesCausedByInsertionOrDeletion(of objects: Set<ZMManagedObject>) {
        // All inserts or deletes of other objects resulting in changes in others,
        // e.g. inserting a user affects the conversation displayName.
        objects.forEach { obj in
            guard let object = obj as? SideEffectSource else { return }
            let changedObjectsAndKeys = object.affectedObjectsForInsertionOrDeletion(keyStore: affectingKeysStore)
            allChanges = allChanges.merged(with: changedObjectsAndKeys)
        }
    }

    private func checkForUnreadMessages(insertedObjects: Set<ZMManagedObject>, updatedObjects: Set<ZMManagedObject>){
        let unreadUnsent = updatedObjects.lazy
            .compactMap { $0 as? ZMMessage }
            .filter { $0.deliveryState == .failedToSend }
            .collect()

        let newUnreads = insertedObjects.lazy
            .compactMap { $0 as? ZMMessage }
            .filter { $0.isUnreadMessage }

        let newUnreadMessages = newUnreads
            .filter { $0.knockMessageData == nil }
            .collect()

        let newUnreadKnocks = newUnreads
            .filter { $0.knockMessageData != nil }
            .collect()

        unreadMessages.unsent.formUnion(unreadUnsent)
        unreadMessages.messages.formUnion(newUnreadMessages)
        unreadMessages.knocks.formUnion(newUnreadKnocks)
    }

    private func fireAllNotifications() {
        let changes = allChanges
        let unreads = unreadMessages
        
        unreadMessages = UnreadMessages()
        allChanges = [:]
        
        var allChangeInfos = [ClassIdentifier: [ObjectChangeInfo]]()

        changes.forEach { object, changedKeys in
            guard
                let notificationName = (object as? ObjectInSnapshot)?.notificationName,
                let changeInfo = ObjectChangeInfo.changeInfo(for: object, changes: changedKeys)
            else {
                return
            }

            postNotification(
                name: notificationName,
                object: object,
                changeInfo: changeInfo
            )

            let classIdentifier = object.classIdentifier
            var previousChanges = allChangeInfos[classIdentifier] ?? []
            previousChanges.append(changeInfo)
            allChangeInfos[classIdentifier] = previousChanges
        }

        forwardNotificationToObserverCenters(changeInfos: allChangeInfos)
        fireNewUnreadMessagesNotifications(unreadMessages: unreads)
    }

    private func fireNewUnreadMessagesNotifications(unreadMessages: UnreadMessages) {
        unreadMessages.changeInfoByNotification.forEach {
            postNotification(name: $0, changeInfo: $1)
        }
    }
    
    private func forwardNotificationToObserverCenters(changeInfos: [ClassIdentifier: [ObjectChangeInfo]]) {
        allChangeInfoConsumers.forEach {
            $0.objectsDidChange(changes: changeInfos)
        }
    }

    private func postNotification(
        name: Notification.Name,
        object: AnyObject? = nil,
        changeInfo: ObjectChangeInfo
    ) {
        NotificationInContext(
            name: name,
            context: managedObjectContext.notificationContext,
            object: object,
            changeInfo: changeInfo
        ).post()
    }

}

private extension LazySequenceProtocol {

    func collect() -> [Element] {
        return Array(self)
    }
    
}

private extension Collection {

    var isNotEmpty: Bool {
        return !isEmpty
    }

}


typealias ObjectAndChanges = [ZMManagedObject: Changes]

