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

private let NSManagedObjectContextFileAssetCacheKey = "zm_fileAssetCache"
private var zmLog = ZMSLog(tag: "assets")


extension NSManagedObjectContext
{
    public var zm_fileAssetCache : FileAssetCache {
        get {
            return self.userInfo[NSManagedObjectContextFileAssetCacheKey] as! FileAssetCache
        }
        
        set {
            self.userInfo[NSManagedObjectContextFileAssetCacheKey] = newValue
        }
    }
}

/// A file cache
/// This class is NOT thread safe. However, the only problematic operation is deleting.
/// Any thread can read objects that are never deleted without any problem.
/// Objects purged from the cache folder by the OS are not a problem as the
/// OS will terminate the app before purging the cache.
private struct FileCache : Cache {
    
    private let cacheFolderURL : URL
    
    /// Create FileCahe
    /// - parameter name: name of the cache
    /// - parameter location: where cache is persisted on disk. Defaults to caches directory if nil.
    init(name: String, location: URL? = nil) {
        
        // Create cache at the provided location or in the defalt caches directory if omitted
        if let cacheFolderURL = location {
            self.cacheFolderURL = cacheFolderURL
        } else if let cacheFolderURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            self.cacheFolderURL = cacheFolderURL
        } else {
            fatal("Can't find/access caches directory")
        }
        
        // create and set attributes
        FileManager.default.createAndProtectDirectory(at: cacheFolderURL)
    }
    
    func assetData(_ key: String) -> Data? {
        let url = URLForKey(key)
        let data: Data?
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        }
        catch let error as NSError {
            if error.code != NSFileReadNoSuchFileError {
                zmLog.error("\(error)")
            }
            data = nil
        }
        return data
    }
    
    func storeAssetData(_ data: Data, key: String) {
        let url = URLForKey(key)
        FileManager.default.createFile(atPath: url.path, contents: data, attributes: [FileAttributeKey.protectionKey.rawValue : FileProtectionType.completeUntilFirstUserAuthentication])
        do {
            try (url as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        } catch {
            _ = try? FileManager.default.removeItem(at: url)
            fatal("Failed to exclude file from backup \(url) \(error)")
        }
    }
    
    func storeAssetFromURL(_ url: URL, key: String) {
        guard url.scheme == NSURLFileScheme else { fatal("Can't save remote URL to cache: \(url)") }
        let finalURL = URLForKey(key)
        do {
            try FileManager.default.copyItem(at: url, to: finalURL)
            try FileManager.default.setAttributes([FileAttributeKey.protectionKey : FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: finalURL.path)
            try (finalURL as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        } catch {
            _ = try? FileManager.default.removeItem(at: finalURL)
            fatal("Failed to copy from \(url) to \(finalURL), \(error)")
        }
        
    }
    
    func deleteAssetData(_ key: String) {
        let url = URLForKey(key)
        do {
            try FileManager.default.removeItem(at: url)
        }
        catch let error as NSError {
            if error.domain != NSCocoaErrorDomain || error.code != NSFileNoSuchFileError {
                zmLog.error("Can't delete file \(url.pathComponents.last!): \(error)")
            }
        }
    }
    
    func assetURL(_ key: String) -> URL? {
        let url = URLForKey(key)
        let isReachable = (try? url.checkResourceIsReachable()) ?? false
        return isReachable ? url : nil
    }
    
    func hasDataForKey(_ key: String) -> Bool {
        return assetURL(key) != nil
    }
    
    /// Returns the expected URL of a cache entry
    fileprivate func URLForKey(_ key: String) -> URL {
        guard key != "." && key != ".." else { fatal("Can't use \(key) as cache key") }
        var safeKey = key
        for c in ":\\/%\"".characters { // see https://en.wikipedia.org/wiki/Filename#Reserved_characters_and_words
            safeKey = safeKey.replacingOccurrences(of: "\(c)", with: "_")
        }
        return cacheFolderURL.appendingPathComponent(safeKey)
    }

    /// Deletes all existing caches. After calling this method, existing caches should not be used anymore.
    /// This is intended for testing
    func wipeCaches() {
        _ = try? FileManager.default.removeItem(at: cacheFolderURL)
    }
}

// MARK: - File asset cache
/// A file cache
/// This class is NOT thread safe. However, the only problematic operation is deleting.
/// Any thread can read objects that are never deleted without any problem.
/// Objects purged from the cache folder by the OS are not a problem as the
/// OS will terminate the app before purging the cache.
open class FileAssetCache : NSObject {
    
    fileprivate let fileCache : FileCache
    
    var cache : Cache {
        return fileCache
    }
    
    /// Creates an asset cache
    public init(location: URL? = nil) {
        self.fileCache = FileCache(name: "files", location: location)
        
        super.init()
    }
    
    /// Returns the image asset data for a given message. This will probably cause I/O
    open func assetData(_ message : ZMConversationMessage, format: ZMImageFormat, encrypted: Bool) -> Data? {
        guard let key = type(of: self).cacheKeyForAsset(message, format: format, encrypted: encrypted) else { return nil }
        return self.cache.assetData(key)
    }
    
    /// Returns the asset data for a given message. This will probably cause I/O
    open func assetData(_ message : ZMConversationMessage, encrypted: Bool) -> Data? {
        guard let key = type(of: self).cacheKeyForAsset(message, encrypted: encrypted) else { return nil }
        return self.cache.assetData(key)
    }
    
    /// Returns the asset URL for a given message
    open func accessAssetURL(_ message : ZMConversationMessage) -> URL? {
        guard let key = type(of: self).cacheKeyForAsset(message) else { return nil }
        return self.cache.assetURL(key)
    }
    
    /// Returns the asset URL for a given message
    open func accessRequestURL(_ message : ZMConversationMessage) -> URL? {
        guard let key = type(of: self).cacheKeyForAsset(message, identifier: "request") else { return nil }
        return cache.assetURL(key)
    }
    
    open func hasDataOnDisk(_ message : ZMConversationMessage, format: ZMImageFormat, encrypted: Bool) -> Bool {
        guard let key = type(of: self).cacheKeyForAsset(message, format: format, encrypted: encrypted) else { return false }
        return cache.hasDataForKey(key)
    }
    
    open func hasDataOnDisk(_ message : ZMConversationMessage, encrypted: Bool) -> Bool {
        guard let key = type(of: self).cacheKeyForAsset(message, encrypted: encrypted) else { return false }
        return cache.hasDataForKey(key)
    }
    
    /// Sets the image asset data for a given message. This will cause I/O
    open func storeAssetData(_ message : ZMConversationMessage, format: ZMImageFormat, encrypted: Bool, data: Data) {
        guard let key = type(of: self).cacheKeyForAsset(message, format: format, encrypted: encrypted) else { return }
        self.cache.storeAssetData(data, key: key)
    }
    
    /// Sets the asset data for a given message. This will cause I/O
    open func storeAssetData(_ message : ZMConversationMessage, encrypted: Bool, data: Data) {
        guard let key = type(of: self).cacheKeyForAsset(message, encrypted: encrypted) else { return }
        self.cache.storeAssetData(data, key: key)
    }
    
    /// Sets the request data for a given message and returns the asset url. This will cause I/O
    open func storeRequestData(_ message : ZMConversationMessage, data: Data) -> URL? {
        guard let key = type(of: self).cacheKeyForAsset(message, identifier: "request") else { return nil }
        cache.storeAssetData(data, key: key)
        return accessRequestURL(message)
    }
    
    /// Deletes the request data for a given message. This will cause I/O
    open func deleteRequestData(_ message : ZMConversationMessage) {
        guard let key = type(of: self).cacheKeyForAsset(message, identifier: "request") else { return }
        cache.deleteAssetData(key)
    }
    
    /// Deletes the image data for a given message. This will cause I/O
    open func deleteAssetData(_ message : ZMConversationMessage, format: ZMImageFormat, encrypted: Bool) {
        guard let key = type(of: self).cacheKeyForAsset(message, format: format, encrypted: encrypted) else { return }
        cache.deleteAssetData(key)
    }
    
    /// Deletes the data for a given message. This will cause I/O
    open func deleteAssetData(_ message : ZMConversationMessage, identifier: String? = nil, encrypted: Bool) {
        guard let key = type(of: self).cacheKeyForAsset(message, identifier: identifier, encrypted: encrypted) else { return }
        self.cache.deleteAssetData(key)
    }
    
    /// Deletes all associated data for a given message. This will cause I/O
    open func deleteAssetData(_ message : ZMConversationMessage) {
        
        if message.imageMessageData != nil {
            let imageFormats : [ZMImageFormat] = [.medium, .original, .preview]
            
            imageFormats.forEach({ format in
                deleteAssetData(message, format: format, encrypted: false)
                deleteAssetData(message, format: format, encrypted: true)
            })
        }
        
        if message.fileMessageData != nil {
            deleteAssetData(message, encrypted: false)
            deleteAssetData(message, encrypted: true)
        }
    }
    
    static func cacheKeyForAsset(_ message : ZMConversationMessage, format: ZMImageFormat, encrypted: Bool = false) -> String? {
        return cacheKeyForAsset(message, identifier: StringFromImageFormat(format), encrypted: encrypted)
    }
    
    static func cacheKeyForAsset(_ message : ZMConversationMessage, identifier: String? = nil, encrypted: Bool = false) -> String? {
        guard let messageId = message.nonce?.transportString(),
              let senderId = message.sender?.remoteIdentifier?.transportString(),
              let conversationId = message.conversation?.remoteIdentifier?.transportString()
        else {
            return nil
        }
    
        var key = "\(messageId)_\(senderId)_\(conversationId)"
        
        if let identifier = identifier {
            key = "\(key)_\(identifier)"
        }
            
        if (encrypted) {
            key = "\(key).encrypted"
        }
        
        return key
    }
    
}

// MARK: - Testing
public extension FileAssetCache {
    /// Deletes all existing caches. After calling this method, existing caches should not be used anymore.
    /// This is intended for testing
    func wipeCaches() {
        fileCache.wipeCaches()
    }
}

