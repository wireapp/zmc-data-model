//
//  NSPersistentStore+Migration.swift
//  WireDataModel
//
//  Created by Marco Conti on 19.07.17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension NSPersistentStoreCoordinator {
    
    /// Creates a filesystem-based persistent store at the given url with the given model
    convenience init(
        localStoreAt url: URL,
        model: NSManagedObjectModel,
        startedMigrationCallback: @escaping (Void)->(Void)
        )
    {
        self.init(managedObjectModel: model)
        
        NSPersistentStoreCoordinator.createDirectoryForStore(at: url)
        
        let storeRelocator = PersistentStoreRelocator(storeLocation: url)
        try! storeRelocator.moveStoreIfNecessary()
        
        if NSPersistentStoreCoordinator.shouldMigrateStoreToNewModelVersion(at: url, model: model) {
            DispatchQueue.main.async {
                startedMigrationCallback()
            }
            self.migrateAndAddPersistentStore(url: url)
        } else {
            self.addPersistentStoreWithNoMigration(at: url)
        }
    }
    
    /// Creates an in memory persistent store coordinator with the given model
    convenience init(inMemoryWithModel model: NSManagedObjectModel) {
        self.init(managedObjectModel: model)
        do {
            try self.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: nil)
        } catch {
            fatal("Unable to create in-memory Core Data store: \(error)")
        }
    }
    
    /// Adds the persistent store
    fileprivate func addPersistentStoreWithNoMigration(at url: URL) {
        let options = NSPersistentStoreCoordinator.persistentStoreOptions(supportsMigration: false)
        do {
            try self.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: url,
                options: options)
        } catch {
            fatal("Can not create Core Data storage at \(url). \(error)")
        }
    }
}

extension NSPersistentStoreCoordinator {
    
    fileprivate static func createDirectoryForStore(at url: URL) {
        
        var directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            let permission = 0700
            let attributes = [FileAttributeKey.posixPermissions.rawValue: permission] as [String: Any]
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: attributes)
            } catch {
                fatal("Failed to create directory: \(error)")
            }
        }
        
        // Make sure this is not backed up and not accessible until first authentication
        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
        } catch {
            fatal("Can not exclude resource \(url) from backup: \(error)")
        }
    }
    
    /// Check if the store should be migrated (as opposed to discarded) based on model versions
    fileprivate static func shouldMigrateStoreToNewModelVersion(at url: URL, model: NSManagedObjectModel) -> Bool {
        
        if FileManager.default.fileExists(atPath: url.path) {
            // Store doesn't exist yet so need to migrate it.
            return false
        }
        
        let metadata = self.metadataForStore(at: url)
        guard let oldModelVersion = metadata.managedObjectModelVersionIdentifier else {
            return false // if we have no version, we better wipe
        }
        
        // this is used to avoid migrating internal builds when we update the DB internally between releases
        let isSameAsCurrent = model.firstVersionIdentifier == oldModelVersion
        guard !isSameAsCurrent else { return false }
        
        // Between non-E2EE and E2EE we should not migrate the DB for privacy reasons.
        // We know that the old mom is a version supporting E2EE when it
        // contains the 'ClientMessage' entity or is at least of version 1.25
        if metadata.managedObjectModelEntityNames.contains(ZMClientMessage.entityName()) {
            return true
        }
        
        let atLeastVersion1_25 = (oldModelVersion as NSString).compare("1.25", options: .numeric) != .orderedAscending
        
        // Unfortunately the 1.24 Release has a mom version of 1.3 but we do not want to migrate from it
        return atLeastVersion1_25 && oldModelVersion != "1.3"
    }
    
    
    /// Retrieves the metadata for the store
    fileprivate static func metadataForStore(at url: URL) -> [String: Any] {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url) else {
            return [:]
        }
        return metadata
    }
    
    /// Performs a migration, crashes if failed
    fileprivate func migrateAndAddPersistentStore(url: URL) {
        
        let metadata = NSPersistentStoreCoordinator.metadataForStore(at: url)
        let options = NSPersistentStoreCoordinator.persistentStoreOptions(supportsMigration: true)
        guard let _ = try? self.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: options) else
        {
            let oldModelVersion = metadata.managedObjectModelVersionIdentifier ?? "n/a"
            let currentModelVersion = self.managedObjectModel.firstVersionIdentifier
            fatal("Unable to perform migration and create SQLite Core Data store." +
                "Old model version: \(oldModelVersion), current version \(currentModelVersion)"
            )
        }
    }
 
    /// Returns the set of options that need to be passed to the persistent sotre
    fileprivate static func persistentStoreOptions(supportsMigration: Bool) -> [String: Any] {
        return [
            // https://www.sqlite.org/pragma.html
            NSSQLitePragmasOption: [
                "journal_mode" : "WAL",
                "synchronous": "FULL"
            ],
            NSMigratePersistentStoresAutomaticallyOption: supportsMigration,
            NSInferMappingModelAutomaticallyOption: supportsMigration
        ]
    }
}

extension Dictionary where Key == String {
    
    fileprivate var managedObjectModelVersionIdentifier: String? {
        return (self[NSStoreModelVersionIdentifiersKey] as? [String])?.first
    }
    
    fileprivate var managedObjectModelEntityNames: Set<String> {
        return Set(((self[NSStoreModelVersionHashesKey] as? [String: Any]) ?? [:]).keys)
    }
}

extension NSManagedObjectModel {
    
    fileprivate var firstVersionIdentifier: String {
        return self.versionIdentifiers.first! as! String
    }
}
