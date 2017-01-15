//
//  AffectingKeyStore.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 13/01/17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation

private var zmLog = ZMSLog(tag: "DependencyKeyStore")

private enum MessageKey: String {
    case deliveryState = "deliveryState"
    case mediumData = "mediumData"
    case mediumRemoteIdentifier = "mediumRemoteIdentifier"
    case previewGenericMessage = "previewGenericMessage"
    case mediumGenericMessage = "mediumGenericMessage"
    case linkPreviewState = "linkPreviewState"
    case linkPreview = "linkPreview"
    case genericMessage = "genericMessage"
    case reactions = "reactions"
    case isObfuscated = "isObfuscated"
}

class DependencyKeyStore {
    
    let observableKeys : [String: Set<String>]
    let allKeys : [String : Set<String>]
    private let affectingKeys : [String : [String : Set<String>]]
    private let effectedKeys : [String : [String : Set<String>]]
    
    init(classIdentifiers: [String]) {
        let observable = Dictionary.mappingKeysToValues(keys:classIdentifiers){DependencyKeyStore.setupObservableKeys(classIdentifier: $0)}
        let affecting = Dictionary.mappingKeysToValues(keys:classIdentifiers){DependencyKeyStore.setupAffectedKeys(classIdentifier: $0,
                                                                                                                   observableKeys: observable[$0]!)}
        let all = Dictionary.mappingKeysToValues(keys:classIdentifiers){DependencyKeyStore.setupAllKeys(observableKeys: observable[$0]!,
                                                                                                        affectingKeys: affecting[$0]!)}
        let affectingInverse = Dictionary.mappingKeysToValues(keys:classIdentifiers){DependencyKeyStore.setupEffectedKeys(affectingKeys: affecting[$0]!)}
        
        self.observableKeys = observable
        self.affectingKeys = affecting
        self.allKeys = all
        self.effectedKeys = affectingInverse
    }
    
    /// When adding objects that are to be observed, add keys that are supposed to be reported on in here
    private static func setupObservableKeys(classIdentifier: String) -> Set<String> {
        switch classIdentifier {
        case ZMConversation.entityName():
            return Set(arrayLiteral: "messages", "lastModifiedDate", "isArchived", "conversationListIndicator", "voiceChannelState", "activeFlowParticipants", "callParticipants", "isSilenced", "securityLevel", "otherActiveVideoCallParticipants", "displayName", "estimatedUnreadCount", "clearedTimeStamp", "otherActiveParticipants", "isSelfAnActiveMember", "relatedConnectionState")
        case ZMUser.entityName():
            return Set(arrayLiteral: "name", "displayName", "accentColorValue", "imageMediumData", "imageSmallProfileData","emailAddress", "phoneNumber", "canBeConnected", "isConnected", "isPendingApprovalByOtherUser", "isPendingApprovalBySelfUser", "clients", "handle")
        case ZMConnection.entityName():
            return Set(arrayLiteral: "status")
        case UserClient.entityName():
            return Set([ZMUserClientTrusted_ByKey, ZMUserClientIgnored_ByKey, ZMUserClientNeedsToNotifyUserKey, ZMUserClientFingerprintKey])
        case ZMMessage.entityName(), ZMSystemMessage.entityName():
            return Set([MessageKey.deliveryState.rawValue, MessageKey.isObfuscated.rawValue])
        case ZMAssetClientMessage.entityName():
            var keys = [MessageKey.deliveryState.rawValue, MessageKey.isObfuscated.rawValue]
            keys.append(ZMAssetClientMessageTransferStateKey)
            keys.append(MessageKey.previewGenericMessage.rawValue)
            keys.append(MessageKey.mediumGenericMessage.rawValue)
            keys.append(ZMAssetClientMessageDownloadedImageKey)
            keys.append(ZMAssetClientMessageDownloadedFileKey)
            keys.append(ZMAssetClientMessageProgressKey)
            keys.append(MessageKey.reactions.rawValue)
            return Set(keys)
        case ZMClientMessage.entityName():
            var keys = [MessageKey.deliveryState.rawValue, MessageKey.isObfuscated.rawValue]
            keys.append(ZMAssetClientMessageDownloadedImageKey)
            keys.append(MessageKey.linkPreviewState.rawValue)
            keys.append(MessageKey.genericMessage.rawValue)
            keys.append(MessageKey.reactions.rawValue)
            keys.append(MessageKey.linkPreview.rawValue)
            return Set(keys)
        case Reaction.entityName(), ZMGenericMessageData.entityName():
            return Set()
        default:
            zmLog.warn("There are no observable keys defined for \(classIdentifier)")
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
        case UserClient.entityName():
            return Dictionary.mappingKeysToValues(keys: Array(observableKeys)){UserClient.keyPathsForValuesAffectingValue(forKey: $0)}
        case ZMMessage.entityName():
            return Dictionary.mappingKeysToValues(keys: Array(observableKeys)){ZMMessage.keyPathsForValuesAffectingValue(forKey: $0)}
        case ZMAssetClientMessage.entityName():
            return Dictionary.mappingKeysToValues(keys: Array(observableKeys)){ZMAssetClientMessage.keyPathsForValuesAffectingValue(forKey: $0)}
        case ZMClientMessage.entityName():
            return Dictionary.mappingKeysToValues(keys: Array(observableKeys)){ZMClientMessage.keyPathsForValuesAffectingValue(forKey: $0)}
        case Reaction.entityName():
            return Dictionary.mappingKeysToValues(keys: Array(observableKeys)){Reaction.keyPathsForValuesAffectingValue(forKey: $0)}
        case ZMGenericMessageData.entityName():
            return Dictionary.mappingKeysToValues(keys: Array(observableKeys)){ZMGenericMessageData.keyPathsForValuesAffectingValue(forKey: $0)}
        default:
            zmLog.warn("There is no path to affecting keys defined for \(classIdentifier)")
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
    
    /// Returns keyPathsForValuesAffectingValueForKey for specified `key`
    func keyPathsForValuesAffectingValue(_ classIdentifier: String, key: String) -> Set<String>{
        return affectingKeys[classIdentifier]?[key] ?? Set()
    }
    
    /// Returns the inverse of keyPathsForValuesAffectingValueForKey, all keys that are affected by `key`
    func keyPathsAffectedByValue(_ classIdentifier: String, key: String) -> Set<String>{
        var keys = effectedKeys[classIdentifier]?[key] ?? Set()
        if let otherKeys = observableKeys[classIdentifier], otherKeys.contains(key) {
            keys.insert(key)
        }
        return keys
    }
}
