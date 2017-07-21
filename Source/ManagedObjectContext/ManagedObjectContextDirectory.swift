//
//  ManagedObjectContextDirectory.swift
//  WireDataModel
//
//  Created by Marco Conti on 19.07.17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation

/// List of context
public class ManagedObjectContextDirectory {
    
    init(persistentStoreCoordinator: NSPersistentStoreCoordinator, keyStore: URL) {
        self.uiContext = ManagedObjectContextDirectory.createUIManagedObjectContext(persistentStoreCoordinator: persistentStoreCoordinator)
        self.syncContext = ManagedObjectContextDirectory.createSyncManagedObjectContext(persistentStoreCoordinator: persistentStoreCoordinator, keyStore: keyStore)
        self.searchContext = ManagedObjectContextDirectory.createSearchManagedObjectContext(persistentStoreCoordinator: persistentStoreCoordinator)
    }
    
    /// User interface context. It can be used only from the main queue
    public let uiContext: NSManagedObjectContext
    
    /// Local storage and network synchronization context. It can be used only from its private queue.
    /// This context track changes to its objects and synchronizes them from/to the backend.
    public let syncContext: NSManagedObjectContext
    
    /// Search context. It can be used only from its private queue.
    /// This context is used to perform searches, not to slow down or insert temporary results in the
    /// sync context.
    public let searchContext: NSManagedObjectContext
    
    deinit {
        self.uiContext.tearDown()
        self.syncContext.tearDown()
        self.searchContext.tearDown()
    }
}

extension ManagedObjectContextDirectory {
    
    fileprivate static func createUIManagedObjectContext(
        persistentStoreCoordinator: NSPersistentStoreCoordinator) -> NSManagedObjectContext {
        
        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.performAndWait {
            moc.markAsUIContext()
            moc.configure(with: persistentStoreCoordinator)
            ZMUser.selfUser(in: moc)
        }
        moc.mergePolicy = ZMSyncMergePolicy(merge: .rollbackMergePolicyType)
        return moc
    }
    
    fileprivate static func createSyncManagedObjectContext(
        persistentStoreCoordinator: NSPersistentStoreCoordinator, keyStore: URL) -> NSManagedObjectContext {
        
        let moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        moc.markAsSyncContext()
        moc.performAndWait {
            moc.configure(with: persistentStoreCoordinator)
            moc.setupLocalCachedSessionAndSelfUser()
            moc.setupUserKeyStore(for: keyStore)
            moc.undoManager = nil
            moc.mergePolicy = ZMSyncMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            
        }
        
        // this will be done async, not to block the UI thread, but
        // enqueued on the syncMOC anyway, so it will execute before
        // any other block of code has a chance to use it
        moc.performGroupedBlock {
            moc.applyPersistedDataPatchesForCurrentVersion()
        }
        return moc
    }
 
    fileprivate static func createSearchManagedObjectContext(
        persistentStoreCoordinator: NSPersistentStoreCoordinator) -> NSManagedObjectContext {
        
        let moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        moc.markAsSearch()
        moc.performAndWait {
            moc.configure(with: persistentStoreCoordinator)
            moc.setupLocalCachedSessionAndSelfUser()
            moc.undoManager = nil
            moc.mergePolicy = ZMSyncMergePolicy(merge: .rollbackMergePolicyType)
        }
        return moc
    }
}

extension NSManagedObjectContext {
    
    fileprivate func configure(with persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        self.createDispatchGroups()
        self.persistentStoreCoordinator = persistentStoreCoordinator
    }
    
    // This function setup the user info on the context, the session and self user must be initialised before end.
    fileprivate func setupLocalCachedSessionAndSelfUser() {
        let session = self.executeFetchRequestOrAssert(ZMSession.sortedFetchRequest()).first as! ZMSession
        self.userInfo[SessionObjectIDKey] = session.objectID
        ZMUser.boxSelfUser(session.selfUser, inContextUserInfo: self)
    }
}
