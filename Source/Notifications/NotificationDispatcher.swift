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

    static var ignoredObservableIdentifiers : [String] {
        return [Reaction.entityName(), ZMGenericMessageData.entityName(), ZMConnection.entityName()]
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
    private let changedKeys : Set<String>
    let originalChanges : [String : NSObject?]
    
    var changedKeysAndNewValues : [String : NSObject?] {
        let changes = Dictionary(keys: Array(changedKeys), repeatedValue: .none as Optional<NSObject>)
        return changes.updated(other: originalChanges)
    }
    
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
    private unowned var syncContext: NSManagedObjectContext
    
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
        self.snapshotCenter = SnapshotCenter(managedObjectContext: managedObjectContext)
        
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationDispatcher.objectsDidChange(_:)), name:NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: self.managedObjectContext)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationDispatcher.contextDidSave(_:)), name:NSNotification.Name.NSManagedObjectContextDidSave, object: self.managedObjectContext)
    }
    
    public func tearDown() {
        NotificationCenter.default.removeObserver(self)
        conversationListObserverCenter.tearDown()
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
        
        guard let userInfo = note.userInfo as? [String: Any] else { return }
        let insertedObjects = (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.flatMap{$0 as? ZMConversation} ?? []
        let deletedObjects = (userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>)?.flatMap{$0 as? ZMConversation} ?? []
        conversationListObserverCenter.conversationsChanges(inserted: insertedObjects,
                                                            deleted: deletedObjects,
                                                            accumulated: false)
    }
    
    public func willMergeChanges(changes: [NSManagedObjectID]){
        snapshotCenter.willMergeChanges(changes: changes)
    }
    
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
        extractChangesAffectedByChangeInObjects(insertedObjects: insertedObjects,
                                                updatedObjects: updatedAndRefreshedObjects,
                                                deletedObjects: deletedObjects)
        
        // Sort the changes by class
        let updatedObjectsByIdentifer = sortObjectsByEntityName(objects: updatedAndRefreshedObjects)
        extractChanges(from: updatedObjectsByIdentifer)
        
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
        let largeImageChanges = managedObjectContext.zm_userImageCache.usersWithChangedLargeImage
        largeImageChanges.forEach { user in
            var newValue = userChanges[user] ?? Set()
            newValue.insert("imageMediumData")
            userChanges[user] = newValue
        }
        let smallImageChanges = managedObjectContext.zm_userImageCache.usersWithChangedSmallImage
        smallImageChanges.forEach { user in
            var newValue = userChanges[user] ?? Set()
            newValue.insert("imageSmallProfileData")
            userChanges[user] = newValue
        }
        managedObjectContext.zm_userImageCache.usersWithChangedLargeImage = []
        managedObjectContext.zm_userImageCache.usersWithChangedSmallImage = []
        return Set(largeImageChanges + smallImageChanges)
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
            if changedKeys.count == 0 || object.isFault {
                // If the object is a fault, calling changedValues() will return an empty set
                // Luckily we created a snapshot of the object before the merge happend which we can use to compare the values
                changedKeys = snapshotCenter.extractChangedKeysFromSnapshot(for: object)
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
                guard relevantKeysAndOldValues.count > 0 || affectedKeys.count > 0 else { return nil }
                return Changes(changedKeys: relevantKeysAndOldValues.union(affectedKeys))
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
            let changedObjectsAndKeys = object.affectedObjectsForInsertionOrDeletion(keyStore: affectingKeysStore)
            changedObjectsAndKeys.forEach{ classIdentifier, changedObjects in
                allChanges[classIdentifier] = allChanges[classIdentifier]?.merged(with: changedObjects) ?? changedObjects
            }
        }
        // (3) All deletes of other objects resulting in changes in others
        // e.g. inserting a user affects the conversation displayName
        deletedObjects.forEach{ (obj) in
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
                      let changeInfo = NotificationDispatcher.changeInfo(for: obj, changes: $1.changedKeysAndNewValues)
                else { return nil }
                if let changeInfo = changeInfo as? ConversationChangeInfo {
                    conversationListObserverCenter.conversationDidChange(changeInfo)
                    messageWindowObserverCenter.conversationDidChange(changeInfo)
                }
                if let changeInfo = changeInfo as? UserChangeInfo {
                    searchUserObserverCenter.usersDidChange(changeInfos: [changeInfo])
                }
                if let changeInfo = changeInfo as? MessageChangeInfo {
                    messageWindowObserverCenter.messageDidChange(changeInfo: changeInfo)
                }
                return Notification(name: notificationName, object: $0, userInfo: ["changeInfo" : changeInfo])
            }
            notifications.forEach{NotificationCenter.default.post($0)}
        }
        fireNewUnreadMessagesNotifications()
        messageWindowObserverCenter.fireNotifications()
        unreadMessages = [:]
        allChanges = [:]
        snapshotCenter.clearSnapshots()
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
    
    static func changeInfo(for object: ZMManagedObject, changes: [String: NSObject?]) -> ObjectChangeInfo? {
        switch object {
        case let object as ZMConversation:  return ConversationChangeInfo.changeInfo(for: object, changedKeys: changes)
        case let object as ZMUser:          return UserChangeInfo.changeInfo(for: object, changedKeys: changes)
        case let object as ZMMessage:       return MessageChangeInfo.changeInfo(for: object, changedKeys: changes)
        case let object as UserClient:      return UserClientChangeInfo.changeInfo(for: object, changedKeys: changes)
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
