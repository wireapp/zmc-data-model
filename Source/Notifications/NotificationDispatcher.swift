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

private var zmLog = ZMSLog(tag: "notifications")

protocol OpaqueConversationToken : NSObjectProtocol {}

let ChangedKeysAndNewValuesKey = "ZMChangedKeysAndNewValues"

extension Notification.Name {
    
    static let ConversationChangeNotification = Notification.Name("ZMConversationChangedNotification")
    static let MessageChangeNotification = Notification.Name("ZMMessageChangedNotification")
    static let UserChangeNotification = Notification.Name("ZMUserChangedNotification")
    static let ConnectionChangeNotification = Notification.Name("ZMConnectionChangeNotification")
    static let UserClientChangeNotification = Notification.Name("ZMUserClientChangeNotification")
    static let NewUnreadMessageNotification = Notification.Name("ZMNewUnreadMessageNotification")
    static let NewUnreadKnockNotification = Notification.Name("ZMNewUnreadKnockNotification")
    static let NewUnreadUnsentMessageNotification = Notification.Name("ZMNewUnreadUnsentMessageNotification")
    static let VoiceChannelStateChangeNotification = Notification.Name("ZMVoiceChannelStateChangeNotification")
    static let VoiceChannelParticipantStateChangeNotification = Notification.Name("ZMVoiceChannelParticipantStateChangeNotification")

    static var ignoredObservableIdentifiers : [String] {
        return [Reaction.entityName(), ZMGenericMessageData.entityName()]
    }
    
    static func nameForObservable(with classIdentifier : String) -> Notification.Name? {
        switch classIdentifier {
        case ZMConversation.entityName():
            return .ConversationChangeNotification
        case ZMUser.entityName():
            return .UserChangeNotification
        case ZMConnection.entityName():
            return .ConnectionChangeNotification
        case UserClient.entityName():
            return .UserClientChangeNotification
        case ZMMessage.entityName(), ZMClientMessage.entityName(), ZMAssetClientMessage.entityName():
            return .MessageChangeNotification
        default:
            if !ignoredObservableIdentifiers.contains(classIdentifier) {
                zmLog.warn("There is no NotificationName defined for \(classIdentifier)")
            }
            return nil
        }
    }
}

extension Dictionary {

    init(keys: [Key], repeatedValue: Value) {
        self.init()
        for key in keys {
            updateValue(repeatedValue, forKey: key)
        }
    }
    
    static func mappingKeysToValues(keys: [Key], valueMapping: ((Key) -> Value?)) -> Dictionary {
        var dict = Dictionary()
        keys.forEach {
            if let value = valueMapping($0) {
                dict.updateValue(value, forKey: $0)
            }
        }
        return dict
    }
    
    func updated(other:Dictionary) -> Dictionary {
        var newDict = self
        for (key,value) in other {
            newDict.updateValue(value, forKey:key)
        }
        return newDict
    }

    func removingKeysNotIn(set: Set<Key>) -> Dictionary {
        var newDict = self
        keys.forEach{
            if !set.contains($0) {
                newDict.removeValue(forKey: $0)
            }
        }
        return newDict
    }
}

protocol Mergeable {
    func merged(with other: Self) -> Self
}

extension Dictionary where Value : Mergeable {
    
    func merged(with other: Dictionary) -> Dictionary {
        var newDict = self
        other.forEach{ (key, value) in
            newDict[key] = newDict[key]?.merged(with: value) ?? value
        }
        return newDict
    }
}

struct Changes : Mergeable {
    private let changedKeys : Set<String>
    let changedKeysAndNewValues : [String : NSObject?]
    
    init(changedKeys: Set<String>) {
        self.changedKeys = changedKeys
        self.changedKeysAndNewValues = changedKeys.reduce([:]){ (dict, value) in
            var newDict = dict
            if dict[value] == nil {
                newDict[value] = .none as NSObject?
            }
            return newDict
        }
    }

    init(changedKeysAndNewValues : [String : NSObject?]){
        self.init(changedKeys: Set(changedKeysAndNewValues.keys), changedKeysAndNewValues: changedKeysAndNewValues)
    }
    
    init(changedKeys: Set<String>, changedKeysAndNewValues : [String : NSObject?]) {
        self.changedKeys = changedKeys
        let mappedChangedKeys : [String : NSObject?] = changedKeys.reduce([:]){ (dict, value) in
            var newDict = dict
            if dict[value] == nil {
                newDict[value] = .none as NSObject?
            }
            return newDict
        }
        self.changedKeysAndNewValues = mappedChangedKeys.updated(other: changedKeysAndNewValues)
    }
    
    func merged(with other: Changes) -> Changes {
        return Changes(changedKeys: changedKeys.union(other.changedKeys), changedKeysAndNewValues: changedKeysAndNewValues.updated(other: other.changedKeysAndNewValues))
    }
}



struct Observable {
    
    private let affectingKeyStore: DependencyKeyStore
    let classIdentifier : String
    private let affectingKeys : [String : Set<String>]
    private let affectedKeys : [String : Set<String>]

    /// Keys that we want to report changes for
    var observableKeys : Set<String> {
        return affectingKeyStore.observableKeys[classIdentifier] ?? Set()
    }
    
    /// Union of observable keys and their affecting keys
    var allKeys : Set<String> {
        return affectingKeyStore.allKeys[classIdentifier] ?? Set()
    }
    
    init(classIdentifier: String, affectingKeyStore: DependencyKeyStore) {
        self.classIdentifier = classIdentifier
        self.affectingKeyStore = affectingKeyStore
        self.affectingKeys = affectingKeyStore.affectingKeys[classIdentifier] ?? [:]
        self.affectedKeys = affectingKeyStore.effectedKeys[classIdentifier] ?? [:]
    }
    
    func keyPathsForValuesAffectingValue(for key: String) -> Set<String>{
        return affectingKeys[key] ?? Set()
    }
    
    func keyPathsAffectedByValue(for key: String) -> Set<String>{
        var keys = affectedKeys[key] ?? Set()
        if observableKeys.contains(key) {
            keys.insert(key)
        }
        return keys
    }
}


public class NotificationDispatcher : NSObject {

    private unowned var managedObjectContext: NSManagedObjectContext
    private unowned var syncContext: NSManagedObjectContext
    
    private var tornDown = false
    private let affectingKeysStore : DependencyKeyStore
    private let voicechannelObserverCenter : VoicechannelObserverCenter
    
    private var allChanges : [String : [NSObject : Changes]] = [:]
    private var snapshots : [NSManagedObjectID : [String : NSObject?]] = [:]
    private var userChanges : [ZMManagedObject : Set<String>] = [:]
    private var unreadMessages : [Notification.Name : Set<ZMMessage>] = [:]
    
    public init(managedObjectContext: NSManagedObjectContext, syncContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        self.syncContext = syncContext
        let classIdentifiers : [String] = [ZMConversation.entityName(),
                                           ZMUser.entityName(),
                                           ZMConnection.entityName(),
                                           UserClient.entityName(),
                                           ZMMessage.entityName(),
                                           ZMClientMessage.entityName(),
                                           ZMAssetClientMessage.entityName(),
                                           Reaction.entityName(),
                                           ZMGenericMessageData.entityName()]
        let affectingKeysStore = DependencyKeyStore(classIdentifiers : classIdentifiers)
        self.affectingKeysStore = affectingKeysStore
        self.voicechannelObserverCenter = VoicechannelObserverCenter()
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationDispatcher.objectsDidChange(_:)), name:NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: self.managedObjectContext)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationDispatcher.contextDidSave(_:)), name:NSNotification.Name.NSManagedObjectContextDidSave, object: self.managedObjectContext)
    }
    
    public func tearDown() {
        NotificationCenter.default.removeObserver(self)
        tornDown = true
    }
    
    deinit {
        assert(tornDown)
    }
    
    @objc func objectsDidChange(_ note: Notification){
        process(note: note)
    }
    
    @objc func contextDidSave(_ note: Notification){
        fireAllNotifications()
    }
    
    // TODO Sabine: When do we get rid of those?
    /// This function needs to be called when the sync context saved and we receive the NSManagedObjectContextDidSave notification and before the changes are merged into the UI context
    public func willMergeChanges(changes: [NSManagedObjectID]){
        // TODO Sabine do I need to wrap this in a block?
        managedObjectContext.performGroupedBlock { [weak self] in
            guard let `self` = self else { return }
            self.snapshots = Dictionary.mappingKeysToValues(keys: changes){ objectID in
                guard let obj = (try? self.managedObjectContext.existingObject(with: objectID)) else { return [:] }
                let attributes = obj.entity.attributesByName.keys
                return Dictionary.mappingKeysToValues(keys: Array(attributes)){
                    obj.primitiveValue(forKey: $0) as? NSObject
                }
            }
        }
    }
    
    public func notifyUpdatedCallState(_ conversations: Set<ZMConversation>, notifyDirectly: Bool) {
        voicechannelObserverCenter.recalculateStateIfNeeded(updatedConversationsAndChangedKeys:
            Dictionary.mappingKeysToValues(keys: Array(conversations)){
                Set($0.changedValues().keys)
            }
        )
    }
    
    func process(note: Notification) {
        guard let userInfo = note.userInfo as? [String : Any] else { return }

        let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<ZMManagedObject> ?? Set()
        let refreshedObjects = userInfo[NSRefreshedObjectsKey] as? Set<ZMManagedObject> ?? Set()
        let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<ZMManagedObject> ?? Set()
        let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<ZMManagedObject> ?? Set()
        
        let usersWithNewImage = checkForChangedImages()
        let usersWithNewName = checkForDisplayNameUpdates(with: note)

        let updatedAndRefreshedObjects = updatedObjects.union(refreshedObjects).union(usersWithNewImage).union(usersWithNewName)
        extractChangesAffectedByChangeInObjects(insertedObjects: insertedObjects,
                                                updatedObjects: updatedAndRefreshedObjects,
                                                deletedObjects: deletedObjects)
        
        // Sort the changes by class
        let updatedObjectsByIdentifer = sortObjectsByEntityName(objects: updatedAndRefreshedObjects)
        extractChanges(from: updatedObjectsByIdentifer)
        
        checkForUnreadMessages(insertedObjects: insertedObjects, updatedObjects:updatedObjects )
        
        userChanges = [:]
    }
    
    func checkForUnreadMessages(insertedObjects: Set<ZMManagedObject>, updatedObjects: Set<ZMManagedObject>){
        let unreadUnsent : [ZMMessage] = updatedObjects.flatMap{
            guard let msg = $0 as? ZMMessage else { return nil}
            return (msg.deliveryState == .failedToSend) ? msg : nil
        }
        let (newUnreadMessages, newUnreadKnocks) = insertedObjects.reduce(([ZMMessage](),[ZMMessage]())) {
            guard let msg = $1 as? ZMMessage, msg.isUnreadMessage else { return $0 }
            var (messages, knocks) = $0
            if msg.knockMessageData == nil {
                messages.append(msg)
            } else {
                knocks.append(msg)
            }
            return (messages, knocks)
        }
        
        updateExisting(name: .NewUnreadUnsentMessageNotification, newSet: unreadUnsent)
        updateExisting(name: .NewUnreadMessageNotification, newSet: newUnreadMessages)
        updateExisting(name: .NewUnreadKnockNotification, newSet: newUnreadKnocks)
    }
    
    func updateExisting(name: Notification.Name, newSet: [ZMMessage]) {
        let existingUnreadUnsent = unreadMessages[name]
        unreadMessages[name] = existingUnreadUnsent?.union(newSet) ?? Set(newSet)
    }
    
    /// Gets additional user changes from userImageCache
    func checkForChangedImages() -> Set<ZMManagedObject> {
        let changedUsers = managedObjectContext.zm_userImageCache.changedUsersSinceLastSave
        changedUsers.forEach { user in
            var newValue = userChanges[user] ?? Set()
            newValue.insert("imageMediumData")
            userChanges[user] = newValue
        }
        managedObjectContext.zm_userImageCache.changedUsersSinceLastSave = []
        return Set(changedUsers)
    }
    
    
    /// Gets additional changes from UserDisplayNameGenerator
    func checkForDisplayNameUpdates(with note: Notification) -> Set<ZMManagedObject> {
        let updatedUsers = managedObjectContext.updateDisplayNameGenerator(withChanges: note) as! Set<ZMUser>
        updatedUsers.forEach{ user in
            var newValue = userChanges[user] ?? Set()
            newValue.insert("displayName")
            userChanges[user] = newValue
        }
        return updatedUsers
    }
    
    /// Extracts changes from the updated objects
    func extractChanges(from changedObjects: [String : Set<ZMManagedObject>]) {
        
        func getChangedKeysSinceLastSave(object: ZMManagedObject) -> [String : NSObject?] {
            var changedKeysAndNewValues = object.changedValues() as? [String : NSObject?] ?? [:]
            if changedKeysAndNewValues.count == 0 && object.isFault {
                // If the object is a fault, calling changedValues() will return an empty set
                // Luckily we created a snapshot of the object before the merge happend which we can use to compare the values
                if let snapshot = snapshots[object.objectID] {
                    changedKeysAndNewValues = extractChangedKeysFromSnapshot(snapshot: snapshot, for: object)
                    snapshots.removeValue(forKey: object.objectID)
                }
            }
            if let knownKeys = userChanges[object] {
                changedKeysAndNewValues = changedKeysAndNewValues.updated(other: Dictionary(keys: Array(knownKeys), repeatedValue: .none as Optional<NSObject>))
            }
            return changedKeysAndNewValues
        }
        
        // Check for changed keys and affected keys
        changedObjects.forEach{ (classIdentifier, objects) in
            let observable = Observable(classIdentifier: classIdentifier, affectingKeyStore: affectingKeysStore)
            
            let changes : [NSObject: Changes] = Dictionary.mappingKeysToValues(keys: Array(objects)){ object in
                // (1) Get all the changed keys since last Save
                let changedKeysAndNewValues = getChangedKeysSinceLastSave(object: object)
                guard changedKeysAndNewValues.count > 0 else { return nil }

                // (2) Map the changed keys to affected keys, remove the ones that we are not reporting
                let relevantKeysAndOldValues = changedKeysAndNewValues.removingKeysNotIn(set: observable.observableKeys)
                let affectedKeys = changedKeysAndNewValues.keys.map{observable.keyPathsAffectedByValue(for: $0)}
                    .reduce(Set()){$0.union($1)}
                    .intersection(observable.observableKeys)
                guard relevantKeysAndOldValues.count > 0 || affectedKeys.count > 0 else { return nil }
                return Changes(changedKeys: affectedKeys, changedKeysAndNewValues: relevantKeysAndOldValues)
            }
            
            // (3) Merge the changes with the other ones
            let value = allChanges[observable.classIdentifier]
            allChanges[observable.classIdentifier] = value?.merged(with: changes) ?? changes
        }
    }
    
    /// Get all changes that resulted from other objects through dependencies (e.g. user.name -> conversation.displayName)
    func extractChangesAffectedByChangeInObjects(insertedObjects: Set<ZMManagedObject>,
                                                 updatedObjects:  Set<ZMManagedObject>,
                                                 deletedObjects:  Set<ZMManagedObject>)
    {
            // (1) All Updates in other objects resulting in changes on others
            // e.g. changing a users name affects the conversation displayName
            updatedObjects.forEach{ (obj) in
                guard let object = obj as? SideEffectSource else { return }
                let knownKeys = obj is ZMUser ? (userChanges[obj] ?? Set()) : Set()
                let changedObjectsAndKeys = object.affectedObjectsAndKeys(keyStore: affectingKeysStore, knownKeys: knownKeys)
                changedObjectsAndKeys.forEach{ classIdentifier, changedObjects in
                    allChanges[classIdentifier] = allChanges[classIdentifier]?.merged(with: changedObjects) ?? changedObjects
                }
            }
            // (2) All inserts of other objects resulting in changes in others
            // e.g. inserting a user affects the conversation displayName
            insertedObjects.forEach{ (obj) in
                guard let object = obj as? SideEffectSource else { return }
                let changedObjectsAndKeys = object.affectedObjectsAndKeysForInsertion(keyStore: affectingKeysStore)
                changedObjectsAndKeys.forEach{ classIdentifier, changedObjects in
                    allChanges[classIdentifier] = allChanges[classIdentifier]?.merged(with: changedObjects) ?? changedObjects
                }
            }
    }
    
    /// Before merging the sync into the ui context, we create a snapshot of all changed objects
    /// This function compares the snapshot values to the current ones and returns all keys and new values where the value changed due to the merge
    func extractChangedKeysFromSnapshot(snapshot: [String : NSObject?], for object: NSObject) -> [String : NSObject?] {
        var changedKeysAndNewValues = [String : NSObject?]()
        snapshot.forEach{ (key, oldValue) in
            let currentValue = object.value(forKey: key) as? NSObject
            if currentValue != oldValue {
                changedKeysAndNewValues[key] = currentValue
            }
        }
        return changedKeysAndNewValues
    }
    
    func fireAllNotifications(){
        allChanges.forEach{ (classIdentifier, changes) in
            guard let notificationName = Notification.Name.nameForObservable(with: classIdentifier) else { return }
            let notifications : [Notification] = changes.flatMap{Notification(name: notificationName,
                                                                              object: $0,
                                                                              userInfo: [ChangedKeysAndNewValuesKey : $1.changedKeysAndNewValues])
            }
            notifications.forEach{NotificationCenter.default.post($0)}
        }
        unreadMessages.forEach{ (notificationName, messages) in
            guard messages.count > 0 else { return }
            let notification = Notification(name: notificationName, object: Array(messages), userInfo: nil)
            NotificationCenter.default.post(notification)
        }
        unreadMessages = [:]
        allChanges = [:]
        snapshots = [:]
    }
    
    /// Sorts all objects by entityName, e.g. ["ZMConversation" : Set(conversation1, conversation2), "ZMUser" : Set(user1, user2)]
    private func sortObjectsByEntityName(objects: Set<ZMManagedObject>) ->  [String : Set<ZMManagedObject>]{
        let objectsSortedByClass = objects.reduce([String : Set<ZMManagedObject>]()){ (dict, object) in
            let name = type(of: object).entityName()
            var values = dict[name] ?? Set<ZMManagedObject>()
            values.insert(object)
            
            var newDict = dict
            newDict[name] = values
            return newDict
        }
        return objectsSortedByClass
    }
}
