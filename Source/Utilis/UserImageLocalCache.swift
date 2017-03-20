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
import PINCache
import ZMTransport

private let MEGABYTE = UInt(1 * 1000 * 1000)

// MARK: ZMUser
extension ZMUser {
    
    private func cacheIdentifier(suffix: String?) -> String? {
        guard let userRemoteId = remoteIdentifier?.transportString(), let suffix = suffix else { return nil }
        return (userRemoteId + "-" + suffix)
    }
    
    /// The identifier to use for the large profile image
    fileprivate var legacyLargeImageCacheKey : String? {
        return cacheIdentifier(suffix: mediumRemoteIdentifier?.transportString())
    }
    
    /// The identifier to use for the small profile image
    fileprivate var legacySmallImageCacheKey : String? {
        return cacheIdentifier(suffix: smallProfileRemoteIdentifier?.transportString())
    }
    
    /// The identifier to use for the preview profile image stored as AssetV3
    fileprivate var previewImageAssetCacheKey: String? {
        return cacheIdentifier(suffix: previewProfileAssetIdentifier)
    }
    
    /// The identifier to use for the complete profile image stored as AssetV3
    fileprivate var completeImageAssetCacheKey: String? {
        return cacheIdentifier(suffix: completeProfileAssetIdentifier)
    }
    
    /// Cache keys for all large user images
    fileprivate var largeCacheKeys: [String] {
        return [legacyLargeImageCacheKey, completeImageAssetCacheKey].flatMap{ $0 }
    }
    
    /// Cache keys for all small user images
    fileprivate var smallCacheKeys: [String] {
        return [legacySmallImageCacheKey, previewImageAssetCacheKey].flatMap{ $0 }
    }
}

// MARK: NSManagedObjectContext

let NSManagedObjectContextUserImageCacheKey = "zm_userImageCacheKey"

extension NSManagedObjectContext
{
    public var zm_userImageCache : UserImageLocalCache! {
        get {
            return self.userInfo[NSManagedObjectContextUserImageCacheKey] as? UserImageLocalCache
        }
        
        set {
            self.userInfo[NSManagedObjectContextUserImageCacheKey] = newValue
        }
    }
}

// MARK: Cache
@objc open class UserImageLocalCache : NSObject {
    
    /// Cache for large user profile image
    fileprivate let largeUserImageCache : PINCache
    
    /// Cache for small user profile image
    fileprivate let smallUserImageCache : PINCache
    
    
    /// Create UserImageLocalCache
    /// - parameter location: where cache is persisted on disk. Defaults to caches directory if nil.
    public init(location: URL? = nil) {
        
        let largeUserImageCacheName = "largeUserImages"
        let smallUserImageCacheName = "smallUserImages"
        
        if let rootPath = location?.path {
            largeUserImageCache = PINCache(name: largeUserImageCacheName, rootPath: rootPath)
            smallUserImageCache = PINCache(name: smallUserImageCacheName, rootPath: rootPath)
        } else {
            largeUserImageCache = PINCache(name: largeUserImageCacheName)
            smallUserImageCache = PINCache(name: smallUserImageCacheName)
        }
        
        largeUserImageCache.configureLimits(50 * MEGABYTE)
        smallUserImageCache.configureLimits(25 * MEGABYTE)
        
        largeUserImageCache.makeURLSecure()
        smallUserImageCache.makeURLSecure()
        super.init()
    }
    
    /// Stores image in cache and removes legacy copy if it was there, returns true is the data was stored
    private func setImage(inCache cache: PINCache, legacyCacheKey: String?, cacheKey: String?, data: Data) -> Bool {
        let resolvedCacheKey: String?
        if let cacheKey = cacheKey {
            resolvedCacheKey = cacheKey
            if let legacyCacheKey = legacyCacheKey {
                cache.removeObject(forKey: legacyCacheKey)
            }
        } else {
            resolvedCacheKey = legacyCacheKey
        }
        if let resolvedCacheKey = resolvedCacheKey {
            cache.setObject(data as NSCoding, forKey: resolvedCacheKey)
            return true
        }
        return false
    }
    
    /// Removes all images for user
    open func removeAllUserImages(_ user: ZMUser) {
        user.largeCacheKeys.forEach(largeUserImageCache.removeObject)
        user.smallCacheKeys.forEach(smallUserImageCache.removeObject)
    }
    
    /// Large image for user
    open func largeUserImage(_ user: ZMUser) -> Data? {
        let cacheKey = user.completeImageAssetCacheKey ?? user.legacyLargeImageCacheKey
        guard let largeCacheKey = cacheKey else { return nil }
        return largeUserImageCache.object(forKey: largeCacheKey) as? Data
    }
    
    /// Sets the large user image for a user
    open func setLargeUserImage(_ user: ZMUser, imageData: Data) {
        let stored = setImage(inCache: largeUserImageCache, legacyCacheKey: user.legacyLargeImageCacheKey, cacheKey: user.completeImageAssetCacheKey, data: imageData)
        if stored {
            usersWithChangedLargeImage.append(user.objectID)
        }
    }
    
    /// Small image for user
    open func smallUserImage(_ user: ZMUser) -> Data? {
        let cacheKey = user.previewImageAssetCacheKey ?? user.legacySmallImageCacheKey
        guard let smallCacheKey = cacheKey else { return nil }
        return smallUserImageCache.object(forKey: smallCacheKey) as? Data
    }
    
    /// Sets the small user image for a user
    open func setSmallUserImage(_ user: ZMUser, imageData: Data) {
        let stored = setImage(inCache: smallUserImageCache, legacyCacheKey: user.legacySmallImageCacheKey, cacheKey: user.previewImageAssetCacheKey, data: imageData)
        if stored {
            usersWithChangedSmallImage.append(user.objectID)
        }
    }
    
    var usersWithChangedSmallImage : [NSManagedObjectID] = []
    var usersWithChangedLargeImage : [NSManagedObjectID] = []

}

public extension UserImageLocalCache {
    func wipeCache() {
        smallUserImageCache.removeAllObjects()
        largeUserImageCache.removeAllObjects()
    }
}
