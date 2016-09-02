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

extension ZMAssetClientMessage {
    
    /// Returns the binary data of the encrypted `Asset.Uploaded` protobuf message or `nil`
    /// in case the receiver does not contain a `Asset.Uploaded` generic message.
    /// Also returns `nil` for messages representing an image
    public func encryptedMessagePayloadForDataType(dataType: ZMAssetClientMessageDataType) -> NSData? {
        
        guard let managedObjectContext = self.managedObjectContext,
            let selfClient = ZMUser.selfUserInContext(managedObjectContext).selfClient() where
            selfClient.remoteIdentifier != nil && imageAssetStorage != nil
            else {
                return nil
        }
        guard let conversation = self.conversation else { return nil }
        guard let genericMessage = self.genericMessageForDataType(dataType) else { return nil }
        
        var recipients : [ZMUserEntry] = []
        selfClient.keysStore.encryptionContext.perform { (sessionsDirectory) in
            recipients = genericMessage.recipientsWithEncryptedData(selfClient, recipients: conversation.activeParticipants.array as! [ZMUser], sessionDirectory: sessionsDirectory)
        }
        
        if dataType == .FullAsset || dataType == .Thumbnail {
            return ZMOtrAssetMeta.otrAssetMeta(withSender: selfClient, nativePush: true, inline: false, recipients: recipients).data()
        } else if dataType == .Placeholder {
            return ZMNewOtrMessage.message(withSender: selfClient, nativePush: true, recipients: recipients, blob: nil).data()
        }
        
        return nil
    }
    
    /// Returns the OTR asset meta for the image format
    public func encryptedMessagePayloadForImageFormat(imageFormat: ZMImageFormat) -> ZMOtrAssetMeta? {
        
        guard let managedObjectContext = self.managedObjectContext,
            let imageAssetStorage = self.imageAssetStorage,
            let selfClient = ZMUser.selfUserInContext(managedObjectContext).selfClient() where
            selfClient.remoteIdentifier != nil
        else {
            return nil
        }
        
        guard let conversation = self.conversation else { return nil }
        
        let builder = ZMOtrAssetMeta.builder()
        builder.setIsInline(imageAssetStorage.isInlineForFormat(imageFormat))
        builder.setNativePush(imageAssetStorage.isUsingNativePushForFormat(imageFormat))
        builder.setSender(selfClient.clientId)
        
        guard let genericMessage = imageAssetStorage.genericMessageForFormat(imageFormat) else {
            return nil
        }
        
        var recipients : [ZMUserEntry] = []
        selfClient.keysStore.encryptionContext.perform { (sessionsDirectory) in
            recipients = genericMessage.recipientsWithEncryptedData(selfClient, recipients: conversation.activeParticipants.array as! [ZMUser], sessionDirectory: sessionsDirectory)
        }
        
        builder.setRecipientsArray(recipients)
        return builder.build()
    }
}

