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

// TODO Sabine: Pass in snapshots to get previous values

protocol SideEffectSource {
    
    /// Returns a map of objects and keys that are affected by an update and it's resulting changedValues mapped by classIdentifier
    /// [classIdentifier : [affectedObject: changedKeys]]
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>?) -> [ClassIdentifier: ObjectAndChanges]
    
    /// Returns a map of objects and keys that are affected by an insert or deletion mapped by classIdentifier
    /// [classIdentifier : [affectedObject: changedKeys]]
    func affectedObjectsForInsertionOrDeletion(keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges]
}


extension ZMManagedObject {
    
    /// Returns a map of [classIdentifier : [affectedObject: changedKeys]]
    func byInsertOrDeletionAffectedKeys(for object: ZMManagedObject?, keyStore: DependencyKeyStore, affectedKey: String) -> [ClassIdentifier: ObjectAndChanges] {
        guard let object = object else { return [:] }
        let classIdentifier = type(of:object).entityName()
        return [classIdentifier : [object : Changes(changedKeys: keyStore.keyPathsAffectedByValue(classIdentifier, key: affectedKey))]]
    }
    
    /// Returns a map of [classIdentifier : [affectedObject: changedKeys]]
    func byUpdateAffectedKeys(for object: ZMManagedObject?,
                         keyStore: DependencyKeyStore,
                         originalChangeKey: String? = nil,
                         keyMapping: ((String) -> String)) -> [ClassIdentifier: ObjectAndChanges] {
        guard let object = object else { return [:]}
        let classIdentifier = type(of: object).entityName()
        
        let changes = changedValues()
        guard changes.count > 0  else { return [:] }
        
        let mappedKeys : [String] = Array(changes.keys).map(keyMapping)
        let keys = mappedKeys.map{keyStore.keyPathsAffectedByValue(classIdentifier, key: $0)}.reduce(Set()){$0.union($1)}
        guard keys.count > 0 || originalChangeKey != nil else { return [:] }
        
        var originalChanges = [String : NSObject?]()
        if let originalChangeKey = originalChangeKey {
            let requiredKeys = keyStore.requiredKeysForIncludingRawChanges(classIdentifier: classIdentifier, for: self)
            if requiredKeys.count == 0 || !requiredKeys.isDisjoint(with: changes.keys) {
                originalChanges = [originalChangeKey : [self : changes] as Optional<NSObject>]
            }
        }
        return [classIdentifier : [object: Changes(changedKeys: keys, originalChanges: originalChanges)]]
    }
}


extension ZMUser : SideEffectSource {
    
    var allConversations : [ZMConversation] {
        var conversations = activeConversations.array as? [ZMConversation] ?? []
        if let connectedConversation = connection?.conversation {
            conversations.append(connectedConversation)
        }
        return conversations
    }
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [ClassIdentifier: ObjectAndChanges] {
        let changes = changedValues()
        guard changes.count > 0 || knownKeys?.count > 0 else { return [:] }
        
        var allKeys = Set(changes.keys)
        if let knownKeys = knownKeys {
            allKeys.formUnion(knownKeys)
        }
        let conversations = allConversations
        guard conversations.count > 0 else { return  [:] }
        
        let affectedObjects = conversationChanges(changedKeys: allKeys, conversations:conversations, keyStore:keyStore)
        let affectedMessages = messageChanges(changes: changes, allChangedKeys: allKeys, conversations: conversations, keyStore: keyStore)
        return affectedObjects.updated(other: affectedMessages)
    }
    
    func conversationChanges(changedKeys: Set<String>, conversations: [ZMConversation], keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges] {
        var affectedObjects = [String: [NSObject : Changes]]()
        let classIdentifier = ZMConversation.entityName()
        let otherPartKeys = changedKeys.map{"otherActiveParticipants.\($0)"}
        let selfUserKeys = changedKeys.map{"connection.to.\($0)"}
        let mappedKeys = otherPartKeys + selfUserKeys
        let keys = mappedKeys.map{keyStore.keyPathsAffectedByValue(classIdentifier, key: $0)}.reduce(Set()){$0.union($1)}
        if keys.count > 0 {
            affectedObjects[classIdentifier] = Dictionary(keys: Array(conversations), repeatedValue: Changes(changedKeys: keys))
        }
        return affectedObjects
    }
    
    func messageChanges(changes: [String : Any], allChangedKeys: Set<String>, conversations: [ZMConversation], keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges] {
        // TODO Sabine: This is super expensive, maybe we should not do that at all
        var affectedObjects = [String: [NSObject : Changes]]()
        let messages : [ZMMessage] = conversations.reduce([]){$0 + ($1.messages.array as? [ZMMessage] ?? [])}
            .filter{$0.sender == self}
        let mappedMessageKeys = allChangedKeys.map{"sender.\($0)"}
        var originalChanges = [String : NSObject?]()
        let requiredKeys = keyStore.requiredKeysForIncludingRawChanges(classIdentifier: ZMMessage.entityName(), for: self)
        if requiredKeys.count == 0 || !requiredKeys.isDisjoint(with: allChangedKeys) {
            originalChanges["userChanges"] = [self : changes] as Optional<NSObject>
        }
        
        var mapping = [ClassIdentifier : Set<String>]()
        messages.forEach {
            let identifier = type(of: $0).entityName()
            if affectedObjects[identifier] == nil {
                affectedObjects[identifier] = [:]
            }
            mapping[identifier] = mapping[identifier] ?? mappedMessageKeys.map{keyStore.keyPathsAffectedByValue(identifier, key: $0)}
                                                                          .reduce(Set()){$0.union($1)}
            affectedObjects[identifier]?[$0] = Changes(changedKeys: mapping[identifier]!,
                                                       originalChanges: originalChanges)
            
        }
        return affectedObjects
    }
    
    func affectedObjectsForInsertionOrDeletion(keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges] {
        let conversations = allConversations
        guard conversations.count > 0 else { return  [:] }
        
        let classIdentifier = ZMConversation.entityName()
        return [classIdentifier: Dictionary(keys: conversations,
                                            repeatedValue: Changes(changedKeys: keyStore.keyPathsAffectedByValue(classIdentifier, key: "otherActiveParticipants")))]
    }
}

extension ZMMessage : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [ClassIdentifier: ObjectAndChanges] {
        return [:]
    }
    
    func affectedObjectsForInsertionOrDeletion(keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges] {
        return byInsertOrDeletionAffectedKeys(for: conversation, keyStore: keyStore, affectedKey: "messages")
    }
}

extension ZMConnection : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [ClassIdentifier: ObjectAndChanges] {
        let conversationChanges = byUpdateAffectedKeys(for: conversation, keyStore: keyStore, keyMapping: {"connection.\($0)"})
        let userChanges = byUpdateAffectedKeys(for: to, keyStore: keyStore, keyMapping: {"connection.\($0)"})
        return conversationChanges.updated(other: userChanges)
    }
    
    func affectedObjectsForInsertionOrDeletion(keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges] {
        return [:]
    }
}


extension UserClient : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [ClassIdentifier: ObjectAndChanges] {
        return byUpdateAffectedKeys(for: user, keyStore: keyStore, originalChangeKey: "clientChanges", keyMapping: {"clients.\($0)"})
    }
    
    func affectedObjectsForInsertionOrDeletion(keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges] {
        return byInsertOrDeletionAffectedKeys(for: user, keyStore: keyStore, affectedKey: "clients")
    }
}

extension Reaction : SideEffectSource {

    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [ClassIdentifier: ObjectAndChanges] {
        return byUpdateAffectedKeys(for: message, keyStore: keyStore, originalChangeKey: "reactionChanges", keyMapping: {"reactions.\($0)"})
    }
    
    func affectedObjectsForInsertionOrDeletion(keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges] {
        return byInsertOrDeletionAffectedKeys(for: message, keyStore: keyStore, affectedKey: "reactions")
    }
}

extension ZMGenericMessageData : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [ClassIdentifier: ObjectAndChanges] {
        return byUpdateAffectedKeys(for: message ?? asset, keyStore: keyStore, keyMapping: {"dataSet.\($0)"})
    }
    
    func affectedObjectsForInsertionOrDeletion(keyStore: DependencyKeyStore) -> [ClassIdentifier: ObjectAndChanges] {
        return byInsertOrDeletionAffectedKeys(for: message ?? asset, keyStore: keyStore, affectedKey: "dataSet")
    }
}
