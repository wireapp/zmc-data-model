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

extension ZMUser {
    static let previewProfileAssetIdentifierKey = #keyPath(ZMUser.previewProfileAssetIdentifier)
    static let completeProfileAssetIdentifierKey = #keyPath(ZMUser.completeProfileAssetIdentifier)
    
    @NSManaged public var previewProfileAssetIdentifier: String?
    @NSManaged public var completeProfileAssetIdentifier: String?
    
    public func updateAndSyncProfileAssetIdentifiers(previewIdentifier: String, completeIdentifier: String) {
        guard isSelfUser else { return }
        previewProfileAssetIdentifier = previewIdentifier
        completeProfileAssetIdentifier = completeIdentifier
        setLocallyModifiedKeys([ZMUser.previewProfileAssetIdentifierKey, ZMUser.completeProfileAssetIdentifierKey])
    }
    
    @objc public func updateAssetData(with assets: NSArray?, authoritative: Bool) {
        guard !hasLocalModifications(forKeys: [ZMUser.previewProfileAssetIdentifierKey, ZMUser.completeProfileAssetIdentifierKey]) else { return }
        guard let assets = assets as? [[String : String]] else {
            if authoritative {
                previewProfileAssetIdentifier = nil
                imageSmallProfileData = nil
                completeProfileAssetIdentifier = nil
                imageMediumData = nil
            }
            return
        }
        for data in assets {
            if let size = data["size"], let key = data["key"] {
                switch size {
                case "preview":
                    previewProfileAssetIdentifier = key
                    imageSmallProfileData = nil
                case "complete":
                    completeProfileAssetIdentifier = key
                    imageMediumData = nil
                default:
                    break
                }
            }
        }
    }
}
