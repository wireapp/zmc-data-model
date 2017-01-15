//
//  SideEffectSoruces.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 13/01/17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation


protocol SideEffectSource {
    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes]
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes]
}

extension SideEffectSource {
    func affectedKeys(for changedKeys: [String], affecting observable: Observable) ->  Set<String> {
        let affectedKeys = Set<String>(observable.observableKeys.flatMap {
            if !observable.keyPathsForValuesAffectingValue(for: $0).isDisjoint(with: changedKeys) {
                return $0
            }
            return nil
        })
        return affectedKeys
    }
    
}


extension ZMUser : SideEffectSource {
    
    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMConversation.entityName():
            let changes = changedValues()
            guard changes.count > 0 else { return [:] }
            
            var conversations = activeConversations.array as? [ZMConversation] ?? []
            if let connectedConversation = connection?.conversation {
                conversations.append(connectedConversation)
            }
            guard conversations.count > 0 else { return  [:] }
            
            let otherPartKeys = changedValues().keys.map{"otherActiveParticipants.\($0)"}
            let selfUserKeys = changedValues().keys.map{"connection.to.\($0)"}
            let mappedKeys = Array(otherPartKeys)+Array(selfUserKeys)
            let keys = affectedKeys(for: mappedKeys, affecting: observable)
            guard keys.count > 0 else { return [:] }
            
            let conversationMap : [NSObject : Changes] = Dictionary(keys: conversations,
                                                                    repeatedValue: Changes(changedKeys: keys))
            return conversationMap
        case ZMMessage.entityName():
            let changes = changedValues()
            guard changes.count > 0 else { return [:] }
            
            var conversations = activeConversations.array as? [ZMConversation] ?? []
            if let connectedConversation = connection?.conversation {
                conversations.append(connectedConversation)
            }
            guard conversations.count > 0 else { return  [:] }
            
            // TODO Sabine: this could be quite expensive :-/
            let messages : [ZMMessage] = conversations.reduce([]){$0 + ($1.messages.array as? [ZMMessage] ?? [])}
                                                      .filter{$0.sender == self}
            let mappedKeys = changedValues().keys.map{"sender.\($0)"}
            let keys = affectedKeys(for: Array(mappedKeys), affecting: observable)            
            
            return Dictionary(keys: messages,
                              repeatedValue: Changes(changedKeys: keys,
                                                     changedKeysAndNewValues: ["userChanges" : [self : changes] as Optional<NSObject>]))
        default:
            return [:]
        }
    }
    
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMConversation.entityName():
            var conversations = activeConversations.array as? [ZMConversation] ?? []
            if let connectedConversation = connection?.conversation {
                conversations.append(connectedConversation)
            }
            guard conversations.count > 0 else { return  [:] }

            return Dictionary(keys: conversations,
                              repeatedValue: Changes(changedKeys: observable.keyPathsAffectedByValue(for: "otherActiveParticipants")))
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
            return [conversation : Changes(changedKeys: observable.keyPathsAffectedByValue(for: "messages"))]
        default:
            return [:]
        }
    }
}

extension ZMConnection : SideEffectSource {
    
    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMConversation.entityName():
            guard let conversation = conversation else { return [:] }
            let mappedKeys = changedValues().keys.map{"connection.\($0)"}
            let keys = affectedKeys(for: Array(mappedKeys), affecting: observable)
            guard keys.count > 0 else { return [:] }
            return [conversation: Changes(changedKeys: keys)]
        
        case ZMUser.entityName():
            guard let user = to else { return [:] }
            let mappedKeys = changedValues().keys.map{"connection.\($0)"}
            let keys = affectedKeys(for: Array(mappedKeys), affecting: observable)
            guard keys.count > 0 else { return [:] }
            return [user: Changes(changedKeys: keys)]
        default:
            return [:]
        }
    }
    
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes] {
        return [:]
    }
}


extension UserClient : SideEffectSource {
    
    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMUser.entityName():
            guard let user = user else { return [:] }
            let changes = changedValues()
            let mappedKeys = changes.keys.map{"clients.\($0)"}
            let keys = affectedKeys(for: Array(mappedKeys), affecting: observable)
            
            var clientChanges = [UserClient : [String : Any]]()
            if changes.keys.contains(where: {$0 == ZMUserClientTrustedKey || $0 == ZMUserClientTrusted_ByKey}) {
                clientChanges[self] = changes
            }
            
            guard keys.count > 0 || clientChanges.count > 0 else { return [:] }
            
            return [user: Changes(changedKeys: keys,
                                  changedKeysAndNewValues: ["clientChanges" : clientChanges as Optional<NSObject>] )]
        default:
            return [:]
        }
    }
    
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMUser.entityName():
            guard let user = user else { return [:] }
            return [user : Changes(changedKeys: observable.keyPathsAffectedByValue(for: "clients"))]
        default:
            return [:]
        }
    }
}

extension Reaction : SideEffectSource {

    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMMessage.entityName():
            guard let message = message else { return [:] }
            let changes = changedValues()
            guard changes.count > 0  else { return [:] }
            
            let mappedKeys = changes.keys.map{"reactions.\($0)"}
            let keys = affectedKeys(for: Array(mappedKeys), affecting: observable)
            
            return [message: Changes(changedKeys: keys,
                                     changedKeysAndNewValues: ["reactionChanges" : [self : changes] as Optional<NSObject>])]
        default:
            return [:]
        }
    }
    
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMMessage.entityName():
            guard let message = message else { return [:] }
            return [message : Changes(changedKeys: observable.keyPathsAffectedByValue(for: "reactions"))]
        default:
            return [:]
        }
    }
}

extension ZMGenericMessageData : SideEffectSource {

    func affectedObjectsAndKeys(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMMessage.entityName():
            guard let msg : ZMMessage = message ?? asset else { return [:] }
            let changes = changedValues()
            guard changes.count > 0  else { return [:] }
            
            let mappedKeys = changes.keys.map{"dataSet.\($0)"}
            let keys = affectedKeys(for: Array(mappedKeys), affecting: observable)
            print(">>>>>>>>",observable.classIdentifier, Array(mappedKeys), observable.observableKeys, keys)
            return [msg: Changes(changedKeys: keys)]
        default:
            return [:]
        }
    }
    
    func affectedObjectsAndKeysForInsertion(observable: Observable) -> [NSObject : Changes] {
        switch observable.classIdentifier {
        case ZMMessage.entityName():
            guard let msg : ZMMessage = message ?? asset else { return [:] }
            return [msg : Changes(changedKeys: observable.keyPathsAffectedByValue(for: "dataSet"))]
        default:
            return [:]
        }
    }
}
