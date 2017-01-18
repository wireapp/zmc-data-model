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
#if os(iOS)
    import CoreTelephony
#endif
import ZMCSystem

private let zmLog = ZMSLog(tag: "Observer")

public enum ObjectObserverType: Int {
    
    // The order of this enum is important, because some event create additional observer to fire (reaction fires message notification), 
    // and therefore needs to happen before the message observer handler to propagate properly to the UI
    case invalid = 0
    case connection
    case client
    case userList
    case user
    case displayName
    case searchUser
    case message
    case conversation
    case voiceChannel
    case reaction
    case conversationMessageWindow
    case conversationList

    static func observerTypeForObject(_ object: NSObject) -> ObjectObserverType {
        
        if object is ZMConnection {
            return .connection
        } else if object is ZMUser {
            return .user
        } else if object is ZMMessage {
            return .message
        } else if object is ZMConversation {
            return .conversation
        } else if object is ZMSearchUser {
            return .searchUser
        } else if object is ZMCDataModel.Reaction {
            return .reaction
        } else if object is UserClient {
            return .client
        }
        return .invalid
    }
    
    var shouldForwardDuringSync : Bool {
        switch self {
        case .invalid, .client, .userList, .user, .searchUser, .message, .conversation, .voiceChannel, .conversationMessageWindow, .displayName, .reaction:
            return false
        case .conversationList, .connection:
            return true
        }
    }
    
    func observedObjectType() -> ObjectObserverType {
        switch self {
        case .voiceChannel, .conversationMessageWindow, .conversationList:
            return .conversation
        case .userList, .displayName:
            return .user
        default:
            return self
        }
    }
    
    func printDescription() -> String {
        switch self {
        case .invalid:
            return "Invalid"
        case .connection:
            return "Connection"
        case .user:
            return "User"
        case .searchUser:
            return "SearchUser"
        case .message:
            return "Message"
        case .conversation:
            return "Conversation"
        case .voiceChannel:
            return "VoiceChannel"
        case .conversationMessageWindow:
            return "ConversationMessageWindow"
        case .conversationList:
            return "ConversationList"
        case .client:
            return "UserClient"
        case .userList:
            return "UserList"
        case .displayName:
            return "DisplayName"
        case .reaction:
            return "Reaction"
        }
    }
}

public struct ManagedObjectChangesByObserverType {
    fileprivate let inserted: [ObjectObserverType : [NSObject]]
    fileprivate let deleted: [ObjectObserverType : [NSObject]]
    fileprivate let updated: [ObjectObserverType : [NSObject]]
    
    static func mapByObjectObserverType(_ set: [NSObject]) -> [ObjectObserverType : [NSObject]] {
        var mapping : [ObjectObserverType : [NSObject]] = [:]
        for obj in set {
            let observerType = ObjectObserverType.observerTypeForObject(obj)
            let previous = mapping[observerType] ?? []
            mapping[observerType] = previous + [obj]
        }
        return mapping
    }
    
    init(inserted: [NSObject], deleted: [NSObject], updated: [NSObject]){
        self.inserted = ManagedObjectChangesByObserverType.mapByObjectObserverType(inserted)
        self.deleted = ManagedObjectChangesByObserverType.mapByObjectObserverType(deleted)
        self.updated = ManagedObjectChangesByObserverType.mapByObjectObserverType(updated)
    }
    
    init(changes: ManagedObjectChanges) {
        self.init(inserted: changes.inserted, deleted: changes.deleted, updated: changes.updated)
    }
    
    func changesForObserverType(_ observerType : ObjectObserverType) -> ManagedObjectChanges {
        
        let objectType = observerType.observedObjectType()
        
        let filterInserted = inserted[objectType] ?? []
        let filterDeleted = deleted[objectType] ?? []
        let filterUpdated = updated[objectType] ?? []
        
        return ManagedObjectChanges(
            inserted: filterInserted,
            deleted: filterDeleted,
            updated: filterUpdated
        )
    }
}

public struct ManagedObjectChanges: CustomDebugStringConvertible {
    
    public let inserted: [NSObject]
    public let deleted: [NSObject]
    public let updated: [NSObject]
    
    public init(inserted: [NSObject], deleted: [NSObject], updated: [NSObject]){
        self.inserted = inserted
        self.deleted = deleted
        self.updated = updated
    }
    
    init() {
        self.inserted = []
        self.deleted = []
        self.updated = []
    }
    
    func changesByAppendingChanges(_ changes: ManagedObjectChanges) -> ManagedObjectChanges {
        let inserted = self.inserted + changes.inserted
        let deleted = self.deleted + changes.deleted
        let updated = self.updated + changes.updated
        
        return ManagedObjectChanges(inserted: inserted, deleted: deleted, updated: updated)
    }
    
    public var changesWithoutZombies: ManagedObjectChanges {
        let isNoZombie: (NSObject) -> Bool = {
            guard let managedObject = $0 as? ZMManagedObject else { return true }
            return !managedObject.isZombieObject
        }

        return ManagedObjectChanges(
            inserted: inserted.filter(isNoZombie),
            deleted: deleted,
            updated: updated.filter(isNoZombie)
        )
    }
    
    init(note: Notification) {

        var inserted, deleted: [NSObject]?
        var updatedAndRefreshed = [NSObject]()
        
        if let insertedSet = note.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> {
            inserted = Array(insertedSet)
        }
        
        if let deletedSet = note.userInfo?[NSDeletedObjectsKey] as? Set<NSObject> {
            deleted = Array(deletedSet)
        }
        
        if let updatedSet = note.userInfo?[NSUpdatedObjectsKey] as? Set<NSObject> {
            updatedAndRefreshed.append(contentsOf: updatedSet)
        }
        
        if let refreshedSet = note.userInfo?[NSRefreshedObjectsKey] as? Set<NSObject> {
            updatedAndRefreshed.append(contentsOf: refreshedSet)
        }
        
        self.init(inserted: inserted ?? [], deleted: deleted ?? [], updated: updatedAndRefreshed)
    }
    
    public var debugDescription : String { return "Inserted: \(SwiftDebugging.shortDescription(inserted)), updated: \(SwiftDebugging.shortDescription(updated)), deleted: \(SwiftDebugging.shortDescription(deleted))" }
    public var description : String { return debugDescription }
    
    public var isEmpty : Bool {
        return self.inserted.count + self.updated.count + self.deleted.count == 0
    }
}

public func +(lhs: ManagedObjectChanges, rhs: ManagedObjectChanges) -> ManagedObjectChanges {
    return lhs.changesByAppendingChanges(rhs)
}
