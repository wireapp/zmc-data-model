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
    
    static let ConversationChange = Notification.Name("ZMConversationChangedNotification")
    static let MessageChange = Notification.Name("ZMMessageChangedNotification")
    static let UserChange = Notification.Name("ZMUserChangedNotification")
    static let SearchUserChange = Notification.Name("ZMSearchUserChangedNotification")
    static let ConnectionChange = Notification.Name("ZMConnectionChangeNotification")
    static let UserClientChange = Notification.Name("ZMUserClientChangeNotification")
    static let NewUnreadMessage = Notification.Name("ZMNewUnreadMessageNotification")
    static let NewUnreadKnock = Notification.Name("ZMNewUnreadKnockNotification")
    static let NewUnreadUnsentMessage = Notification.Name("ZMNewUnreadUnsentMessageNotification")
    static let VoiceChannelStateChange = Notification.Name("ZMVoiceChannelStateChangeNotification")
    static let VoiceChannelParticipantStateChange = Notification.Name("ZMVoiceChannelParticipantStateChangeNotification")

    public static let NonCoreDataChangeInManagedObject = Notification.Name("NonCoreDataChangeInManagedObject")
    
    static var ignoredObservableIdentifiers : [String] {
        return [Reaction.entityName(), ZMGenericMessageData.entityName(), ZMConnection.entityName(), ZMSystemMessage.entityName()]
    }
    
    static func nameForObservable(with classIdentifier : String) -> Notification.Name? {
        switch classIdentifier {
        case ZMConversation.entityName():
            return .ConversationChange
        case ZMUser.entityName():
            return .UserChange
        case UserClient.entityName():
            return .UserClientChange
        case ZMMessage.entityName(), ZMClientMessage.entityName(), ZMAssetClientMessage.entityName():
            return .MessageChange
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
    
    func mapping<NewKey, NewValue>(keysMapping: ((Key) -> NewKey), valueMapping: ((Key, Value) -> NewValue?)) -> Dictionary<NewKey, NewValue> {
        var dict = Dictionary<NewKey, NewValue>()
        for (key, value) in self {
            if let newValue = valueMapping(key, value) {
                dict.updateValue(newValue, forKey: keysMapping(key))
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
}


extension Array where Element : Hashable {
    
    func mapToDictionary<Value>(with block: (Element) -> Value?) -> Dictionary<Element, Value> {
        var dict = Dictionary<Element, Value>()
        forEach {
            if let value = block($0) {
                dict.updateValue(value, forKey: $0)
            }
        }
        return dict
    }
    func mapToDictionaryWithOptionalValue<Value>(with block: (Element) -> Value?) -> Dictionary<Element, Value?> {
        var dict = Dictionary<Element, Value?>()
        forEach {
            dict.updateValue(block($0), forKey: $0)
        }
        return dict
    }
}

extension Set {
    
    func mapToDictionary<Value>(with block: (Element) -> Value?) -> Dictionary<Element, Value> {
        var dict = Dictionary<Element, Value>()
        forEach {
            if let value = block($0) {
                dict.updateValue(value, forKey: $0)
            }
        }
        return dict
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
    let changedKeys : Set<String>
    let originalChanges : [String : NSObject?]
    
    init(changedKeys: Set<String>) {
        self.changedKeys = changedKeys
        self.originalChanges = [:]
    }
    
    init(changedKeys: Set<String>, originalChanges : [String : NSObject?]) {
        self.changedKeys = changedKeys
        self.originalChanges = originalChanges
    }
    
    func merged(with other: Changes) -> Changes {
        return Changes(changedKeys: changedKeys.union(other.changedKeys), originalChanges: originalChanges.updated(other: other.originalChanges))
    }
}

// TODO Sabine: Does it make sense to replace ZMManagedObject with this?
//protocol IdentifiableClass {
//    static var classIdentifier : String { get }
//}
//
//extension ZMManagedObject : IdentifiableClass {
//    static var classIdentifier : String {
//        return entityName()
//    }
//}

protocol Countable {
    var count : Int { get }
}

extension NSOrderedSet : Countable {}
extension NSSet : Countable {}

typealias ClassIdentifier = String
typealias ObjectAndChanges = [NSObject : Changes]

public class NotificationDispatcher : NSObject {

    private unowned var managedObjectContext: NSManagedObjectContext
    
    private var tornDown = false
    private let affectingKeysStore : DependencyKeyStore
    private let voicechannelObserverCenter : VoicechannelObserverCenter
    private var messageWindowObserverCenter : MessageWindowObserverCenter {
        return managedObjectContext.messageWindowObserverCenter
    }
    private var conversationListObserverCenter : ConversationListObserverCenter {
        return managedObjectContext.conversationListObserverCenter
    }
    private var searchUserObserverCenter: SearchUserObserverCenter {
        return managedObjectContext.searchUserObserverCenter
    }
    private let snapshotCenter: SnapshotCenter
    
    private var allChanges : [ClassIdentifier : [NSObject : Changes]] = [:] 
    private var userChanges : [ZMManagedObject : Set<String>] = [:]
    private var unreadMessages : [Notification.Name : Set<ZMMessage>] = [:]
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
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
        self.snapshotCenter = SnapshotCenter(managedObjectContext: managedObjectContext)
        
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationDispatcher.objectsDidChange(_:)), name:.NSManagedObjectContextObjectsDidChange, object: self.managedObjectContext)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationDispatcher.contextDidSave(_:)), name:.NSManagedObjectContextDidSave, object: self.managedObjectContext)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationDispatcher.nonCoreDataChange(_:)), name:.NonCoreDataChangeInManagedObject, object: nil)
    }
    
    public func tearDown() {
        NotificationCenter.default.removeObserver(self)
        conversationListObserverCenter.tearDown()
        tornDown = true
    }
    
    deinit {
        assert(tornDown)
    }
    
    /// This is called when objects in the uiMOC change
    /// Might be called several times in between saves
    @objc func objectsDidChange(_ note: Notification){
        process(note: note)
        forwardChangesToConversationListObserver(note: note)
    }
    
    /// This is called when the uiMOC saved
    @objc func contextDidSave(_ note: Notification){
        fireAllNotifications()
        forwardChangesToConversationListObserver(note: note)
    }
    
    /// This will be called if a change to an object does not cause a change in Core Data, e.g. downloading the asset and adding it to the cache
    @objc func nonCoreDataChange(_ note: Notification){
        // TODO Sabine: add tests for this!
        guard let object = note.object as? ZMManagedObject,
              let changedKeys = (note.userInfo as? [String : [String]])?["changedKeys"]
        else { return }
        
        let classIdentifier = type(of: object).entityName()
        let change = Changes(changedKeys: Set(changedKeys))

        let objectAndChangedKeys = [object: change]
        allChanges[classIdentifier] = allChanges[classIdentifier]?.merged(with: objectAndChangedKeys) ?? objectAndChangedKeys
        // TODO Sabine: make sure that save is always called
        // e.g. there could be a timer that starts after every save / merge and is cancelled on every objectDidChange
        // Alternatively pass bool along (enforceSave) or just post notification immediately
        managedObjectContext.forceSaveOrRollback()
    }
    
    /// Forwards inserted and deleted conversations to the conversationList observer to update lists accordingly
    internal func forwardChangesToConversationListObserver(note: Notification) {
        guard let userInfo = note.userInfo as? [String: Any] else { return }
        
        let insertedObjects : [ZMConversation] = (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.flatMap{$0 as? ZMConversation} ?? []
        let objectsWithTempIDs = insertedObjects.filter{$0.objectID.isTemporaryID}
        try? self.managedObjectContext.obtainPermanentIDs(for:objectsWithTempIDs)
        snapshotCenter.snapshotInsertedObjects(insertedObjects: Set(insertedObjects))

        let deletedObjects = (userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>)?.flatMap{$0 as? ZMConversation} ?? []
        conversationListObserverCenter.conversationsChanges(inserted: insertedObjects,
                                                            deleted: deletedObjects,
                                                            accumulated: false)
    }
    
    /// Call this from syncStrategy BEFORE merging the changes from syncMOC into uiMOC
    /// Get updated objects from notifications userInfo and map them to objectIDs
    /// After merging call `didMergeChanges()`
    public func willMergeChanges(_ changes: Set<NSManagedObjectID>){
        snapshotCenter.willMergeChanges(changes: changes)
    }
    
    /// Call this from syncStrategy AFTER merging the changes from syncMOC into uiMOC
    public func didMergeChanges() {
        fireAllNotifications()
    }
    
    /// Call this from syncStrategy BEFORE merging the changes from syncMOC into uiMOC
    public func notifyUpdatedCallState(_ conversations: Set<ZMConversation>, notifyDirectly: Bool) {
        let updatedConversations = voicechannelObserverCenter.conversationsWithVoicechannelStateChange(updatedConversationsAndChangedKeys:
            conversations.mapToDictionary{Set($0.changedValues().keys)}
        )
        guard updatedConversations.count > 0 else { return }
        let classIdentifier = ZMConversation.entityName()
        let affectedKeys = affectingKeysStore.keyPathsAffectedByValue(classIdentifier, key: "voiceChannelState")
        let changes = Dictionary(keys: updatedConversations, repeatedValue: Changes(changedKeys: affectedKeys))
        allChanges[classIdentifier] = allChanges[ZMConversation.entityName()]?.merged(with: changes) ?? changes
    }
    
    func process(note: Notification) {
        guard let userInfo = note.userInfo as? [String : Any] else { return }

        let updatedObjects = extractObjects(for: NSUpdatedObjectsKey, from: userInfo)
        let refreshedObjects = extractObjects(for: NSRefreshedObjectsKey, from: userInfo)
        let insertedObjects = extractObjects(for: NSInsertedObjectsKey, from: userInfo)
        let deletedObjects = extractObjects(for: NSDeletedObjectsKey, from: userInfo)
        
        let usersWithNewImage = checkForChangedImages()
        let usersWithNewName = checkForDisplayNameUpdates(with: note)

        let updatedAndRefreshedObjects = updatedObjects.union(refreshedObjects).union(usersWithNewImage).union(usersWithNewName)
        
        
        let updatedObjectsByIdentifer = sortObjectsByEntityName(objects: updatedAndRefreshedObjects)
        extractChanges(from: updatedObjectsByIdentifer)
        extractChangesAffectedByInsertionOrDeletion(of: insertedObjects.union(deletedObjects))
        
        checkForUnreadMessages(insertedObjects: insertedObjects, updatedObjects:updatedObjects )
        
        userChanges = [:]
    }
    
    func extractObjects(for key: String, from userInfo: [String : Any]) -> Set<ZMManagedObject> {
        guard let objects = userInfo[key] else { return Set() }
        guard let expectedObjects = objects as? Set<ZMManagedObject> else {
            zmLog.warn("Unable to cast userInfo content to Set of ZMManagedObject. Is there a new entity that does not inherit form it?")
            return Set()
        }
        return expectedObjects
    }
    
    /// Checks if any messages that were inserted or updated are unread and fired notifications for those
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
        
        updateExisting(name: .NewUnreadUnsentMessage, newSet: unreadUnsent)
        updateExisting(name: .NewUnreadMessage, newSet: newUnreadMessages)
        updateExisting(name: .NewUnreadKnock, newSet: newUnreadKnocks)
    }
    
    func updateExisting(name: Notification.Name, newSet: [ZMMessage]) {
        let existingUnreadUnsent = unreadMessages[name]
        unreadMessages[name] = existingUnreadUnsent?.union(newSet) ?? Set(newSet)
    }
    
    /// Gets additional user changes from userImageCache
    func checkForChangedImages() -> Set<ZMManagedObject> {
        let largeImageChanges = managedObjectContext.zm_userImageCache?.usersWithChangedLargeImage
        let largeImageUsers = extractUsersWithImageChange(objectIDs: largeImageChanges,
                                                          changedKey: "imageMediumData")
        let smallImageChanges = managedObjectContext.zm_userImageCache?.usersWithChangedSmallImage
        let smallImageUsers = extractUsersWithImageChange(objectIDs: smallImageChanges,
                                                          changedKey: "imageSmallProfileData")
        managedObjectContext.zm_userImageCache?.usersWithChangedLargeImage = []
        managedObjectContext.zm_userImageCache?.usersWithChangedSmallImage = []
        return smallImageUsers.union(largeImageUsers)
    }
    
    
    func extractUsersWithImageChange(objectIDs: [NSManagedObjectID]?, changedKey: String) -> Set<ZMUser> {
        guard let objectIDs = objectIDs else { return Set() }
        var users = Set<ZMUser>()
        objectIDs.forEach { objectID in
            guard let user = (try? managedObjectContext.existingObject(with: objectID)) as? ZMUser else { return }
            var newValue = userChanges[user] ?? Set()
            newValue.insert(changedKey)
            userChanges[user] = newValue
            users.insert(user)
        }
        return users
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
        
        func getChangedKeysSinceLastSave(object: ZMManagedObject) -> Set<String> {
            var changedKeys = Set(object.changedValues().keys)
            if changedKeys.count == 0 || object.isFault  {
                // If the object is a fault, calling changedValues() will return an empty set
                // Luckily we created a snapshot of the object before the merge happend which we can use to compare the values
                changedKeys = snapshotCenter.extractChangedKeysFromSnapshot(for: object)
            } else {
                snapshotCenter.removeSnapshot(for:object)
            }
            if let knownKeys = userChanges[object] {
                changedKeys = changedKeys.union(knownKeys)
            }
            return changedKeys
        }
        
        // Check for changed keys and affected keys
        changedObjects.forEach{ (classIdentifier, objects) in
            let observable = Observable(classIdentifier: classIdentifier, affectingKeyStore: affectingKeysStore)
            
            let changes : [NSObject: Changes] = objects.mapToDictionary{ object in
                // (1) Get all the changed keys since last Save
                let changedKeys = getChangedKeysSinceLastSave(object: object)
                guard changedKeys.count > 0 else { return nil }

                // (2) Map the changed keys to affected keys, remove the ones that we are not reporting
                let relevantKeysAndOldValues = changedKeys.intersection(observable.observableKeys)
                let affectedKeys = changedKeys.map{observable.keyPathsAffectedByValue(for: $0)}
                    .reduce(Set()){$0.union($1)}
                    .intersection(observable.observableKeys)
                
                extractChangesAffectedByChangeInObjects(updatedObject: object, knownKeys: changedKeys)
                guard relevantKeysAndOldValues.count > 0 || affectedKeys.count > 0 else { return nil }
                return Changes(changedKeys: relevantKeysAndOldValues.union(affectedKeys))
            }
            
            // (3) Merge the changes with the other ones
            let value = allChanges[observable.classIdentifier]
            allChanges[observable.classIdentifier] = value?.merged(with: changes) ?? changes
        }
    }
    
    /// Get all changes that resulted from other objects through dependencies (e.g. user.name -> conversation.displayName)
    func extractChangesAffectedByChangeInObjects(updatedObject:  ZMManagedObject, knownKeys : Set<String>)
    {
        // (1) All Updates in other objects resulting in changes on others
        // e.g. changing a users name affects the conversation displayName
        guard let object = updatedObject as? SideEffectSource else { return }
        let knownKeys = knownKeys.union(userChanges[updatedObject] ?? Set())
        let changedObjectsAndKeys = object.affectedObjectsAndKeys(keyStore: affectingKeysStore, knownKeys: knownKeys)
        changedObjectsAndKeys.forEach{ classIdentifier, changedObjects in
            allChanges[classIdentifier] = allChanges[classIdentifier]?.merged(with: changedObjects) ?? changedObjects
        }
    }
    
    /// Get all changes that resulted from other objects through dependencies (e.g. user.name -> conversation.displayName)
    func extractChangesAffectedByInsertionOrDeletion(of objects: Set<ZMManagedObject>)
    {
        // All inserts or deletes of other objects resulting in changes in others
        // e.g. inserting a user affects the conversation displayName
        objects.forEach{ (obj) in
            guard let object = obj as? SideEffectSource else { return }
            let changedObjectsAndKeys = object.affectedObjectsForInsertionOrDeletion(keyStore: affectingKeysStore)
            changedObjectsAndKeys.forEach{ classIdentifier, changedObjects in
                allChanges[classIdentifier] = allChanges[classIdentifier]?.merged(with: changedObjects) ?? changedObjects
            }
        }
    }
    
    func fireAllNotifications(){
        allChanges.forEach{ (classIdentifier, changes) in
            guard let notificationName = Notification.Name.nameForObservable(with: classIdentifier) else { return }
            let notifications : [Notification] = changes.flatMap{
                guard let obj = $0 as? ZMManagedObject,
                      let changeInfo = NotificationDispatcher.changeInfo(for: obj, changes: $1)
                else { return nil }
                forwardNotificationToObserverCenters(changeInfo: changeInfo)
                return Notification(name: notificationName, object: $0, userInfo: ["changeInfo" : changeInfo])
            }
            notifications.forEach{NotificationCenter.default.post($0)}
        }
        fireNewUnreadMessagesNotifications()
        messageWindowObserverCenter.fireNotifications()
        unreadMessages = [:]
        allChanges = [:]
    }
    
    /// Fire all new unread notifications
    func fireNewUnreadMessagesNotifications(){
        unreadMessages.forEach{ (notificationName, messages) in
            guard messages.count > 0 else { return }
            guard let changeInfo = NotificationDispatcher.changeInfoforNewMessageNotification(with: notificationName, changedMessages: messages) else {
                zmLog.warn("Did you forget to add the mapping for that?")
                return
            }
            let notification = Notification(name: notificationName, object:nil, userInfo: ["changeInfo" : changeInfo])
            NotificationCenter.default.post(notification)
        }
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
    
    func forwardNotificationToObserverCenters(changeInfo: ObjectChangeInfo){
        if let changeInfo = changeInfo as? ConversationChangeInfo {
            conversationListObserverCenter.conversationDidChange(changeInfo)
            messageWindowObserverCenter.conversationDidChange(changeInfo)
        }
        if let changeInfo = changeInfo as? UserChangeInfo {
            searchUserObserverCenter.usersDidChange(changeInfos: [changeInfo])
            messageWindowObserverCenter.userDidChange(changeInfo: changeInfo)
        }
        if let changeInfo = changeInfo as? MessageChangeInfo {
            messageWindowObserverCenter.messageDidChange(changeInfo: changeInfo)
        }
    }
    
    static func changeInfo(for object: ZMManagedObject, changes: Changes) -> ObjectChangeInfo? {
        switch object {
        case let object as ZMConversation:  return ConversationChangeInfo.changeInfo(for: object, changes: changes)
        case let object as ZMUser:          return UserChangeInfo.changeInfo(for: object, changes: changes)
        case let object as ZMMessage:       return MessageChangeInfo.changeInfo(for: object, changes: changes)
        case let object as UserClient:      return UserClientChangeInfo.changeInfo(for: object, changes: changes)
        default:
            return nil
        }
    }
    
    static func changeInfoforNewMessageNotification(with name: Notification.Name, changedMessages messages: Set<ZMMessage>) -> ObjectChangeInfo? {
        switch name {
        case Notification.Name.NewUnreadUnsentMessage: return NewUnreadUnsentMessageChangeInfo(messages: Array(messages) as [ZMConversationMessage])
        case Notification.Name.NewUnreadMessage:       return NewUnreadMessagesChangeInfo(messages:      Array(messages) as [ZMConversationMessage])
        case Notification.Name.NewUnreadKnock:         return NewUnreadKnockMessagesChangeInfo(messages: Array(messages) as [ZMConversationMessage])
        default:
            return nil
        }
    }
}

extension NotificationDispatcher {

    
    public static func notifyNonCoreDataChanges(objectID: NSManagedObjectID, changedKeys: [String], uiContext: NSManagedObjectContext) {
        uiContext.performGroupedBlock {
            guard let uiMessage = try? uiContext.existingObject(with: objectID) else { return }
            NotificationCenter.default.post(name: .NonCoreDataChangeInManagedObject,
                                            object: uiMessage,
                                            userInfo: ["changedKeys" : changedKeys])
        }
    }
}
