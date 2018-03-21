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

public extension Notification.Name {
    /// Notification to be fired when a (v3) asset should be deleted,
    /// which is only possible to be done by the original uploader of the asset.
    /// When firing this notification the asset id has to be included as object in the notification.
    static let deleteAssetNotification = Notification.Name("deleteAssetNotification")
}

extension ZMAssetClientMessage {

    func deleteContent() {
        self.managedObjectContext?.zm_fileAssetCache.deleteAssetData(self)
        self.dataSet = NSOrderedSet()
        self.cachedGenericAssetMessage = nil
        self.assetId = nil
        self.associatedTaskIdentifier = nil
        self.preprocessedSize = CGSize.zero
    }
    
    override public func removeClearingSender(_ clearingSender: Bool) {
        if !clearingSender {
            markRemoteAssetToBeDeleted()
        }
        deleteContent()
        super.removeClearingSender(clearingSender)
    }
    
    private func markRemoteAssetToBeDeleted() {
        guard sender == ZMUser.selfUser(in: managedObjectContext!) else { return }
        
        // Request the asset to be deleted
        if let identifier = assetId?.transportString() {
            NotificationCenter.default.post(name: .deleteAssetNotification, object: identifier)
        }
        
        // Request the preview asset to be deleted
        if let previewIdentifier = genericAssetMessage?.previewAssetId {
            NotificationCenter.default.post(name: .deleteAssetNotification, object: previewIdentifier)
        }
    }
}
