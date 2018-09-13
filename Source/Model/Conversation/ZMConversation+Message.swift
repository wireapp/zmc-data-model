//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

private let log = ZMSLog(tag: "Conversations")

extension ZMConversation {
    
    func append(location: LocationData, nonce: UUID = UUID()) -> ZMConversationMessage? {
        return appendClientMessage(with: ZMGenericMessage.message(content: location.zmLocation(), nonce: nonce, expiresAfter: messageDestructionTimeoutValue))
    }
    
    func appendKnock(nonce: UUID = UUID()) -> ZMConversationMessage? {
        return appendClientMessage(with: ZMGenericMessage.message(content: ZMKnock.knock(), nonce: nonce, expiresAfter: messageDestructionTimeoutValue))
    }
    
    func append(text: String, mentions: [Mention] = [], fetchLinkPreview: Bool = true, nonce: UUID = UUID()) -> ZMConversationMessage? {
        let message = appendClientMessage(with: ZMGenericMessage.message(content: ZMText.text(with: text, mentions: mentions, linkPreviews: []), nonce: nonce, expiresAfter: messageDestructionTimeoutValue))
        
        message?.linkPreviewState = fetchLinkPreview ? .waitingToBeProcessed : .done
        
        if let managedObjectContext = managedObjectContext {
            NotificationInContext(name: ZMConversation.clearTypingNotificationName,
                                  context: managedObjectContext.notificationContext,
                                  object: self).post()
        }
        
        return message
    }
    
    func append(imageAtURL URL: URL, nonce: UUID = UUID()) -> ZMConversationMessage?  {
        guard URL.isFileURL,
              ZMImagePreprocessor.sizeOfPrerotatedImage(at: URL) != .zero,
              let imageData = try? Data.init(contentsOf: URL, options: []) else { return nil }
        
        return append(imageFromData: imageData)
    }
    
    func append(imageFromData imageData: Data, nonce: UUID = UUID()) -> ZMConversationMessage? {
        do {
            let imageDataWithoutMetadata = try imageData.wr_removingImageMetadata()
            return appendAssetClientMessage(withNonce: nonce, imageData: imageDataWithoutMetadata)
        } catch let error {
            log.error("Cannot remove image metadata: \(error)")
            return nil
        }
    }
    
    func append(file fileMetadata: ZMFileMetadata, nonce: UUID = UUID()) -> ZMConversationMessage? {
        guard let data = try? Data.init(contentsOf: fileMetadata.fileURL, options: .mappedIfSafe),
              let managedObjectContext = managedObjectContext else { return nil }
        
        guard let message = ZMAssetClientMessage(with: fileMetadata,
                                                 nonce: nonce,
                                                 managedObjectContext: managedObjectContext,
                                                 expiresAfter: messageDestructionTimeoutValue) else { return  nil}
        
        message.sender = ZMUser.selfUser(in: managedObjectContext)
        
        sortedAppendMessage(message)
        unarchiveIfNeeded()
        
        managedObjectContext.zm_fileAssetCache.storeAssetData(message, encrypted: false, data: data)
        
        if let thumbnailData = fileMetadata.thumbnail {
            managedObjectContext.zm_fileAssetCache.storeAssetData(message, format: .original, encrypted: false, data: thumbnailData)
        }
        
        message.updateCategoryCache()
        message.prepareToSend()
        
        return message
    }
    
    // MARK: - Helper methods
    
    func append(message: MessageContentType, nonce: UUID = UUID(), hidden: Bool = false, expires: Bool = false) -> ZMClientMessage? {
        return appendClientMessage(with: ZMGenericMessage.message(content: message, nonce: nonce), expires: expires, hidden: hidden)
    }
    
}
