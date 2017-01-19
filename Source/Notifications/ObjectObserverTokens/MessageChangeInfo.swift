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
    
    public class var observableKeys : [String] {
        return [MessageKey.deliveryState.rawValue, MessageKey.isObfuscated.rawValue]
    }
}

extension ZMImageMessage {
    
    public override class var observableKeys : [String] {
        var keys = ZMMessage.observableKeys
        keys.append(MessageKey.mediumData.rawValue)
        keys.append(MessageKey.mediumRemoteIdentifier.rawValue)
        keys.append(MessageKey.reactions.rawValue)
        return keys
    }
}

extension ZMAssetClientMessage {
    
    public override class var observableKeys : [String] {
        var keys = ZMMessage.observableKeys
        keys.append(ZMAssetClientMessageTransferStateKey)
        keys.append(MessageKey.previewGenericMessage.rawValue)
        keys.append(MessageKey.mediumGenericMessage.rawValue)
        keys.append(ZMAssetClientMessageDownloadedImageKey)
        keys.append(ZMAssetClientMessageDownloadedFileKey)
        keys.append(ZMAssetClientMessageProgressKey)
        keys.append(MessageKey.reactions.rawValue)
        return keys
    }
}

extension ZMClientMessage  {
    
    public override class var observableKeys : [String] {
        var keys = ZMMessage.observableKeys
        keys.append(ZMAssetClientMessageDownloadedImageKey)
        keys.append(MessageKey.linkPreviewState.rawValue)
        keys.append(MessageKey.genericMessage.rawValue)
        keys.append(MessageKey.reactions.rawValue)
        return keys
    }
}


@objc final public class MessageChangeInfo : ObjectChangeInfo {
    
    static let UserChangeInfoKey = "userChanges"
    static let ReactionChangeInfoKey = "reactionChanges"

    static func changeInfo(for message: ZMMessage, changedKeys: [String : NSObject?]) -> MessageChangeInfo? {
        var changedKeysAndValues = changedKeys
        let userChanges = changedKeysAndValues.removeValue(forKey: UserChangeInfoKey) as? [NSObject : [String : Any]]
        let clientChanges = changedKeysAndValues.removeValue(forKey: ReactionChangeInfoKey) as? [NSObject : [String : Any]]
        
        if let clientChanges = clientChanges {
            var reactionChangeInfos = [ReactionChangeInfo]()
            clientChanges.forEach {
                let changeInfo = ReactionChangeInfo(object: $0)
                changeInfo.changedKeysAndOldValues = $1 as! [String : NSObject?]
                reactionChangeInfos.append(changeInfo)
            }
            changedKeysAndValues[ReactionChangeInfoKey] = reactionChangeInfos as NSObject?
        }
        if let userChanges = userChanges, let (object, changes) = userChanges.first {
            let userChangeInfo = UserChangeInfo(object: object)
            userChangeInfo.changedKeysAndOldValues = changes as! [String : NSObject?]
            changedKeysAndValues[UserChangeInfoKey] = userChangeInfo
        }
        
        guard changedKeysAndValues.count > 0 else { return nil }
        
        let changeInfo = MessageChangeInfo(object: message)
        changeInfo.changedKeysAndOldValues = changedKeysAndValues
        return changeInfo
    }
    
    
    public required init(object: NSObject) {
        self.message = object as! ZMMessage
        super.init(object: object)
    }
    public var deliveryStateChanged : Bool {
        return changedKeysAndOldValues.keys.contains(MessageKey.deliveryState.rawValue)
    }
    
    public var reactionsChanged : Bool {
        return changedKeysAndOldValues.keys.contains(MessageKey.reactions.rawValue) || reactionChangeInfos.count != 0
    }

    /// Whether the image data on disk changed
    public var imageChanged : Bool {
        return !Set(arrayLiteral: MessageKey.mediumData.rawValue,
            MessageKey.mediumRemoteIdentifier.rawValue,
            MessageKey.previewGenericMessage.rawValue,
            MessageKey.mediumGenericMessage.rawValue,
            ZMAssetClientMessageDownloadedImageKey
        ).isDisjoint(with: Set(changedKeysAndOldValues.keys))
    }
    
    /// Whether the file on disk changed
    public var fileAvailabilityChanged: Bool {
        return changedKeysAndOldValues.keys.contains(ZMAssetClientMessageDownloadedFileKey)
    }

    public var usersChanged : Bool {
        return userChangeInfo != nil
    }
    
    fileprivate var linkPreviewDataChanged: Bool {
        guard let genericMessage = (message as? ZMClientMessage)?.genericMessage else { return false }
        guard let oldGenericMessage = changedKeysAndOldValues[MessageKey.genericMessage.rawValue] as? ZMGenericMessage else { return false }
        let oldLinks = oldGenericMessage.linkPreviews
        let newLinks = genericMessage.linkPreviews
        
        return oldLinks != newLinks
    }
    
    public var linkPreviewChanged: Bool {
        return changedKeysAndOldValues.keys.contains{$0 == MessageKey.linkPreviewState.rawValue || $0 == MessageKey.linkPreview.rawValue} || linkPreviewDataChanged
    }

    public var senderChanged : Bool {
        if self.usersChanged && (self.userChangeInfo?.user as? ZMUser ==  self.message.sender){
            return true
        }
        return false
    }
    
    public var isObfuscatedChanged : Bool {
        return changedKeysAndOldValues.keys.contains(MessageKey.isObfuscated.rawValue)
    }
    
    public var userChangeInfo : UserChangeInfo? {
        return changedKeysAndOldValues[MessageChangeInfo.UserChangeInfoKey] as? UserChangeInfo
    }
    
    var reactionChangeInfos : [ReactionChangeInfo] {
        return changedKeysAndOldValues[MessageChangeInfo.ReactionChangeInfoKey] as? [ReactionChangeInfo] ?? []
    }
    
    public let message : ZMMessage
}


// MARK: - Reaction observer

private let ReactionUsersKey = "users"

public final class ReactionChangeInfo : ObjectChangeInfo {
    
    var usersChanged : Bool {
        return changedKeysAndOldValues.keys.contains(ReactionUsersKey)
    }
}

@objc protocol ReactionObserver {
    func reactionDidChange(_ reactionInfo: ReactionChangeInfo)
}
