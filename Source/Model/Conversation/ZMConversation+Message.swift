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

    /// Appends a button action message.
    ///
    /// - Parameters:
    ///     - id: The id of the button action.
    ///     - referenceMessageId: The id of the message which this action references.
    ///     - nonce: The nonce of the button action message.
    ///
    /// - Throws:
    ///     - `AppendMessageError` if the message couldn't be appended.
    ///
    /// - Returns:
    ///     The appended message.

    @discardableResult
    func appendButtonAction(havingId id: String, referenceMessageId: UUID, nonce: UUID = UUID()) throws -> ZMClientMessage {
        let buttonAction = ButtonAction(buttonId: id, referenceMessageId: referenceMessageId)
        return try appendClientMessage(with: GenericMessage(content: buttonAction, nonce: nonce), hidden: true)
    }

    /// Appends a location message.
    ///
    /// - Parameters:
    ///     - locationData: The data describing the location.
    ///     - nonce: The nonce of the location message.
    ///
    /// - Throws:
    ///     - `AppendMessageError` if the message couldn't be appended.
    ///
    /// - Returns:
    ///     The appended message.

    @discardableResult
    public func appendLocation(with locationData: LocationData, nonce: UUID = UUID()) throws -> ZMConversationMessage {
        let locationContent = Location.with {
            if let name = locationData.name {
                $0.name = name
            }

            $0.latitude = locationData.latitude
            $0.longitude = locationData.longitude
            $0.zoom = locationData.zoomLevel
        }

        let message = GenericMessage(content: locationContent, nonce: nonce, expiresAfter: messageDestructionTimeoutValue)
        return try appendClientMessage(with: message)
    }

    /// Appends a knock message.
    ///
    /// - Parameters:
    ///     - nonce: The nonce of the knock message.
    ///
    /// - Throws:
    ///     `AppendMessageError` if the message couldn't be appended.
    ///
    /// - Returns:
    ///     The appended message.

    @discardableResult
    public func appendKnock(nonce: UUID = UUID()) throws -> ZMConversationMessage {
        let content = Knock.with { $0.hotKnock = false }
        let message = GenericMessage(content: content, nonce: nonce, expiresAfter: messageDestructionTimeoutValue)
        return try appendClientMessage(with: message)
    }

    public enum UpdateSelfConversationError: Error {

        case missingLastReadTimestamp
        case invalidConversation

    }

    // TODO: Move these to a new file

    /// Append a `LastRead` message derived from a given conversation to the self conversation.
    ///
    /// - Parameters:
    ///     - conversation: The conversation from which the last read message is derived.
    ///
    /// - Throws:
    ///     - `UpdateSelfConversationError` if last read can't or shouldn't be derived from `conversation`.
    ///     - `AppendMessageError` if the last read message couldn't be appended.
    ///
    /// - Returns:
    ///     The appended message.

    @discardableResult
    public static func updateSelfConversation(withLastReadOf conversation: ZMConversation) throws -> ZMClientMessage {
        guard let lastReadTimeStamp = conversation.lastReadServerTimeStamp else {
            throw UpdateSelfConversationError.missingLastReadTimestamp
        }

        guard
            let moc = conversation.managedObjectContext,
            let convID = conversation.remoteIdentifier,
            convID != ZMConversation.selfConversationIdentifier(in: moc)
        else {
            throw UpdateSelfConversationError.invalidConversation
        }

        let lastRead = LastRead(conversationID: convID, lastReadTimestamp: lastReadTimeStamp)
        let genericMessage = GenericMessage(content: lastRead, nonce: .init())
        let selfConversation = ZMConversation.selfConversation(in: moc)

        return try selfConversation.appendClientMessage(with: genericMessage, expires: false, hidden: false)
    }

    /// Create and append to self conversation a ClientMessage that has generic message data built with the given data

    public static func appendSelfConversation(genericMessage: GenericMessage, managedObjectContext: NSManagedObjectContext) -> ZMClientMessage? {
        let selfConversation = ZMConversation.selfConversation(in: managedObjectContext)
        // TODO: [John] handle?
        let clientMessage = try? selfConversation.appendClientMessage(with: genericMessage, expires: false, hidden: false)
        return clientMessage
    }


    public static func appendSelfConversation(withClearedOf conversation: ZMConversation) -> ZMClientMessage? {
        guard let convID = conversation.remoteIdentifier,
            let cleared = conversation.clearedTimeStamp,
            let managedObjectContext = conversation.managedObjectContext,
            convID != ZMConversation.selfConversationIdentifier(in: managedObjectContext) else {
                return nil
        }
        let message = GenericMessage(content: Cleared(timestamp: cleared, conversationID: convID), nonce: UUID())
        return appendSelfConversation(genericMessage: message, managedObjectContext: managedObjectContext)
    }

    @discardableResult
    public func append(text: String,
                       mentions: [Mention] = [],
                       fetchLinkPreview: Bool = true,
                       nonce: UUID = UUID()) -> ZMConversationMessage? {

        return append(text: text, mentions: mentions, replyingTo: nil, fetchLinkPreview: fetchLinkPreview, nonce: nonce)
    }

    @discardableResult
    public func append(text: String,
                       mentions: [Mention] = [],
                       replyingTo quotedMessage: ZMConversationMessage? = nil,
                       fetchLinkPreview: Bool = true,
                       nonce: UUID = UUID()) -> ZMConversationMessage? {

        guard
            let moc = managedObjectContext,
            !(text as NSString).zmHasOnlyWhitespaceCharacters()
            else {
                return nil
        }

        let text = Text(content: text, mentions: mentions, linkPreviews: [], replyingTo: quotedMessage as? ZMOTRMessage)
        let genericMessage = GenericMessage(content: text, nonce: nonce, expiresAfter: messageDestructionTimeoutValue)
        let clientMessage = ZMClientMessage(nonce: nonce, managedObjectContext: moc)

        do {
            try clientMessage.setUnderlyingMessage(genericMessage)
            clientMessage.linkPreviewState = fetchLinkPreview ? .waitingToBeProcessed : .done
            clientMessage.needsLinkAttachmentsUpdate = fetchLinkPreview
            clientMessage.quote = quotedMessage as? ZMMessage

            try append(clientMessage, expires: true, hidden: false)

            NotificationInContext(name: ZMConversation.clearTypingNotificationName,
                                  context: moc.notificationContext,
                                  object: self).post()

            return clientMessage
        } catch {
            moc.delete(clientMessage)
            return nil
        }
    }

    @discardableResult
    public func append(imageAtURL URL: URL, nonce: UUID = UUID()) -> ZMConversationMessage?  {
        guard URL.isFileURL,
            ZMImagePreprocessor.sizeOfPrerotatedImage(at: URL) != .zero,
            let imageData = try? Data.init(contentsOf: URL, options: []) else { return nil }

        return append(imageFromData: imageData)
    }

    @discardableResult
    public func append(imageFromData imageData: Data, nonce: UUID = UUID()) -> ZMConversationMessage? {
        guard let managedObjectContext = managedObjectContext,
            let imageData = try? imageData.wr_removingImageMetadata() else { return nil }


        // mimeType is assigned first, to make sure UI can handle animated GIF file correctly
        let mimeType = ZMAssetMetaDataEncoder.contentType(forImageData: imageData) ?? ""
        // We update the size again when the the preprocessing is done
        let imageSize = ZMImagePreprocessor.sizeOfPrerotatedImage(with: imageData)

        let asset = WireProtos.Asset(imageSize: imageSize, mimeType: mimeType, size: UInt64(imageData.count))

        return append(asset: asset, nonce: nonce, expires: true, prepareMessage: { message in
            managedObjectContext.zm_fileAssetCache.storeAssetData(message, format: .original, encrypted: false, data: imageData)
        })
    }

    @discardableResult
    public func append(file fileMetadata: ZMFileMetadata, nonce: UUID = UUID()) -> ZMConversationMessage? {
        guard let data = try? Data.init(contentsOf: fileMetadata.fileURL, options: .mappedIfSafe),
            let managedObjectContext = managedObjectContext else { return nil }

        return append(asset: fileMetadata.asset, nonce: nonce, expires: false) { (message) in
            managedObjectContext.zm_fileAssetCache.storeAssetData(message, encrypted: false, data: data)

            if let thumbnailData = fileMetadata.thumbnail {
                managedObjectContext.zm_fileAssetCache.storeAssetData(message, format: .original, encrypted: false, data: thumbnailData)
            }
        }
    }


    private func append(asset: WireProtos.Asset, nonce: UUID, expires: Bool, prepareMessage: (ZMAssetClientMessage) -> Void) -> ZMAssetClientMessage? {
        guard let managedObjectContext = managedObjectContext,
            let message = ZMAssetClientMessage(asset: asset,
                                               nonce: nonce,
                                               managedObjectContext: managedObjectContext,
                                               expiresAfter: messageDestructionTimeoutValue)
            else { return nil }

        message.sender = ZMUser.selfUser(in: managedObjectContext)

        if expires {
            message.setExpirationDate()
        }

        append(message)
        unarchiveIfNeeded()
        prepareMessage(message)
        message.updateCategoryCache()
        message.prepareToSend()

        return message
    }


}

@objc 
extension ZMConversation {
    
    // MARK: - Objective-C compability methods
    
    @discardableResult @objc(appendMessageWithText:)
    public func _append(text: String) -> ZMConversationMessage? {
        return append(text: text)
    }
    
    @discardableResult @objc(appendMessageWithText:fetchLinkPreview:)
    public func _append(text: String, fetchLinkPreview: Bool) -> ZMConversationMessage? {
        return append(text: text, fetchLinkPreview: fetchLinkPreview)
    }

    @discardableResult @objc(appendText:mentions:fetchLinkPreview:nonce:)
    public func _append(text: String,
                        mentions: [Mention],
                        fetchLinkPreview: Bool,
                        nonce: UUID) -> ZMConversationMessage? {

        return append(text: text,
                      mentions: mentions,
                      fetchLinkPreview: fetchLinkPreview,
                      nonce: nonce)
    }

    @discardableResult @objc(appendText:mentions:replyingToMessage:fetchLinkPreview:nonce:)
    public func _append(text: String,
                        mentions: [Mention],
                        replyingTo quotedMessage: ZMConversationMessage?,
                        fetchLinkPreview: Bool,
                        nonce: UUID) -> ZMConversationMessage? {

        return append(text: text,
                      mentions: mentions,
                      replyingTo: quotedMessage,
                      fetchLinkPreview: fetchLinkPreview,
                      nonce: nonce)
    }
    
    @discardableResult @objc(appendKnock)
    public func _appendKnock() -> ZMConversationMessage? {
        return try? appendKnock()
    }
    
    @discardableResult @objc(appendMessageWithLocationData:)
    public func _append(location: LocationData) -> ZMConversationMessage? {
        return try? appendLocation(with: location)
    }
    
    @discardableResult @objc(appendMessageWithImageData:)
    public func _append(imageFromData imageData: Data) -> ZMConversationMessage? {
        return append(imageFromData: imageData)
    }

    @discardableResult @objc(appendImageFromData:nonce:)
    public func _append(imageFromData imageData: Data, nonce: UUID) -> ZMConversationMessage? {
        return append(imageFromData: imageData, nonce: nonce)
    }

    @discardableResult @objc(appendImageAtURL:nonce:)
    public func _append(imageAtURL URL: URL, nonce: UUID) -> ZMConversationMessage? {
        return append(imageAtURL: URL, nonce: nonce)
    }

    @discardableResult @objc(appendMessageWithFileMetadata:)
    public func _append(file fileMetadata: ZMFileMetadata) -> ZMConversationMessage? {
        return append(file: fileMetadata)
    }

    @discardableResult @objc(appendFile:nonce:)
    public func _append(file fileMetadata: ZMFileMetadata, nonce: UUID) -> ZMConversationMessage? {
        return append(file: fileMetadata, nonce: nonce)
    }

    // MARK: - Helper methods
    
    @nonobjc
    func append(message: MessageCapable, nonce: UUID = UUID(), hidden: Bool = false, expires: Bool = false) -> ZMClientMessage? {
        // TODO: [John] handle?
        return try? appendClientMessage(with: GenericMessage(content: message, nonce: nonce), expires: expires, hidden: hidden)
    }
    
}
