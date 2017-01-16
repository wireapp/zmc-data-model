//
//  SideEffectSoruces.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 13/01/17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation


protocol SideEffectSource {
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>?) -> [String: [NSObject : Changes]]
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]]
}


extension ZMManagedObject {

    func affectedKeys(for changedKeys: [String], affectingObjectWith classIdentifier: String, keyStore: DependencyKeyStore) ->  Set<String> {
        let affectedKeys : [String] = keyStore.observableKeys[classIdentifier]?.flatMap {
             keyStore.keyPathsForValuesAffectingValue(classIdentifier, key: $0).isDisjoint(with: changedKeys) ? nil : $0
        } ?? []
        return Set(affectedKeys)
    }
    
    func byInsertAffectedKeys(for object: ZMManagedObject?, keyStore: DependencyKeyStore, affectedKey: String) -> [String: [NSObject : Changes]] {
        guard let object = object else { return [:] }
        let classIdentifier = type(of:object).entityName()
        return [classIdentifier : [object : Changes(changedKeys: keyStore.keyPathsAffectedByValue(classIdentifier, key: affectedKey))]]
    }
    
    func byUpdateAffectedKeys(for object: ZMManagedObject?,
                         keyStore: DependencyKeyStore,
                         originalChangeKey: String? = nil,
                         keyMapping: ((String) -> String)) -> [String: [NSObject : Changes]] {
        guard let object = object else { return [:]}
        let classIdentifier = type(of: object).entityName()
        
        let changes = changedValues()
        guard changes.count > 0  else { return [:] }
        
        let mappedKeys : [String] = Array(changes.keys).map(keyMapping)
        let keys = affectedKeys(for: mappedKeys, affectingObjectWith: classIdentifier, keyStore: keyStore)
        guard keys.count > 0 || originalChangeKey != nil else { return [:] }
        
        var changedKeysAndNewValues = [String : NSObject?]()
        if let originalChangeKey = originalChangeKey {
            let requiredKeys = keyStore.requiredKeysForIncludingRawChanges(classIdentifier: classIdentifier, for: self)
            if requiredKeys.count == 0 || !requiredKeys.isDisjoint(with: changes.keys) {
                changedKeysAndNewValues = [originalChangeKey : [self : changes] as Optional<NSObject>]
            }
        }
        return [classIdentifier : [object: Changes(changedKeys: keys, changedKeysAndNewValues: changedKeysAndNewValues)]]
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
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        var changes = changedValues()
        if let knownKeys = knownKeys {
            changes = changes.updated(other: Dictionary(keys: Array(knownKeys), repeatedValue: .none as Optional<NSObject>))
        }
        guard changes.count > 0 else { return [:] }
        
        let conversations = allConversations
        guard conversations.count > 0 else { return  [:] }
        
        let affectedObjects = conversationChanges(changedKeys: Array(changes.keys), conversations:conversations, keyStore:keyStore)
        let affectedMessages = messageChanges(changes: changes, conversations: conversations, keyStore: keyStore)
        return affectedObjects.updated(other: affectedMessages)
    }
    
    func conversationChanges(changedKeys: [String], conversations: [ZMConversation], keyStore: DependencyKeyStore) -> [String : [NSObject : Changes]] {
        var affectedObjects = [String: [NSObject : Changes]]()
        let classIdentifier = ZMConversation.entityName()
        let otherPartKeys = changedKeys.map{"otherActiveParticipants.\($0)"}
        let selfUserKeys = changedKeys.map{"connection.to.\($0)"}
        let mappedKeys = otherPartKeys + selfUserKeys
        let keys = affectedKeys(for: mappedKeys, affectingObjectWith: classIdentifier, keyStore: keyStore)
        if keys.count > 0 {
            affectedObjects[classIdentifier] = Dictionary(keys: conversations, repeatedValue: Changes(changedKeys: keys))
        }
        return affectedObjects
    }
    
    func messageChanges(changes: [String : Any], conversations: [ZMConversation], keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        // TODO Sabine: This is super expensive, maybe we should not do that at all
        var affectedObjects = [String: [NSObject : Changes]]()
        let messages : [ZMMessage] = conversations.reduce([]){$0 + ($1.messages.array as? [ZMMessage] ?? [])}
            .filter{$0.sender == self}
        let mappedMessageKeys = changes.map{"sender.\($0)"}
        var changedKeysAndNewValues = [String : NSObject?]()
        let requiredKeys = keyStore.requiredKeysForIncludingRawChanges(classIdentifier: ZMMessage.entityName(), for: self)
        if requiredKeys.count == 0 || !requiredKeys.isDisjoint(with: changes.keys) {
            changedKeysAndNewValues["userChanges"] = [self : changes] as Optional<NSObject>
        }
        
        messages.forEach {
            let identifier = type(of: $0).entityName()
            if affectedObjects[identifier] == nil {
                affectedObjects[identifier] = [:]
            }
            affectedObjects[identifier]?[$0] = Changes(changedKeys: affectedKeys(for: mappedMessageKeys,
                                                                                 affectingObjectWith: identifier,
                                                                                 keyStore: keyStore),
                                                       changedKeysAndNewValues: changedKeysAndNewValues)
            
        }
        return affectedObjects
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        let conversations = allConversations
        guard conversations.count > 0 else { return  [:] }
        
        let classIdentifier = ZMConversation.entityName()
        return [classIdentifier: Dictionary(keys: conversations,
                                            repeatedValue: Changes(changedKeys: keyStore.keyPathsAffectedByValue(classIdentifier, key: "otherActiveParticipants")))]
    }
}

extension ZMMessage : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        return [:]
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        return byInsertAffectedKeys(for: conversation, keyStore: keyStore, affectedKey: "messages")
    }
}

extension ZMConnection : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        let conversationChanges = byUpdateAffectedKeys(for: conversation, keyStore: keyStore, keyMapping: {"connection.\($0)"})
        let userChanges = byUpdateAffectedKeys(for: to, keyStore: keyStore, keyMapping: {"connection.\($0)"})
        return conversationChanges.updated(other: userChanges)
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        return [:]
    }
}


extension UserClient : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        return byUpdateAffectedKeys(for: user, keyStore: keyStore, originalChangeKey: "clientChanges", keyMapping: {"clients.\($0)"})
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        return byInsertAffectedKeys(for: user, keyStore: keyStore, affectedKey: "clients")
    }
}

extension Reaction : SideEffectSource {

    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        return byUpdateAffectedKeys(for: message, keyStore: keyStore, originalChangeKey: "reactionChanges", keyMapping: {"reactions.\($0)"})
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        return byInsertAffectedKeys(for: message, keyStore: keyStore, affectedKey: "reactions")
    }
}

extension ZMGenericMessageData : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        return byUpdateAffectedKeys(for: message ?? asset, keyStore: keyStore, keyMapping: {"dataSet.\($0)"})
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        return byInsertAffectedKeys(for: message ?? asset, keyStore: keyStore, affectedKey: "dataSet")
    }
}
