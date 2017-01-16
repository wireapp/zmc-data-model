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

extension SideEffectSource {
    func affectedKeys(for changedKeys: [String], affectingObjectWith classIdentifier: String, keyStore: DependencyKeyStore) ->  Set<String> {
        let affectedKeys : [String] = keyStore.observableKeys[classIdentifier]?.flatMap {
            if !keyStore.keyPathsForValuesAffectingValue(classIdentifier, key: $0).isDisjoint(with: changedKeys) {
                return $0
            }
            return nil
        } ?? []
        return Set(affectedKeys)
    }
    
}


extension ZMUser : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        var changes = changedValues()
        if let knownKeys = knownKeys {
            changes = changes.updated(other: Dictionary(keys: Array(knownKeys), repeatedValue: .none as Optional<NSObject>))
        }
        guard changes.count > 0 else { return [:] }
        
        var conversations = activeConversations.array as? [ZMConversation] ?? []
        if let connectedConversation = connection?.conversation {
            conversations.append(connectedConversation)
        }
        guard conversations.count > 0 else { return  [:] }
        
        var affectedObjects = [String: [NSObject : Changes]]()

        // Affected Conversations
        let classIdentifier = ZMConversation.entityName()
        let otherPartKeys = changes.keys.map{"otherActiveParticipants.\($0)"}
        let selfUserKeys = changes.keys.map{"connection.to.\($0)"}
        let mappedKeys = Array(otherPartKeys) + Array(selfUserKeys)
        let keys = affectedKeys(for: mappedKeys, affectingObjectWith: classIdentifier, keyStore: keyStore)
        if keys.count > 0 {
            affectedObjects[classIdentifier] = Dictionary(keys: conversations, repeatedValue: Changes(changedKeys: keys))
        }
        // Affected Messages
        // TODO Sabine: this could be quite expensive :-/
        let messages : [ZMMessage] = conversations.reduce([]){$0 + ($1.messages.array as? [ZMMessage] ?? [])}
            .filter{$0.sender == self}
        let mappedMessageKeys = changes.map{"sender.\($0)"}
        
        messages.forEach {
            let identifier = type(of: $0).entityName()
            if affectedObjects[identifier] == nil {
                affectedObjects[identifier] = [:]
            }
            affectedObjects[identifier]?[$0] = Changes(changedKeys: affectedKeys(for: mappedMessageKeys, affectingObjectWith: identifier, keyStore: keyStore),
                                                       changedKeysAndNewValues: ["userChanges" : [self : changes] as Optional<NSObject>])

        }
        return affectedObjects
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        var conversations = activeConversations.array as? [ZMConversation] ?? []
        if let connectedConversation = connection?.conversation {
            conversations.append(connectedConversation)
        }
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
        guard let conversation = conversation else { return  [:] }
        let classIdentifier = ZMConversation.entityName()
        return [classIdentifier : [conversation : Changes(changedKeys: keyStore.keyPathsAffectedByValue(classIdentifier, key: "messages"))]]
    }
}

extension ZMConnection : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        var affectedObjects = [String: [NSObject : Changes]]()
        if let conversation = conversation {
            let mappedKeys = changedValues().keys.map{"connection.\($0)"}
            let classIdentifier = ZMConversation.entityName()
            let keys = affectedKeys(for: Array(mappedKeys), affectingObjectWith: classIdentifier, keyStore: keyStore)
            if keys.count > 0 {
                affectedObjects[classIdentifier] = [conversation: Changes(changedKeys: keys)]
            }
        }
        if let user = to {
            let mappedKeys = changedValues().keys.map{"connection.\($0)"}
            let classIdentifier = ZMUser.entityName()
            let keys = affectedKeys(for: Array(mappedKeys), affectingObjectWith: classIdentifier, keyStore: keyStore)
            if keys.count > 0 {
                affectedObjects[classIdentifier] = [user : Changes(changedKeys: keys)]
            }
        }
        return affectedObjects
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        return [:]
    }
}


extension UserClient : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        guard let user = user else { return [:] }
        let classIdentifier = ZMUser.entityName()
        let changes = changedValues()
        let mappedKeys = changes.keys.map{"clients.\($0)"}
        let keys = affectedKeys(for: Array(mappedKeys), affectingObjectWith: classIdentifier, keyStore: keyStore)
        
        var clientChanges = [UserClient : [String : Any]]()
        if changes.keys.contains(where: {$0 == ZMUserClientTrustedKey || $0 == ZMUserClientTrusted_ByKey}) {
            clientChanges[self] = changes
        }
        
        guard keys.count > 0 || clientChanges.count > 0 else { return [:] }
        
        return [classIdentifier : [user: Changes(changedKeys: keys,
                                                 changedKeysAndNewValues: ["clientChanges" : clientChanges as Optional<NSObject>] )]]
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        guard let user = user else { return [:] }
        let classIdentifier = ZMUser.entityName()
        return [classIdentifier : [user : Changes(changedKeys: keyStore.keyPathsAffectedByValue(classIdentifier, key: "clients"))]]
    }
}

extension Reaction : SideEffectSource {

    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        guard let message = message else { return [:] }
        let changes = changedValues()
        guard changes.count > 0  else { return [:] }
        
        let classIdentifier = type(of: message).entityName()
        let mappedKeys = changes.keys.map{"reactions.\($0)"}
        let keys = affectedKeys(for: Array(mappedKeys), affectingObjectWith: classIdentifier, keyStore: keyStore)
        
        return [classIdentifier : [message: Changes(changedKeys: keys,
                                 changedKeysAndNewValues: ["reactionChanges" : [self : changes] as Optional<NSObject>])]]
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        guard let message = message else { return [:] }
        let classIdentifier = type(of: message).entityName()
        return [classIdentifier : [message : Changes(changedKeys: keyStore.keyPathsAffectedByValue(classIdentifier, key: "reactions"))]]
    }
}

extension ZMGenericMessageData : SideEffectSource {
    
    func affectedObjectsAndKeys(keyStore: DependencyKeyStore, knownKeys: Set<String>? = nil) -> [String: [NSObject : Changes]] {
        let classIdentifier : String
        let object : NSObject
        if let msg = message {
            object = msg
            classIdentifier = ZMClientMessage.entityName()
        } else if let msg = asset {
            object = msg
            classIdentifier = ZMAssetClientMessage.entityName()
        } else {
            return [:]
        }
        
        let changes = changedValues()
        guard changes.count > 0  else { return [:] }
        
        let mappedKeys = changes.keys.map{"dataSet.\($0)"}
        let keys = affectedKeys(for: Array(mappedKeys), affectingObjectWith: classIdentifier, keyStore: keyStore)
        return [classIdentifier : [object: Changes(changedKeys: keys)]]
    }
    
    func affectedObjectsAndKeysForInsertion(keyStore: DependencyKeyStore) -> [String: [NSObject : Changes]] {
        let classIdentifier : String
        let object : NSObject
        if let msg = message {
            object = msg
            classIdentifier = ZMClientMessage.entityName()
        } else if let msg = asset {
            object = msg
            classIdentifier = ZMAssetClientMessage.entityName()
        } else {
            return [:]
        }
        return [classIdentifier : [object: Changes(changedKeys: keyStore.keyPathsAffectedByValue(classIdentifier, key: "dataSet"))]]
    }
}
