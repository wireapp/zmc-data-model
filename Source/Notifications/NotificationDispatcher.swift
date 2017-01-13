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

let ChangedKeysAndOldValuesKey = "ZMChangedKeysAndOldValues"

extension Notification.Name {
    
    static let ConversationChangeNotification = Notification.Name("ZMConversationChangedNotification")
    static let MessageChangeNotification = Notification.Name("ZMMessageChangedNotification")
    static let UserChangeNotification = Notification.Name("ZMUserChangedNotification")
    static let ConnectionChangeNotification = Notification.Name("ZMConnectionChangeNotification")
    
    static func nameForObservable(with classIdentifier : String) -> Notification.Name? {
        switch classIdentifier {
        case ZMConversation.entityName():
            return Notification.Name.ConversationChangeNotification
        case ZMUser.entityName():
            return Notification.Name.UserChangeNotification
        case ZMConnection.entityName():
            return Notification.Name.ConnectionChangeNotification
        default:
            zmLog.warn("There is no NotificationName defined for \(classIdentifier)")
            return nil
        }
    }
}


extension ZMUser : SideEffectSource {
    
    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMConversation.entityName():
            let otherPartKeys = changedValues().keys.map{"otherActiveParticipants.\($0)"}
            let selfUserKeys = changedValues().keys.map{"connection.to.\($0)"}
            let mappedKeys = Array(otherPartKeys)+Array(selfUserKeys)+["otherActiveParticipants", "connection.to"]
            
            let affectedKeys = Set<String>(observable.observableKeys.flatMap {
                if !observable.keyPathsForValuesAffectingValue(for: $0).isDisjoint(with: mappedKeys) {
                    return $0
                }
                return nil
            })
            guard affectedKeys.count > 0 else { return [:] }
            
            var conversations = activeConversations.array as? [ZMConversation] ?? []
            if let connectedConversation = connection?.conversation {
                conversations.append(connectedConversation)
            }
            guard conversations.count > 0 else { return  [:] }
            let conversationMap : [NSObject : Changes] = Dictionary(keys: conversations,
                                                                    repeatedValue: Changes(changedKeys: affectedKeys))
            return conversationMap
        default:
            return [:]
        }
    }
    
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMConversation.entityName():
            let changes = Changes(changedKeys: observable.keyPathsAffectedByValue(for: "otherActiveParticipants"))
            let conversations = activeConversations.array as? [ZMConversation] ?? []
            var conversationMap : [NSObject : Changes] = Dictionary(keys: conversations,
                                                                    repeatedValue: changes)

            if let connectedConversation = connection?.conversation {
                conversationMap[connectedConversation] = changes
            }
            return conversationMap
        default:
            return [:]
        }
    }
}

extension ZMMessage : SideEffectSource {

    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes] {
        return [:]
    }
    
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMConversation.entityName():
            guard let conversation = conversation else { return  [:] }
            let changes = Changes(changedKeys: observable.keyPathsAffectedByValue(for: "messages"))
            return [conversation : changes]
        default:
            return [:]
        }
    }
}

extension ZMConnection : SideEffectSource {
    
    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMConversation.entityName():
            let mappedKeys = changedValues().keys.map{"connection.\($0)"}
            
            let affectedKeys = Set<String>(observable.observableKeys.flatMap {
                if !observable.keyPathsForValuesAffectingValue(for: $0).isDisjoint(with: mappedKeys) {
                    return $0
                }
                return nil
            })
            guard affectedKeys.count > 0 else { return [:] }
            
            return [conversation: Changes(changedKeys: affectedKeys)]
        default:
            return [:]
        }
    }
    
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes] {
        return [:]
    }
}

extension ConversationChangeInfo {
    
    public static func add(observer: ZMConversationObserver, for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.ConversationChangeNotification,
                                               object: conversation,
                                               queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                  let changedKeysAndValues = note.userInfo?[ChangedKeysAndOldValuesKey] as? [String : NSObject?]
            else { return }
            
            let changeInfo = ConversationChangeInfo(object: conversation)
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            observer.conversationDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation?) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.ConversationChangeNotification, object: conversation)
    }
}

extension UserChangeInfo {
    
    public static func add(observer: ZMUserObserver, for user: ZMUser) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.UserChangeNotification,
                                                      object: user,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changedKeysAndValues = note.userInfo?[ChangedKeysAndOldValuesKey] as? [String : NSObject?]
            else { return }
            
            let changeInfo = UserChangeInfo(object: user)
            changeInfo.changedKeysAndOldValues = changedKeysAndValues
            observer.userDidChange(changeInfo)
        }
    }
    
    public static func remove(observer: NSObjectProtocol, for user: ZMUser?) {
        NotificationCenter.default.removeObserver(observer, name: Notification.Name.UserChangeNotification, object: user)
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
        for key in keys {
            if let value = valueMapping(key) {
                dict.updateValue(value, forKey: key)
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
    
    func mappingValues<NewValue : Any>(_ transform:((Value) -> NewValue)) -> Dictionary<Key, NewValue> {
        var dict = Dictionary<Key, NewValue>()
        for (key, value) in self {
            dict[key] = transform(value)
        }
        return dict
    }
    
    func mappingKeys<NewKey : Hashable>(_ transform:((Key) -> NewKey)) -> Dictionary<NewKey, Value> {
        var dict = Dictionary<NewKey, Value>()
        for (key, value) in self {
            let newKey = transform(key)
            dict[newKey] = value
        }
        return dict
    }

    func removingKeysNotIn(set: Set<Key>) -> Dictionary {
        var newDict = self
        self.keys.forEach{
            if !set.contains($0) {
                newDict.removeValue(forKey: $0)
            }
        }
        return newDict
    }
}

struct Changes {
    private let changedKeys : Set<String>
    let changedKeysAndOldValues : [String : NSObject?]
    
    init(changedKeys: Set<String>) {
        self.changedKeys = changedKeys
        self.changedKeysAndOldValues = changedKeys.reduce([:]){ (dict, value) in
            var newDict = dict
            if dict[value] == nil {
                newDict[value] = .none as NSObject?
            }
            return newDict
        }
    }

    init(changedKeysAndOldValues : [String : NSObject?]){
        self.init(changedKeys: Set(changedKeysAndOldValues.keys), changedKeysAndOldValues: changedKeysAndOldValues)
    }
    
    init(changedKeys: Set<String>, changedKeysAndOldValues : [String : NSObject?]) {
        self.changedKeys = changedKeys
        let mappedChangedKeys : [String : NSObject?] = changedKeys.reduce([:]){ (dict, value) in
            var newDict = dict
            if dict[value] == nil {
                newDict[value] = .none as NSObject?
            }
            return newDict
        }
        self.changedKeysAndOldValues = mappedChangedKeys.updated(other: changedKeysAndOldValues)
    }
    
    func joined(other: Changes) -> Changes {
        return Changes(changedKeys: changedKeys.union(other.changedKeys), changedKeysAndOldValues: changedKeysAndOldValues.updated(other: other.changedKeysAndOldValues))
    }
}

protocol SideEffectSource {
    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes]
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes]
}

struct Observable {
    
    let classIdentifier : String
    let observableKeys : Set<String>
    let allKeys : Set<String>
    private let affectingKeys : [String : Set<String>]
    private let effectedKeys : [String : Set<String>]

    init(classIdentifier: String) {
        self.classIdentifier = classIdentifier
        self.observableKeys = Observable.setupObservableKeys(classIdentifier: classIdentifier)
        self.affectingKeys = Observable.setupAffectedKeys(classIdentifier: classIdentifier, observableKeys: observableKeys)
        self.allKeys = Observable.setupAllKeys(observableKeys: observableKeys, affectingKeys: affectingKeys)
        self.effectedKeys = Observable.setupEffectedKeys(affectingKeys: affectingKeys)
    }
    
    private static func setupObservableKeys(classIdentifier: String) -> Set<String> {
        switch classIdentifier {
        case ZMConversation.entityName():
            return Set(arrayLiteral: "messages", "lastModifiedDate", "isArchived", "conversationListIndicator", "voiceChannelState", "activeFlowParticipants", "callParticipants", "isSilenced", "securityLevel", "otherActiveVideoCallParticipants", "displayName", "estimatedUnreadCount", "clearedTimeStamp", "otherActiveParticipants", "isSelfAnActiveMember", "relatedConnectionState")
        case ZMUser.entityName():
            return Set(arrayLiteral: "name", "displayName", "accentColorValue", "imageMediumData", "imageSmallProfileData","emailAddress", "phoneNumber", "canBeConnected", "isConnected", "isPendingApprovalByOtherUser", "isPendingApprovalBySelfUser", "clients", "handle")
        case ZMConnection.entityName():
            return Set(arrayLiteral: "status")
        default:
            zmLog.warn("There are no observable keys defined for this \(classIdentifier)")
            return Set()
        }
    }
    
    /// Creates a dictionary mapping the observable keys to keys affecting their values
    /// ["foo" : keysAffectingValueForKey(foo), "bar" : keysAffectingValueForKey(bar)]
    private static func setupAffectedKeys(classIdentifier: String, observableKeys: Set<String>) -> [String : Set<String>] {
        switch classIdentifier {
        case ZMConversation.entityName():
            return Dictionary.mappingKeysToValues(keys: Array(observableKeys)){ZMConversation.keyPathsForValuesAffectingValue(forKey: $0)}
        case ZMUser.entityName():
            return Dictionary.mappingKeysToValues(keys: Array(observableKeys)){ZMUser.keyPathsForValuesAffectingValue(forKey: $0)}
        case ZMConnection.entityName():
            return [:]
        default:
            zmLog.warn("There is no path to affecting keys defined")
            return [:]
        }
    }
    
    /// Combines observed keys and all affecting keys in one giant Set
    private static func setupAllKeys(observableKeys: Set<String>, affectingKeys: [String : Set<String>]) -> Set<String> {
        let allAffectingKeys : Set<String> = affectingKeys.reduce(Set()){$0.union($1.value)}
        return observableKeys.union(allAffectingKeys)
    }
    
    /// Creates a dictionary mapping keys affecting values for key into the opposite direction
    /// ["foo" : Set("affectingKey1", "affectingKey2")] --> ["affectingKey1" : Set("foo"), "affectingKey2" : Set("foo")]
    private static func setupEffectedKeys(affectingKeys: [String : Set<String>]) -> [String : Set<String>] {
        var allEffectedKeys = [String : Set<String>]()
        affectingKeys.forEach{ key, values in
            values.forEach{
                allEffectedKeys[$0] = (allEffectedKeys[$0] ?? Set()).union(Set(arrayLiteral: key))
            }
        }
        return allEffectedKeys
    }
    
    func keyPathsForValuesAffectingValue(for key: String) -> Set<String>{
        return affectingKeys[key] ?? Set()
    }
    
    func keyPathsAffectedByValue(for key: String) -> Set<String>{
        var keys = effectedKeys[key] ?? Set()
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
    private let observables : [Observable] = [Observable(classIdentifier: ZMConversation.entityName()),
                                              Observable(classIdentifier: ZMUser.entityName())]
    private var allChanges : [String : [NSObject : Changes]] = [:]
    private var snapshots : [NSManagedObjectID : [String : NSObject?]] = [:]

    public init(managedObjectContext: NSManagedObjectContext, syncContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        self.syncContext = syncContext
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
    
    public func willMergeChanges(changes: [NSManagedObjectID]){
        self.snapshots = Dictionary.mappingKeysToValues(keys: changes){ objectID in
            guard let obj = (try? managedObjectContext.existingObject(with: objectID)) else { return [:] }
            let attributes = obj.entity.attributesByName.keys
            return Dictionary.mappingKeysToValues(keys: Array(attributes)){
                obj.value(forKey: $0) as? NSObject
            }
        }
    }
    
    func notifyObservers(changes: [Notification]) {
        changes.forEach{NotificationCenter.default.post($0)}
    }
    
    func process(note: Notification) {
        guard let userInfo = note.userInfo as? [String : Any] else { return }

        let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<ZMManagedObject> ?? Set()
        let refreshedObjects = userInfo[NSRefreshedObjectsKey] as? Set<ZMManagedObject> ?? Set()
        let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<ZMManagedObject> ?? Set()
        let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<ZMManagedObject> ?? Set()
        
        let updatedAndRefreshedObjects = updatedObjects.union(refreshedObjects)
        extractChangesAffectedByChangeInObjects(insertedObjects: insertedObjects,
                                                updatedObjects: updatedAndRefreshedObjects,
                                                deletedObjects: deletedObjects)
        
        if updatedAndRefreshedObjects.count > 0 {
            extractChanges(from: updatedAndRefreshedObjects)
        }
//        let updatedUsers = managedObjectContext.updateDisplayNameGenerator(withChanges: note) as! Set<ZMManagedObject>
//        let displayNameChange = Changes(changedKeys: Set(arrayLiteral: "displayName"))
//        updatedUsers.forEach{ user in
//            if let changes = allChanges[ZMUser.entityName()] {
//                let userChanges = changes[user]?.joined(other: displayNameChange)
//                allChanges[ZMUser.entityName()]![user] = userChanges
//            } else {
//                allChanges[ZMUser.entityName()] = [user : displayNameChange]
//            }
//        }
    }
    
    /// Extracts changes from the updated objects
    func extractChanges(from changedObjects: Set<ZMManagedObject>) {
        // Sort the changes by class
        let updatedObjectsByIdentifer = sortObjectsByEntityName(objects: changedObjects)
        
        // Check for changed keys and affected keys
        updatedObjectsByIdentifer.forEach{ (classIdentifier, objects) in
            let observable = Observable(classIdentifier: classIdentifier)
            
            let changes : [NSObject: Changes] = Dictionary.mappingKeysToValues(keys: Array(objects)){ object in
                // (1) Get all the changed keys since last Save
                var changedKeysAndNewValues = [String : NSObject?]()
                if object.isFault {
                    // (1a)
                    // If the object is a fault, calling changedValues() will return an empty set
                    // Luckily we created a snapshot of the object before the merge happend which we can use to compare the values
                    if let snapshot = snapshots[object.objectID] {
                        changedKeysAndNewValues = extractChangedKeysFromSnapshot(snapshot: snapshot, for: object)
                        snapshots.removeValue(forKey: object.objectID)
                    }
                } else {
                    // (1b) If the object is not a fault, get the values from the object directly
                    changedKeysAndNewValues = object.changedValues() as! [String : NSObject?]
                }
                guard changedKeysAndNewValues.count > 0 else { return nil }
                
                // (2) Map the changed keys to affected keys, remove the ones that we are not reporting
                let relevantKeysAndOldValues = changedKeysAndNewValues.removingKeysNotIn(set: observable.observableKeys)
                let affectedKeys = changedKeysAndNewValues.keys.map{observable.keyPathsAffectedByValue(for: $0)}
                    .reduce(Set()){$0.union($1)}
                    .intersection(observable.observableKeys)
                guard relevantKeysAndOldValues.count > 0 || affectedKeys.count > 0 else { return nil }
                
                // (3) Merge the changes with the other ones
                let newChanges = Changes(changedKeys: affectedKeys, changedKeysAndOldValues: relevantKeysAndOldValues)
                let existingChanges = allChanges[classIdentifier]?[object]
                return existingChanges?.joined(other: newChanges) ?? newChanges
            }
            
            let value = allChanges[classIdentifier]
            allChanges[classIdentifier] = value?.updated(other: changes) ?? changes
        }
    }
    
    /// Get all changes that resulted from other objects through dependencies (e.g. user.name -> conversation.displayName)
    func extractChangesAffectedByChangeInObjects(insertedObjects: Set<ZMManagedObject>,
                                                 updatedObjects:  Set<ZMManagedObject>,
                                                 deletedObjects:  Set<ZMManagedObject>)
    {
        observables.forEach{ observable in
            // (1) All Updates in other objects resulting in changes on others
            // e.g. changing a users name affects the conversation displayName
            updatedObjects.forEach{ (obj) in
                guard let object = obj as? SideEffectSource else { return }
                let changedObjectsAndKeys = object.affectedObjectsAndKeys(observable: observable)
                let values = allChanges[observable.classIdentifier]
                allChanges[observable.classIdentifier] = values?.updated(other: changedObjectsAndKeys) ?? changedObjectsAndKeys
            }
            // (2) All inserts of other objects resulting in changes in others
            // e.g. inserting a user affects the conversation displayName
            insertedObjects.forEach{ (obj) in
                guard let object = obj as? SideEffectSource else { return }
                let changedObjectsAndKeys = object.affectedObjectsAndKeysForInsertion(observable: observable)
                let values = allChanges[observable.classIdentifier]
                allChanges[observable.classIdentifier] = values?.updated(other: changedObjectsAndKeys) ?? changedObjectsAndKeys
            }
        }
    }
    
    /// Before merging the sync into the ui context, we create a snapshot of all changed objects
    /// This function compares the snapshot values to the current ones and returns all keys and new values where the value changed due to the merge
    func extractChangedKeysFromSnapshot(snapshot: [String : NSObject?], for object: NSObject) -> [String : NSObject?] {
        var changedKeysAndOldValues = [String : NSObject?]()
        snapshot.forEach{ (key, oldValue) in
            let currentValue = object.value(forKey: key) as? NSObject
            if currentValue != oldValue {
                changedKeysAndOldValues[key] = currentValue
            }
        }
        return changedKeysAndOldValues
    }
    
    func fireAllNotifications(){
        let mappedChanges = allChanges.mappingValues{ (values) in
            return values.mappingValues{$0.changedKeysAndOldValues}
        }
        mappedChanges.forEach{ (classIdentifier, changes) in
            guard let notificationName = Notification.Name.nameForObservable(with: classIdentifier) else { return }
            let notifications : [Notification] = changes.flatMap{Notification(name: notificationName,
                                                                              object: $0,
                                                                              userInfo: [ChangedKeysAndOldValuesKey : $1])}
            notifyObservers(changes: notifications)
        }
        allChanges = [:]
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


/*
 //
 //  ZMNotificationDispatcher.m
 //
 //
 //  Created by Arne Schroppe on 01/07/14.
 //  Copyright (c) 2014 Zeta Project Gmbh. All rights reserved.
 //
 
 #import "ZMNotificationDispatcher.h"
 #import "ZMNotificationDispatcher+Private.h"
 #import "ZMNotifications+Internal.h"
 #import "ZMFunctional.h"
 #import "ZMMessage+Internal.h"
 #import "ZMConversation+Internal.h"
 #import "ZMUser+Internal.h"
 #import "ZMConnection+Internal.h"
 #import "NSManagedObjectContext+zmessaging.h"
 #import "ZMFunctional.h"
 #import "ZMManagedObjectContext.h"
 #import "ZMConversationList+Internal.h"
 #import "ZMCallParticipant.h"
 #import "ZMVoiceChannelNotifications+Internal.h"
 #import "ZMVoiceChannel+Internal.h"
 #import "ZMUserDisplayNameGenerator.h"
 #import "ZMEventID.h"
 #import "ZMConversationList+Internal.h"
 #import "ZMConversationListDirectory.h"
 #import "ZMConversationMessageWindow+Internal.h"
 
 #import <zmessaging/zmessaging-Swift.h>
 
 NSString * const ZMNotificationDispatcherWillMergeChangesFromContextDidSave = @"ZMNotificationDispatcherWillMergeChangesFromContextDidSave";
 static ZMLogLevel_t const ZMLogLevel ZM_UNUSED = ZMLogLevelWarn;
 
 // This array is not thread safe and is supposed to be used on the UI thread only
 static NSMutableSet *WindowTokenList;
 
 @interface ZMNotificationDispatcher ()
 
 @property (nonatomic) NSManagedObjectContext *moc;
 
 @property (nonatomic) NSSet *insertedConversationsOnOtherContext;
 @property (nonatomic) NSSet *updatedConversationsOnOtherContext;
 
 @property (nonatomic) NSMutableArray *notificationsToFire;
 @property (nonatomic, readonly) NSMutableArray *userInfosFromWillMerge;
 
 @property (nonatomic) NSMutableSet *updatedConversations;
 @property (nonatomic) NSMutableSet *updatedConnections;
 @property (nonatomic) NSMutableSet *updatedUsers;
 @property (nonatomic) NSMutableSet *updatedMessages;
 @property (nonatomic) NSMutableSet *updatedAndInsertedConnections;
 @property (nonatomic) NSMutableSet *updatedCallParticipants;
 @property (nonatomic) NSMutableSet *insertedCallParticipants;
 @property (nonatomic) NSMutableSet *insertedMessages;
 @property (nonatomic) NSSet *usersWithUpdatedDisplayNames;
 @property (nonatomic) NSSet *insertedConversations;
 
 @property (nonatomic) ZMConversation *previousActiveVoiceChannelConversation;
 @property (nonatomic) BOOL didChangeConnectionStatus;
 @end
 
 
 
 @implementation ZMNotificationDispatcher
 
 - (instancetype)initWithContext:(NSManagedObjectContext *)moc
 {
 ZMLogDebug(@"%@ %@: %@", self.class, NSStringFromSelector(_cmd), moc);
 VerifyReturnNil(moc != nil);
 Check(moc.zm_isUserInterfaceContext);
 self = [super init];
 if (self) {
 self.moc = moc;
 _userInfosFromWillMerge = [NSMutableArray array];
 NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
 [center addObserver:self selector:@selector(willMergeChanges:) name:ZMNotificationDispatcherWillMergeChangesFromContextDidSave object:moc];
 [center addObserver:self selector:@selector(processChangeNotification:) name:NSManagedObjectContextObjectsDidChangeNotification object:moc];
 
 WindowTokenList = [NSMutableSet set];
 }
 return self;
 }
 
 - (void)dealloc
 {
 [[NSNotificationCenter defaultCenter] removeObserver:self];
 }
 
 - (void)willMergeChanges:(NSNotification *)note;
 {
 [self.userInfosFromWillMerge addObject:[note.userInfo copy] ?: @{}];
 }
 
 
 
 - (void)checkForConversationListChanges;
 {
 NSEntityDescription *conversationEntity = self.moc.persistentStoreCoordinator.managedObjectModel.entitiesByName[ZMConversation.entityName];
 
 NSMutableSet *insertedObjectIDs = [NSMutableSet set];
 for (NSDictionary *userInfo in self.userInfosFromWillMerge) {
 NSSet *inserted = userInfo[NSInsertedObjectsKey];
 for (NSManagedObject *mo in inserted) {
 NSManagedObjectID *moid = mo.objectID;
 if (moid.entity == conversationEntity) {
 [insertedObjectIDs addObject:moid];
 }
 }
 }
 
 [self.userInfosFromWillMerge removeAllObjects];
 NSArray *insertedConversations = [[insertedObjectIDs allObjects] mapWithBlock:^id(NSManagedObjectID *moid) {
 // Get the same object in the other context:
 return [self.moc objectWithID:moid];
 }];
 self.insertedConversationsOnOtherContext = [NSSet setWithArray:insertedConversations];
 }
 
 - (void)checkForConversationChangesInDidSaveNotification:(NSNotification *)note;
 {
 NSSet *updated = note.userInfo[NSUpdatedObjectsKey];
 NSEntityDescription *conversationEntity = self.moc.persistentStoreCoordinator.managedObjectModel.entitiesByName[ZMConversation.entityName];
 NSArray *updatedConversations = [[updated allObjects] mapWithBlock:^id(NSManagedObject *mo) {
 if (mo.entity != conversationEntity) {
 return nil;
 }
 // Get the same object in the other context:
 return [self.moc objectWithID:mo.objectID];
 }];
 self.updatedConversationsOnOtherContext = [NSSet setWithArray:updatedConversations];
 }
 
 - (void)logChangeNotification:(NSNotification *)note;
 {
 ZMLogDebug(@"%@", note.name);
 for (NSString *key in @[NSInsertedObjectsKey, NSUpdatedObjectsKey, NSRefreshedObjectsKey, NSDeletedObjectsKey]) {
 NSSet *objects = note.userInfo[key];
 if (objects.count == 0) {
 continue;
 }
 BOOL const isUpdateOrRefresh = ([key isEqual:NSUpdatedObjectsKey] || [key isEqual:NSRefreshedObjectsKey]);
 ZMLogDebug(@"[%@]:", key);
 NSMutableArray *lines = [NSMutableArray array];
 for (NSManagedObject *mo in objects) {
 if (isUpdateOrRefresh) {
 [lines addObject:[NSString stringWithFormat:@"    <%@: %p> %@, keys: {%@}",
 mo.class, mo, mo.objectID.URIRepresentation,
 [[mo updatedKeysForChangeNotification].allObjects componentsJoinedByString:@", "]]];
 } else {
 [lines addObject:[NSString stringWithFormat:@"    <%@: %p> %@",
 mo.class, mo, mo.objectID.URIRepresentation]];
 }
 }
 ZM_ALLOW_MISSING_SELECTOR([lines sortUsingSelector:@selector(compare:)]);
 for (NSString *line in lines) {
 ZMLogDebug(@"%@", line);
 }
 }
 }
 
 - (void)processChangeNotification:(NSNotification *)note
 {
 if (__builtin_expect((ZMLogLevelDebug <= ZMLogLevel),0)) { \
 [self logChangeNotification:note];
 }
 
 [self calculateNotificationsFromChangeNotification:note withBlock:^NSArray *(){
 
 NSArray *voiceChannelChangeNotifications = [self createVoiceChannelChangeNotifications];
 NSArray *userChangeNotifications = [self createUserChangeNotification];
 NSArray *messageChangeNotifications = [self createMessagesChangeNotificationWithUserChangeNotifications:userChangeNotifications];
 NSArray *conversationChangeNotifications = [self createConversationChangeNotificationsWithUserChangeNotifications:userChangeNotifications
 messageChangeNotifications:messageChangeNotifications];
 NSArray *connectionChangeNotifications = [self createConnectionChangeNotification];
 NSArray *newUnreadMessagesNotifications = [self createNewUnreadMessagesNotification];
 NSArray *updatedKnocksNotifications = [self createNewUnreadKnocksNotificationsForUpdatedKnocks];
 NSArray *conversationListChangeNotifications = [self createConversationListChangeNotificationsWithConversationChangeNotification:conversationChangeNotifications connectionChangedNotifications:connectionChangeNotifications];
 
 [ZMNotificationDispatcher notifyConversationWindowChangeTokensWithUpdatedMessages:self.updatedMessages];
 
 return [self combineArrays:@[voiceChannelChangeNotifications,
 userChangeNotifications,
 messageChangeNotifications,
 conversationChangeNotifications,
 connectionChangeNotifications,
 newUnreadMessagesNotifications,
 updatedKnocksNotifications,
 conversationListChangeNotifications,
 ]];
 
 }];
 
 
 }
 
 - (NSArray *)combineArrays:(NSArray *)arrays {
 NSArray *accum = @[];
 
 for (NSArray *array in arrays) {
 accum = [accum arrayByAddingObjectsFromArray:array];
 }
 
 return accum;
 
 }
 
 
 - (void)calculateNotificationsFromChangeNotification:(NSNotification *)changeNotification withBlock:(NSArray *(^)())block;
 {
 [self checkForConversationListChanges];
 
 [self extractUpdatedObjectsFromChangeNotification:changeNotification];
 self.notificationsToFire = [NSMutableArray array];
 self.didChangeConnectionStatus = NO;
 
 NSArray *newNotifications = block();
 
 for (NSNotification *note in newNotifications) {
 [self addNotification:note];
 }
 
 [self fireAllNotifications];
 
 self.updatedConversations = nil;
 self.updatedConnections = nil;
 self.updatedUsers = nil;
 self.updatedMessages = nil;
 self.updatedAndInsertedConnections = nil;
 self.updatedCallParticipants = nil;
 self.insertedCallParticipants = nil;
 self.insertedConversations = nil;
 self.didChangeConnectionStatus = NO;
 self.usersWithUpdatedDisplayNames = nil;
 self.insertedMessages = nil;
 self.insertedConversationsOnOtherContext = nil;
 
 NSManagedObjectContext *moc = changeNotification.object;
 [moc clearCustomSnapshotsWithObjectChangeNotification:changeNotification];
 }
 
 - (void)extractUpdatedObjectsFromChangeNotification:(NSNotification *)changeNotification;
 {
 self.updatedConversations = [NSMutableSet setWithSet:[((NSSet *) changeNotification.userInfo[NSUpdatedObjectsKey]) objectsOfClass:ZMConversation.class]];
 [self.updatedConversations unionSet:[((NSSet *) changeNotification.userInfo[NSRefreshedObjectsKey]) objectsOfClass:ZMConversation.class]];
 
 self.updatedConnections = [NSMutableSet setWithSet:[((NSSet *) changeNotification.userInfo[NSUpdatedObjectsKey]) objectsOfClass:ZMConnection.class]];
 [self.updatedConnections unionSet:[((NSSet *) changeNotification.userInfo[NSRefreshedObjectsKey]) objectsOfClass:ZMConnection.class]];
 
 self.updatedUsers = [NSMutableSet setWithSet:[((NSSet *) changeNotification.userInfo[NSUpdatedObjectsKey]) objectsOfClass:ZMUser.class]];
 [self.updatedUsers unionSet:[((NSSet *) changeNotification.userInfo[NSRefreshedObjectsKey]) objectsOfClass:ZMUser.class]];
 
 self.updatedMessages = [NSMutableSet setWithSet:[((NSSet *) changeNotification.userInfo[NSUpdatedObjectsKey]) objectsOfClass:ZMMessage.class]];
 [self.updatedMessages unionSet:[((NSSet *) changeNotification.userInfo[NSRefreshedObjectsKey]) objectsOfClass:ZMMessage.class]];
 
 self.insertedMessages = [[((NSSet *) changeNotification.userInfo[NSInsertedObjectsKey]) objectsOfClass:ZMMessage.class] mutableCopy];
 
 self.updatedCallParticipants = [NSMutableSet set];
 self.updatedCallParticipants = [NSMutableSet setWithSet:[((NSSet *) changeNotification.userInfo[NSUpdatedObjectsKey]) objectsOfClass:ZMCallParticipant.class]];
 [self.updatedCallParticipants unionSet:[((NSSet *) changeNotification.userInfo[NSRefreshedObjectsKey]) objectsOfClass:ZMCallParticipant.class]];
 
 self.insertedCallParticipants = [[((NSSet *) changeNotification.userInfo[NSInsertedObjectsKey]) objectsOfClass:ZMCallParticipant.class] mutableCopy];
 self.insertedConversations = [((NSSet *) changeNotification.userInfo[NSInsertedObjectsKey]) objectsOfClass:ZMConversation.class];
 
 self.updatedAndInsertedConnections = [NSMutableSet setWithSet:[((NSSet *) changeNotification.userInfo[NSUpdatedObjectsKey]) objectsOfClass:ZMConnection.class]];
 [self.updatedAndInsertedConnections unionSet:[((NSSet *) changeNotification.userInfo[NSRefreshedObjectsKey]) objectsOfClass:ZMConnection.class]];
 [self.updatedAndInsertedConnections unionSet:[((NSSet *) changeNotification.userInfo[NSInsertedObjectsKey]) objectsOfClass:ZMConnection.class]];
 
 NSSet *insertedUsers =  [NSMutableSet setWithSet:[((NSSet *) changeNotification.userInfo[NSInsertedObjectsKey]) objectsOfClass:ZMUser.class]];
 NSSet *deletedUsers =  [NSMutableSet setWithSet:[((NSSet *) changeNotification.userInfo[NSDeletedObjectsKey]) objectsOfClass:ZMUser.class]];
 
 if (insertedUsers.count != 0 || deletedUsers.count != 0 || self.updatedUsers.count != 0) {
 self.usersWithUpdatedDisplayNames = [self.moc updateDisplayNameGeneratorWithInsertedUsers:insertedUsers  updatedUsers:self.updatedUsers deletedUsers:deletedUsers];
 }
 }
 
 - (void)fireAllNotifications;
 {
 if (0 < self.notificationsToFire.count) {
 static int count;
 ZMLogInfo(@"%@ firing notifications (%d)", self.class, count++);
 for (NSNotification *note in self.notificationsToFire) {
 ZMLogInfo(@"    posting %@ (obj = %p)", note.name, note.object);
 [[NSNotificationCenter defaultCenter] postNotification:note];
 }
 }
 self.notificationsToFire = nil;
 }
 
 - (NSArray *)createConversationListChangeNotificationsWithConversationChangeNotification:(NSArray *)conversationNotifications
 connectionChangedNotifications:(NSArray *)connectionNotifications;
 {
 // These are "special" hooks for the ZMConversationList:
 
 NSSet * const allUpdatedConversationKeys = [self allUpdatedConversationKeys];
 NSSet * const allUpdatedConnectionsKeys = [self allUpdatedConnectionKeys];
 BOOL const insertedOrRemovedConversations = [self conversationsWereInsertedOrRemoved];
 
 ZMLogDebug(@"allUpdatedConversationKeys: %@", [allUpdatedConversationKeys.allObjects componentsJoinedByString:@", "]);
 ZMLogDebug(@"allUpdatedConnectionsKeys: %@", [allUpdatedConnectionsKeys.allObjects componentsJoinedByString:@", "]);
 
 NSMutableArray *notifications = [NSMutableArray array];
 
 for (ZMConversationList *list in self.moc.allConversationLists) {
 BOOL const refetch = (insertedOrRemovedConversations ||
 [list predicateIsAffectedByConversationKeys:allUpdatedConversationKeys connectionKeys:allUpdatedConnectionsKeys]);
 BOOL const resort = (refetch ||
 [list sortingIsAffectedByConversationKeys:allUpdatedConversationKeys]);
 ZMConversationListRefresh const refreshType = (refetch ?
 ZMConversationListRefreshByRefetching :
 (resort ?
 ZMConversationListRefreshByResorting :
 ZMConversationListRefreshItemsInPlace));
 
 ZMLogDebug(@"ZMConversationListChangeNotification refresh type “%@” for %p", ZMConversationListRefreshName(refreshType), list);
 ZMConversationListChangeNotification *note = [ZMConversationListChangeNotification notificationForList:list
 conversationChangeNotifications:conversationNotifications
 connectionChangeNotifications:connectionNotifications
 refreshType:refreshType];
 if (note != nil) {
 [notifications addObject:note];
 }
 }
 return notifications;
 }
 
 - (BOOL)conversationsWereInsertedOrRemoved;
 {
 return ((0 < self.self.insertedConversations.count) ||
 (0 < self.insertedConversationsOnOtherContext.count));
 }
 
 /// Keys that have changed in any conversation:
 - (NSSet *)allUpdatedConversationKeys;
 {
 NSMutableSet *allKeys = [NSMutableSet set];
 for (ZMConversation *conversation in self.updatedConversations) {
 [allKeys unionSet:[conversation updatedKeysForChangeNotification]];
 }
 return allKeys;
 }
 
 - (NSSet *)allUpdatedConnectionKeys;
 {
 NSMutableSet *allKeys = [NSMutableSet set];
 for (ZMConnection *connection in self.updatedConnections) {
 [allKeys unionSet:[connection updatedKeysForChangeNotification]];
 }
 return allKeys;
 }
 
 - (void)addNotification:(NSNotification *)note;
 {
 if (note != nil) {
 [self.notificationsToFire addObject:note];
 }
 }
 
 - (void)addNotificationWithTopPriority:(NSNotification *)note;
 {
 if (note != nil) {
 [self.notificationsToFire insertObject:note atIndex:0];
 }
 }
 
 - (ZMNotification *)createActiveVoiceChannelNotification
 {
 NSSet * const allUpdatedConversationKeys = [self allUpdatedConversationKeys];
 NSSet * const keysOfInterest = [NSSet setWithObjects:ZMConversationCallDeviceIsActiveKey, ZMConversationFlowManagerCategoryKey, nil];
 
 if ((self.updatedCallParticipants.count == 0) &&
 (self.insertedCallParticipants.count == 0) &&
 ! [allUpdatedConversationKeys intersectsSet:keysOfInterest])
 {
 return nil;
 }
 
 // active channel
 ZMVoiceChannel *activeVoiceChannel = [ZMVoiceChannel activeVoiceChannelInManagedObjectContext:self.moc];
 ZMConversation *strongConversation = activeVoiceChannel.conversation;
 
 if(strongConversation == self.previousActiveVoiceChannelConversation) {
 return nil;
 }
 
 ZMVoiceChannelActiveChannelChangedNotification *activeChannelNotification = [ZMVoiceChannelActiveChannelChangedNotification notificationWithActiveVoiceChannel:activeVoiceChannel];
 activeChannelNotification.currentActiveVoiceChannel = activeVoiceChannel;
 activeChannelNotification.previousActiveVoiceChannel = self.previousActiveVoiceChannelConversation.voiceChannel;
 
 self.previousActiveVoiceChannelConversation = strongConversation;
 
 return activeChannelNotification;
 }
 
 - (NSArray *)createNewUnreadMessagesNotification {
 
 NSMutableArray *newUnreadMessages = [NSMutableArray array];
 NSMutableArray *newUnreadKnocks = [NSMutableArray array];
 
 for(ZMMessage *msg in self.insertedMessages) {
 if(msg.conversation.lastReadEventID != nil && msg.eventID != nil && [msg.eventID compare:msg.conversation.lastReadEventID] == NSOrderedDescending) {
 if ([msg isKindOfClass:[ZMKnockMessage class]]) {
 [newUnreadKnocks addObject:msg];;
 }
 else {
 [newUnreadMessages addObject:msg];
 }
 }
 }
 
 NSMutableArray *notifications = [NSMutableArray array];
 if (newUnreadMessages.count > 0) {
 ZMNewUnreadMessagesNotification *messageNote = [ZMNewUnreadMessagesNotification notificationWithMessages:newUnreadMessages];
 if (messageNote != nil) {
 [notifications addObject:messageNote];
 }
 }
 if (newUnreadKnocks.count > 0) {
 ZMNewUnreadKnocksNotification *knockNote = [ZMNewUnreadKnocksNotification notificationWithKnockMessages:newUnreadKnocks];
 if (knockNote != nil) {
 [notifications addObject:knockNote];
 }
 }
 
 return notifications;
 }
 
 - (NSArray *)createVoiceChannelChangeNotifications;
 {
 NSMutableSet *conversations = [self.updatedConversations mutableCopy];
 [conversations unionSet:self.conversationsWithChangesForCallParticipants];
 
 NSMutableArray *notifications = [NSMutableArray array];
 for (ZMConversation *conversation in conversations) {
 ZMVoiceChannelStateChangedNotification *channelNotification = [ZMVoiceChannelStateChangedNotification notificationWithConversation:conversation insertedParticipants:self.insertedCallParticipants];
 if (channelNotification != nil) {
 [notifications addObject:channelNotification];
 }
 
 for(ZMCallParticipant *participant in conversation.mutableCallParticipants) {
 
 BOOL isInserted = [self.insertedCallParticipants containsObject:participant];
 ZMVoiceChannelParticipantStateChangedNotification *participantNotification =
 [ZMVoiceChannelParticipantStateChangedNotification notificationWithConversation:conversation callParticipant:participant isInserted:isInserted];
 if(participantNotification != nil) {
 [notifications addObject:participantNotification];
 }
 }
 }
 
 ZMNotification *activeChannelNotification = [self createActiveVoiceChannelNotification];
 if(activeChannelNotification != nil) {
 [notifications addObject:activeChannelNotification];
 }
 
 return notifications;
 }
 
 - (NSSet *)conversationsWithChangesForCallParticipants;
 {
 NSMutableSet *conversations = [NSMutableSet set];
 
 for (ZMCallParticipant *participant in self.updatedCallParticipants) {
 if ([participant.updatedKeysForChangeNotification containsObject:ZMCallParticipantIsJoinedKey]) {
 [conversations addObject:participant.conversation];
 }
 }
 
 for (ZMCallParticipant *participant in self.insertedCallParticipants) {
 [conversations addObject:participant.conversation];
 }
 return conversations;
 }
 
 - (NSArray *)createMessagesChangeNotificationWithUserChangeNotifications:(NSArray *)userChangeNotifications;
 {
 NSMutableArray *notifications = [NSMutableArray array];
 [self.updatedMessages unionSet:[self messagesWithChangedSendersForUserChangeNotifications:userChangeNotifications]];
 
 for (ZMMessage *message in self.updatedMessages) {
 ZMMessageChangeNotification *notification = [ZMMessageChangeNotification notificationWithMessage:message userChangeNotifications:userChangeNotifications];
 
 if (notification) {
 [notifications addObject:notification];
 }
 }
 return notifications;
 }
 
 - (NSArray *)createNewUnreadKnocksNotificationsForUpdatedKnocks
 {
 NSMutableArray *updatedKnocks = [NSMutableArray array];
 
 for (ZMMessage *message in self.updatedMessages) {
 if (![message isKindOfClass:[ZMKnockMessage class]]){
 continue;
 }
 if ((message.conversation.lastReadEventID != nil && message.eventID != nil) &&
 [message.eventID compare:message.conversation.lastReadEventID] == NSOrderedDescending){
 [updatedKnocks addObject:message];
 }
 }
 
 ZMNewUnreadKnocksNotification *note;
 if (updatedKnocks.count != 0u) {
 note = [ZMNewUnreadKnocksNotification notificationWithKnockMessages:updatedKnocks];
 }
 if (note == nil) {
 return @[];
 }
 
 return @[note];
 }
 
 - (NSMutableSet *)messagesWithChangedSendersForUserChangeNotifications:(NSArray *)userChangeNotifications;
 {
 NSMutableSet *messages = [NSMutableSet set];
 for (ZMUserChangeNotification *note in userChangeNotifications) {
 // For performance, we'll have to put some logic here.
 
 if (! (note.mediumProfileImageChanged || note.smallProfileImageChanged || note.nameChanged || note.accentChanged)) {
 continue;
 }
 for (ZMMessage *message in self.moc.registeredObjects) {
 if (! [message isKindOfClass:[ZMMessage class]]) {
 continue;
 }
 if (message.sender == note.user) {
 [messages addObject:message];
 }
 }
 }
 return messages;
 }
 
 - (NSArray *)createConversationChangeNotificationsWithUserChangeNotifications:(NSArray *)userChangeNotifications
 messageChangeNotifications:(NSArray *)messageChangeNotifications;
 {
 NSMutableArray *notifications = [NSMutableArray array];
 
 NSMutableSet *conversationsWithChangedMessages = [NSMutableSet set];
 for(ZMMessageChangeNotification *note in messageChangeNotifications) {
 if(note.message.conversation != nil) {
 [conversationsWithChangedMessages addObject:note.message.conversation];
 }
 }
 NSMutableSet *conversationsWithInsertedMessages = [NSMutableSet set];
 for (ZMMessage *insertedMessage in self.insertedMessages) {
 if (insertedMessage.conversation != nil) {
 [conversationsWithInsertedMessages addObject:insertedMessage.conversation];
 }
 }
 
 [self.updatedConversations unionSet:[self conversationsWithChangedUsers:userChangeNotifications]];
 [self.updatedConversations unionSet:conversationsWithChangedMessages];
 
 for (ZMConversation *conversation in self.updatedConversations) {
 BOOL const hasUpdatedMessages = [conversationsWithChangedMessages containsObject:conversation];
 BOOL const hasInsertedMessages = [conversationsWithInsertedMessages containsObject:conversation];
 ZMConversationChangeNotification *notification = [ZMConversationChangeNotification notificationWithConversation:conversation userChangeNotifications:userChangeNotifications hasUpdatedMessages:hasUpdatedMessages hasInsertedMessages:hasInsertedMessages];
 if (notification != nil) {
 [notifications addObject:notification];
 }
 }
 return notifications;
 }
 
 - (NSMutableSet *)conversationsWithChangedUsers:(NSArray *)userChangeNotifications;
 {
 NSMutableSet *conversations = [NSMutableSet set];
 for (ZMUserChangeNotification *note in userChangeNotifications) {
 if(note.completeUser != nil) {
 [conversations unionSet:note.completeUser.activeConversations];
 ZMConversation *oneOnOneConversation = note.completeUser.connection.conversation;
 if (oneOnOneConversation != nil) {
 [conversations addObject:oneOnOneConversation];
 }
 }
 }
 return conversations;
 }
 
 
 - (NSArray *)createUserChangeNotification
 {
 NSMutableArray *notifications = [NSMutableArray array];
 
 for (NSManagedObjectID *objectID in self.usersWithUpdatedDisplayNames){
 ZMUser *user = (ZMUser *)[self.moc objectWithID:objectID];
 if ([self.updatedUsers containsObject:user]) {
 [self.updatedUsers removeObject:user];
 }
 ZMUserChangeNotification *note = [ZMUserChangeNotification notificationWithUser:user displayNameChanged:YES];
 if (note) {
 [notifications addObject:note];
 }
 }
 
 for (ZMUser *user in self.updatedUsers) {
 ZMUserChangeNotification *note = [ZMUserChangeNotification notificationWithUser:user displayNameChanged:NO];
 if (note) {
 [notifications addObject:note];
 }
 
 }
 return notifications;
 }
 
 - (NSArray *)createConnectionChangeNotification
 {
 NSMutableArray *notifications = [NSMutableArray array];
 
 for (ZMConnection *connection in self.updatedAndInsertedConnections) {
 if (connection.updatedKeysForChangeNotification.count == 0) {
 // We shouldn't spam the UI if nothing appears to have changed.
 continue;
 }
 if (connection.to != nil) {
 NSNotification *userNote = [ZMUserChangeNotification notificationForChangedConnectionToUser:connection.to];
 if (userNote) {
 [notifications addObject:userNote];
 }
 
 ZMConversationChangeNotification *connectionNote = [ZMConversationChangeNotification notificationForUpdatedConnectionInConversation:connection.conversation];
 if (connectionNote) {
 [notifications addObject:connectionNote];
 if (connectionNote.connectionStateChanged) {
 self.didChangeConnectionStatus = YES;
 }
 }
 }
 }
 return notifications;
 }
 
 @end
 
 
 
 @implementation ZMNotificationDispatcher (Private)
 
 + (void)addConversationWindowChangeToken:(ZMMessageWindowChangeToken *)token
 {
 [WindowTokenList addObject:token];
 }
 
 + (void)removeConversationWindowChangeToken:(ZMMessageWindowChangeToken *)token
 {
 [WindowTokenList removeObject:token];
 }
 
 + (void)notifyConversationWindowChangeTokensWithUpdatedMessages:(NSSet *)updatedMessages;
 {
 for(ZMMessageWindowChangeToken *token in WindowTokenList) {
 [token conversationDidChange:updatedMessages.allObjects];
 }
 }
 
 @end

 */
