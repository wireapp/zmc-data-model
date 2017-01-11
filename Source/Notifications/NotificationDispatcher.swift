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

protocol OpaqueConversationToken : NSObjectProtocol {}


extension Notification.Name {
    
    static let ConversationChangeNotification = Notification.Name("ZMConversationChangedNotification")
    static let MessageChangeNotification = Notification.Name("ZMMessageChangedNotification")
    static let UserChangeNotification = Notification.Name("ZMUserChangedNotification")
}


extension ZMUser : SideEffectSource {
    
    func affectedObjectsAndKeys(observable: Observable) -> [SideEffect] {
        switch observable.classIdentifier {
        case ZMConversation.entityName():
            let otherPartKeys = changedValues().keys.map{"otherActiveParticipants.\($0)"}
            let selfUserKeys = changedValues().keys.map{"connection.to.\($0)"}
            let mappedKeys = Array(otherPartKeys)+Array(selfUserKeys)
            
            let affectedKeys = Set(observable.observableKeys.filter {
                return !observable.keyPathsForValuesAffectingValue(for: $0).isDisjoint(with: mappedKeys)
            })
            guard affectedKeys.count > 0 else { return [] }
            
            guard let activeConversations = activeConversations.array as? [ZMConversation] else { return []}
            let conversationMap : [SideEffect] = activeConversations.map{SideEffect(object: $0, changedKeys: affectedKeys)}
            return conversationMap
        default:
            return []
        }
    }
}

extension ConversationChangeInfo {
    
    public static func add(observer: ZMConversationObserver, for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: NSNotification.Name.ConversationChangeNotification,
                                               object: conversation,
                                               queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                  let changedKeysAndValues = note.userInfo?["changedKeysAndOldValues"] as? [String : NSObject?]
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
                let changedKeysAndValues = note.userInfo?["changedKeysAndOldValues"] as? [String : NSObject?]
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

struct SideEffect {
    let object : NSObject
    let changedKeys : Set<String>
}

protocol SideEffectSource {
    func affectedObjectsAndKeys(observable: Observable) -> [SideEffect]
}


struct Observable {
    
    let classIdentifier : String
    let observableKeys : Set<String>
    let allKeys : Set<String>
    private let affectingKeys : [String : Set<String>]
    
    var notificationName : Notification.Name? {
        switch classIdentifier {
        case ZMConversation.entityName():
            return Notification.Name.ConversationChangeNotification
        case ZMUser.entityName():
            return Notification.Name.UserChangeNotification
        default:
            return nil
        }
    }

    init(classIdentifier: String) {
        self.classIdentifier = classIdentifier
        self.observableKeys = Observable.setupObservableKeys(classIdentifier: classIdentifier)
        self.affectingKeys = Observable.setupAffectedKeys(observableKeys: observableKeys)
        self.allKeys = Observable.setupAllKeys(observableKeys: observableKeys, affectingKeys: affectingKeys)
    }
    
    private static func setupObservableKeys(classIdentifier: String) -> Set<String> {
        switch classIdentifier {
        case ZMConversation.entityName():
            return Set(arrayLiteral: "messages", "lastModifiedDate", "isArchived", "conversationListIndicator", "voiceChannelState", "activeFlowParticipants", "callParticipants", "isSilenced", "securityLevel", "otherActiveVideoCallParticipants", "displayName", "estimatedUnreadCount", "clearedTimeStamp", "otherActiveParticipants", "isSelfAnActiveMember", "relatedConnectionState")
        case ZMUser.entityName():
            return Set(arrayLiteral: "name")
        default:
            return Set()
        }
    }
    
    private static func setupAffectedKeys(observableKeys: Set<String>) -> [String : Set<String>] {
        let affectingKeys :  [String : Set<String>] = observableKeys.reduce([:]){ (dict, key) in
            var newDict = dict
            newDict[key] = ZMConversation.keyPathsForValuesAffectingValue(forKey: key)
            return newDict
        }
        return affectingKeys
    }
    
    private static func setupAllKeys(observableKeys: Set<String>, affectingKeys: [String : Set<String>]) -> Set<String> {
        let allAffectingKeys : Set<String> = affectingKeys.reduce(Set()){$0.union($1.value)}
        return observableKeys.union(allAffectingKeys)
    }
    
    func keyPathsForValuesAffectingValue(for key: String) -> Set<String>{
        return affectingKeys[key] ?? Set()
    }
}


public class NotificationDispatcher : NSObject {

    private unowned var managedObjectContext: NSManagedObjectContext
    private var tornDown = false
    private let observables : [Observable] = [Observable(classIdentifier: ZMConversation.entityName()),
                                              Observable(classIdentifier: ZMUser.entityName())]
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationDispatcher.objectsDidChange(_:)), name:NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: self.managedObjectContext)
    }
    
    public func tearDown() {
        NotificationCenter.default.removeObserver(self)
        tornDown = true
    }
    
    deinit {
        assert(tornDown)
    }
    
    @objc func objectsDidChange(_ note: Notification){
        guard let userInfo = note.userInfo as? [String : Any] else { return }
        process(userInfo)
    }

    func notifyObservers(changes: [Notification]) {
        changes.forEach{NotificationCenter.default.post($0)}
    }
    
    func process(_ userInfo: [String : Any]) {
        //let deletedObjects = extractObjects(for: [NSDeletedObjectsKey], from: userInfo)
        let updatedObjects = extractObjects(for: [NSRefreshedObjectsKey, NSUpdatedObjectsKey], from: userInfo)
        //let insertedObjects = extractObjects(for: [NSInsertedObjectsKey], from: userInfo)
        
        let sideEffects : [String: [SideEffect]] = observables.reduce([:]){ (dict, observable) in
            var newDict = dict
            let allUpdatedObjects : Set<ZMManagedObject> = updatedObjects.reduce(Set<ZMManagedObject>()){$0.union($1.value)}
            allUpdatedObjects.forEach{ (object) in
                guard let object = object as? SideEffectSource else { return }

                let changedObjectsAndKeys = object.affectedObjectsAndKeys(observable: observable)

                let values = (newDict[observable.classIdentifier] ?? [])+changedObjectsAndKeys
                newDict[observable.classIdentifier] = values
            }
            return newDict
        }
        
        let reducedSideEffects : [String : [NSObject : Set<String>]] = sideEffects.reduce([:]){ (dict, sideEffects) in
            var newDict = dict
            let value : [NSObject : Set<String>] = sideEffects.value.reduce([:]){ (innerDict, sideEffect) in
                var newInnerDict = innerDict
                let newValue = (newInnerDict[sideEffect.object] ?? Set()).union(sideEffect.changedKeys)
                newInnerDict[sideEffect.object] = newValue
                return newInnerDict
            }
            newDict[sideEffects.key] = value
            return newDict
        }
        
        reducedSideEffects.forEach{ (classIdentifier, changes) in
            let observable = Observable(classIdentifier: classIdentifier)
            let notifications : [Notification] = changes.flatMap{
                guard let notificationName = observable.notificationName else {
                    return nil
                }
                let mappedKeys : [String : NSObject?] = $0.1.reduce([:]){
                    var newDict = $0
                    newDict[$1] = .none as NSObject?
                    return newDict
                }
                return Notification(name: notificationName,
                                    object: $0.key,
                                    userInfo: ["changedKeysAndOldValues" : mappedKeys])}
            notifyObservers(changes: notifications)
        }
        
        observables.forEach{ obs in
            guard let changes = updatedObjects[obs.classIdentifier] else { return }
            let notifications : [Notification] = changes.flatMap{
                guard let notificationName = obs.notificationName else { return nil }
                let relevantKeysAndOldValues = $0.changedValuesForCurrentEvent().reduce([:]){ (dict, pair) in
                    if obs.allKeys.contains(pair.key){
                        var newDict = dict
                        newDict[pair.key] = pair.value
                        return newDict
                    }
                    return dict
                }

                guard relevantKeysAndOldValues.count > 0 else { return nil }
                return Notification(name: notificationName,
                                    object: $0,
                                    userInfo: ["changedKeysAndOldValues" : relevantKeysAndOldValues])}
            notifyObservers(changes: notifications)
        }
    }
    
    /// Extracts objects for dictionary keys and sorts them by entityName
    private func extractObjects(for keys:[String], from userInfo: [String : Any]) -> [String : Set<ZMManagedObject>] {
        var allObjects = Set<ZMManagedObject>()
        keys.forEach{
            guard let objects = userInfo[$0] as? Set<ZMManagedObject> else { return }
            allObjects.formUnion(objects)
        }
        let objectsSortedByClass = sortObjectsByEntityName(objects: allObjects)
        return objectsSortedByClass
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
