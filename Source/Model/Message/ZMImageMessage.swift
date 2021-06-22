//
//  ZMImageMessage.swift
//  WireDataModel
//
//  Created by Bill, Yiu Por Chan on 28.05.21.
//  Copyright © 2021 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMImageMessage {
    /// Request the download of the image if not already present.
    /// The download will be executed asynchronously. The caller can be notified by observing the message window.
    /// This method can safely be called multiple times, even if the content is already available locally
    public func requestFileDownload() {
        // V2

        // objects with temp ID on the UI must just have been inserted so no need to download
        if objectID.isTemporaryID {
            return
        }

        if let moc = managedObjectContext?.zm_userInterface {
            let note = NotificationInContext(
                name: ZMAssetClientMessage.imageDownloadNotificationName,
                context: moc.notificationContext,
                object: objectID,
                userInfo: nil)
            note.post()
        }
    }
}
