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

private var zmLog = ZMSLog(tag: "MessageChangeInfo")

// MARK: Message observing 

enum MessageKey: String {
    case deliveryState = "deliveryState"
    case mediumData = "mediumData"
    case mediumRemoteIdentifier = "mediumRemoteIdentifier"
    case previewGenericMessage = "previewGenericMessage"
    case mediumGenericMessage = "mediumGenericMessage"
    case linkPreviewState = "linkPreviewState"
    case genericMessage = "genericMessage"
    case reactions = "reactions"
    case isObfuscated = "isObfuscated"
    case linkPreview = "linkPreview"
}

extension ZMMessage : ObjectInSnapshot {
    
    public class var observableKeys : Set<String> {
        return [MessageKey.deliveryState.rawValue, MessageKey.isObfuscated.rawValue]
    }
}

extension ZMAssetClientMessage {

    public class override var observableKeys : Set<String> {
        let keys = super.observableKeys
        let additionalKeys = [ZMAssetClientMessageTransferStateKey,
                              MessageKey.previewGenericMessage.rawValue,
                              MessageKey.mediumGenericMessage.rawValue,
                              ZMAssetClientMessageDownloadedImageKey,
                              ZMAssetClientMessageDownloadedFileKey,
                              ZMAssetClientMessageProgressKey,
                              ZMAssetClientMessageTransferStateKey,
                              MessageKey.reactions.rawValue]
        return keys.union(additionalKeys)
    }
}

extension ZMClientMessage {
    
    public class override var observableKeys : Set<String> {
        let keys = super.observableKeys
        let additionalKeys = [ZMAssetClientMessageDownloadedImageKey,
                              MessageKey.linkPreviewState.rawValue,
                              MessageKey.genericMessage.rawValue,
                              MessageKey.reactions.rawValue,
                              MessageKey.linkPreview.rawValue]
        return keys.union(additionalKeys)
    }
}

extension ZMImageMessage {
    
    public class override var observableKeys : Set<String> {
        let keys = super.observableKeys
        let additionalKeys = [MessageKey.mediumData.rawValue,
                              MessageKey.mediumRemoteIdentifier.rawValue,
                              MessageKey.reactions.rawValue]
        return keys.union(additionalKeys)
    }
}


@objc final public class MessageChangeInfo : ObjectChangeInfo {
    
    static let UserChangeInfoKey = "userChanges"
    static let ReactionChangeInfoKey = "reactionChanges"

    static func changeInfo(for message: ZMMessage, changes: Changes) -> MessageChangeInfo? {
        var originalChanges = changes.originalChanges
        let clientChanges = originalChanges.removeValue(forKey: ReactionChangeInfoKey) as? [NSObject : [String : Any]]
        
        if let clientChanges = clientChanges {
            var reactionChangeInfos = [ReactionChangeInfo]()
            clientChanges.forEach {
                let changeInfo = ReactionChangeInfo(object: $0)
                changeInfo.changedKeysAndOldValues = $1 as! [String : NSObject?]
                reactionChangeInfos.append(changeInfo)
            }
            originalChanges[ReactionChangeInfoKey] = reactionChangeInfos as NSObject?
        }
        
        guard originalChanges.count > 0 || changes.changedKeys.count > 0 else { return nil }
        
        let changeInfo = MessageChangeInfo(object: message)
        changeInfo.changedKeysAndOldValues = originalChanges
        changeInfo.changedKeys = changes.changedKeys
        return changeInfo
    }
    
    
    public required init(object: NSObject) {
        self.message = object as! ZMMessage
        super.init(object: object)
    }
    public var deliveryStateChanged : Bool {
        return changedKeysContain(keys: MessageKey.deliveryState.rawValue)
    }
    
    public var reactionsChanged : Bool {
        return changedKeysContain(keys: MessageKey.reactions.rawValue) || reactionChangeInfos.count != 0
    }

    /// Whether the image data on disk changed
    public var imageChanged : Bool {
        return changedKeysContain(keys: MessageKey.mediumData.rawValue,
            MessageKey.mediumRemoteIdentifier.rawValue,
            MessageKey.previewGenericMessage.rawValue,
            MessageKey.mediumGenericMessage.rawValue,
            ZMAssetClientMessageDownloadedImageKey)
    }
    
    /// Whether the file on disk changed
    public var fileAvailabilityChanged: Bool {
        return changedKeysContain(keys: ZMAssetClientMessageDownloadedFileKey)
    }

    public var usersChanged : Bool {
        return userChangeInfo != nil
    }
    
    public var linkPreviewChanged: Bool {
        return changedKeysContain(keys: MessageKey.linkPreviewState.rawValue, MessageKey.linkPreview.rawValue)
    }

    public var senderChanged : Bool {
        if self.usersChanged && (self.userChangeInfo?.user as? ZMUser ==  self.message.sender){
            return true
        }
        return false
    }
    
    public var isObfuscatedChanged : Bool {
        return changedKeysContain(keys: MessageKey.isObfuscated.rawValue)
    }
    
    public var userChangeInfo : UserChangeInfo? {
        return changedKeysAndOldValues[MessageChangeInfo.UserChangeInfoKey] as? UserChangeInfo
    }
    
    var reactionChangeInfos : [ReactionChangeInfo] {
        return changedKeysAndOldValues[MessageChangeInfo.ReactionChangeInfoKey] as? [ReactionChangeInfo] ?? []
    }
    
    public let message : ZMMessage
    
}



//@objc public protocol ZMMessageObserverOpaqueToken : NSObjectProtocol {}

@objc public protocol ZMMessageObserver : NSObjectProtocol {
    func messageDidChange(_ changeInfo: MessageChangeInfo)
}

extension MessageChangeInfo {
    
    @objc(addObserver:forMessage:)
    public static func add(observer: ZMMessageObserver, for message: ZMConversationMessage) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .MessageChange,
                                                      object: message,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? MessageChangeInfo
                else { return }
            
            observer.messageDidChange(changeInfo)
        } 
    }
    
    @objc(removeObserver:forMessage:)
    public static func remove(observer: NSObjectProtocol, for message: ZMConversationMessage?) {
        NotificationCenter.default.removeObserver(observer, name: .MessageChange, object: message)
    }
}


// MARK: - Reaction observer

private let ReactionUsersKey = "users"

public final class ReactionChangeInfo : ObjectChangeInfo {
    
    var usersChanged : Bool {
        return changedKeysContain(keys: ReactionUsersKey)
    }
}

@objc protocol ReactionObserver {
    func reactionDidChange(_ reactionInfo: ReactionChangeInfo)
}
