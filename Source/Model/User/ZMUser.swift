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

@objc public enum ProfileImageSize: Int {
    case preview
    case complete
    
    public var imageFormat: ZMImageFormat {
        switch self {
        case .preview:
            return .medium
        case .complete:
            return .profile
        }
    }
    
    public static var allSizes: [ProfileImageSize] {
        return [.preview, .complete]
    }
    
    internal var userKeyPath: String {
        switch self {
        case .preview:
            return #keyPath(ZMUser.imageSmallProfileData)
        case .complete:
            return #keyPath(ZMUser.imageMediumData)
        }
    }
}


extension ZMUser {
    static let previewProfileAssetIdentifierKey = #keyPath(ZMUser.previewProfileAssetIdentifier)
    static let completeProfileAssetIdentifierKey = #keyPath(ZMUser.completeProfileAssetIdentifier)
    
    @NSManaged public var previewProfileAssetIdentifier: String?
    @NSManaged public var completeProfileAssetIdentifier: String?
    
    public static var previewImageDownloadFilter: NSPredicate {
        let assetIdExists = NSPredicate(format: "(%K != nil)", ZMUser.previewProfileAssetIdentifierKey)
        let notCached = NSPredicate() { (user, _) -> Bool in
            guard let user = user as? ZMUser else { return false }
            return user.imageSmallProfileData == nil
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [assetIdExists, notCached])
    }
    
    public static var completeImageDownloadFilter: NSPredicate {
        let assetIdExists = NSPredicate(format: "(%K != nil)", ZMUser.completeProfileAssetIdentifierKey)
        let notCached = NSPredicate() { (user, _) -> Bool in
            guard let user = user as? ZMUser else { return false }
            return user.imageMediumData == nil
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [assetIdExists, notCached])
    }
    
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
                    if key != previewProfileAssetIdentifier {
                        previewProfileAssetIdentifier = key
                        imageSmallProfileData = nil
                    }
                case "complete":
                    if key != completeProfileAssetIdentifier {
                        completeProfileAssetIdentifier = key
                        imageMediumData = nil
                    }
                default:
                    break
                }
            }
        }
    }
}
