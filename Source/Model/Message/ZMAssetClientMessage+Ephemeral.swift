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
 
    override public var isEphemeral: Bool {
        return self.destructionDate != nil || self.ephemeral != nil || self.isObfuscated
    }
    
    var ephemeral: ZMEphemeral? {
        let first = self.dataSet.array
            .flatMap { ($0 as? ZMGenericMessageData)?.genericMessage }
            .filter { $0.hasEphemeral() }
            .first
        return first?.ephemeral
    }
    
    override public var deletionTimeout: TimeInterval {
        if let ephemeral = self.ephemeral {
            return TimeInterval(ephemeral.expireAfterMillis / 1000)
        }
        return -1
    }
    
    override public func obfuscate() {
        super.obfuscate()
        
        var obfuscatedMessage: ZMGenericMessage? = nil
        if let medium = self.mediumGenericMessage {
            obfuscatedMessage = medium.obfuscatedMessage()
        } else if self.fileMessageData != nil {
            obfuscatedMessage = self.genericAssetMessage?.obfuscatedMessage()
        }
        
        self.deleteContent()
        
        if let obfuscatedMessage = obfuscatedMessage {
            _ = self.createNewGenericMessage(with: obfuscatedMessage.data())
        }
    }
}
//
//- (BOOL)startDestructionIfNeeded
//{
//    BOOL isSelfUser = self.sender.isSelfUser;
//
//    if (!isSelfUser) {
//        if (nil != self.imageMessageData && !self.hasDownloadedImage) {
//            return NO;
//        } else if (nil != self.fileMessageData) {
//            if (!self.genericAssetMessage.assetData.hasUploaded &&
//                !self.genericAssetMessage.assetData.hasNotUploaded)
//            {
//                return NO;
//            }
//        }
//    }
//    // This method is called after receiving the response but before updating the
//    // uploadState, which means a state of fullAsset corresponds to the asset upload being done.
//    if (isSelfUser && self.uploadState != ZMAssetUploadStateUploadingFullAsset) {
//        return NO;
//    }
//    return [super startDestructionIfNeeded];
//}
//
//@end
