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
        case unvailable
        
        static var casesRequiringMigration: [LegacyTransferState] {
            return LegacyTransferState.allCases.filter({ $0 != .uploading && $0 != .uploaded})
        }
        
        func migrate() -> AssetTransferState {
            switch self {
            case .uploading: return .uploading
            case .uploaded, .downloading, .downloaded, .failedDownloaded, .unvailable: return .uploaded
            case .failedUpload: return .uploadingFailed
            case .cancelledUpload: return .uploadingCancelled
            }
        }
    }
    
    /// When we simplified our asset uploading we replaced ZMFileTransferState with AssetTransferState, which
    /// only contains a subset  of the original cases. This method will fetch and migrate all asset messages
    /// which doesn't have a valid tranferState any more.
    static func migrateLegacyTransferState(in moc: NSManagedObjectContext) {
        
        let transferStateKey = "transferState"
        let fetchRequest = NSFetchRequest<ZMAssetClientMessage>(entityName: ZMAssetClientMessage.entityName())
        fetchRequest.predicate = NSPredicate(format: "\(transferStateKey) IN %@", LegacyTransferState.casesRequiringMigration.map(\.rawValue))
        
        let assetMessages = moc.fetchOrAssert(request: fetchRequest)
        
        for assetMessage in assetMessages {
            guard let rawLegacyTransferState = assetMessage.primitiveValue(forKey: transferStateKey) as? Int,
                  let legacyTransferState = LegacyTransferState(rawValue: rawLegacyTransferState)
            else { continue }
            
            assetMessage.transferState = legacyTransferState.migrate()
        }
    }
}
