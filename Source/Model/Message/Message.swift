//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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


/// The `ZMConversationMessage` protocol can not be extended in Objective-C,
/// thus this helper class provides access to comonly used properties.
public class Message: NSObject {

    /// Returns YES, if the message has text to display.
    /// This also includes linkPreviews or links to soundcloud, youtube or vimeo
    @objc(isTextMessage:)
    public class func isText(_ message: ZMConversationMessage) -> Bool {
        return message.textMessageData != nil
    }

    @objc(isImageMessage:)
    public class func isImage(_ message: ZMConversationMessage) -> Bool {
        return message.imageMessageData != nil ||
        (message.fileMessageData != nil && message.fileMessageData!.v3_isImage() == true)
    }

    @objc(isKnockMessage:)
    public class func isKnock(_ message: ZMConversationMessage) -> Bool {
        return message.knockMessageData != nil
    }

    /// Returns YES, if the message is a file transfer message
    /// This also includes audio messages and video messages
    @objc(isFileTransferMessage:)
    public class func isFileTransfer(_ message: ZMConversationMessage) -> Bool {
        return message.fileMessageData != nil && !message.fileMessageData!.v3_isImage()
    }

    @objc(isVideoMessage:)
    public class func isVideo(_ message: ZMConversationMessage) -> Bool {
        return isFileTransfer(message) && message.fileMessageData!.isVideo()
    }

    @objc(isAudioMessage:)
    public class func isAudio(_ message: ZMConversationMessage) -> Bool {
        return isFileTransfer(message) && message.fileMessageData!.isAudio()
    }

    @objc(isLocationMessage:)
    public class func isLocation(_ message: ZMConversationMessage) -> Bool {
        return message.locationMessageData != nil
    }

    @objc(isSystemMessage:)
    public class func isSystem(_ message: ZMConversationMessage) -> Bool {
        return message.systemMessageData != nil
    }

    @objc(isNormalMessage:)
    public class func isNormal(_ message: ZMConversationMessage) -> Bool {
        return isText(message)
        || isImage(message)
        || isKnock(message)
        || isFileTransfer(message)
        || isVideo(message)
        || isAudio(message)
        || isLocation(message)
    }

    @objc(isConnectionRequestMessage:)
    public class func isConnectionRequest(_ message: ZMConversationMessage) -> Bool {
        guard isSystem(message) else { return false }
        return message.systemMessageData!.systemMessageType == .connectionRequest
    }

    @objc(isMissedCallMessage:)
    public class func isMissedCall(_ message: ZMConversationMessage) -> Bool {
        guard isSystem(message) else { return false }
        return message.systemMessageData!.systemMessageType == .missedCall
    }

    @objc(isDeletedMessage:)
    public class func isDeleted(_ message: ZMConversationMessage) -> Bool {
        guard isSystem(message) else { return false }
        return message.systemMessageData!.systemMessageType == .messageDeletedForEveryone
    }

}
