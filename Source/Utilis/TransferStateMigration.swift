//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

struct TransferStateMigration {
    
    internal enum LegacyTransferState: Int, CaseIterable {
        case uploading = 0
        case uploaded
        case downloading
        case downloaded
        case failedUpload
        case cancelledUpload
        case failedDownloaded
        case unavailable
                
        static var migrationMappings: [(AssetTransferState, [LegacyTransferState])] = [
            (.uploaded, [.downloading, .downloaded, .failedDownloaded, .unavailable]),
            (.uploadingFailed, [.failedUpload]),
            (.uploadingCancelled, [.cancelledUpload]),
        ]
    }
    
    /// When we simplified our asset uploading we replaced ZMFileTransferState with AssetTransferState, which
    /// only contains a subset  of the original cases. This method will fetch and migrate all asset messages
    /// which doesn't have a valid tranferState any more.
    static func migrateLegacyTransferState(in moc: NSManagedObjectContext) {
        
        let transferStateKey = "transferState"
        
        for (newValue, legacyValues) in LegacyTransferState.migrationMappings {
            let batchUpdateRequest = NSBatchUpdateRequest(entityName: ZMAssetClientMessage.entityName())
            batchUpdateRequest.predicate = NSPredicate(format: "\(transferStateKey) IN %@", legacyValues.map(\.rawValue))
            batchUpdateRequest.propertiesToUpdate = [transferStateKey: newValue.rawValue]
            batchUpdateRequest.resultType = .updatedObjectsCountResultType
            
            do {
                try moc.execute(batchUpdateRequest)
            } catch {
                fatalError("Failed to perform batch update: \(error)")
            }
        }
    }
}
