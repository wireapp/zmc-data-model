//
//  ZMImageMessage.swift
//  WireDataModel
//
//  Created by Bill, Yiu Por Chan on 28.05.21.
//  Copyright © 2021 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMImageMessage {
    public func requestFileDownload() {
        // V2

        // objects with temp ID on the UI must just have been inserted so no need to download
        if objectID.isTemporaryID {
            return
        }

        let moc = managedObjectContext?.zm_userInterface

        if let moc = moc {
            let note = NotificationInContext(
                name: ZMAssetClientMessage.imageDownloadNotificationName,
                context: moc.notificationContext,
                object: objectID,
                userInfo: nil)
            note.post()
        }
    }
}
