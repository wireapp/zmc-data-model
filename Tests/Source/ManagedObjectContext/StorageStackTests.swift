//
//  StorageStackTests.swift
//  WireDataModel
//
//  Created by Marco Conti on 31.07.17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation
import XCTest
@testable import WireDataModel

class StorageStackTests: XCTestCase {
    
    var appURL: URL {
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
    }
    
    var storeURL: URL {
        return self.appURL.appendingPathComponent("StorageStackTests")
    }
    
    override func setUp() {
        super.setUp()
        self.clearStorageFolder()
        try! FileManager.default.createDirectory(at: self.appURL, withIntermediateDirectories: true)
    }
    
    fileprivate func clearStorageFolder() {
        try? FileManager.default.removeItem(at: self.storeURL)

    }
    
    override func tearDown() {
        StorageStack.reset()
        super.tearDown()
        self.clearStorageFolder()
    }
    
    func testThatTheContextDirectoryIsRetainedInTheSingleton() {

        // WHEN
        weak var contextDirectory: ManagedObjectContextDirectory? = self.createStorageStackAndWaitForCompletion()

        // THEN
        XCTAssertNotNil(contextDirectory)
    }
    
    func testThatItCreatesSubfolderForStorageWithUUID() {
        
        // WHEN
        _ = self.createStorageStackAndWaitForCompletion()

        // THEN
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.storeURL.path))
    }
    
    func testThatTheContextDirectoryIsTornDown() {
        
        // GIVEN
        weak var contextDirectory: ManagedObjectContextDirectory? = self.createStorageStackAndWaitForCompletion()

        // WHEN
        StorageStack.reset()
        
        // THEN
        XCTAssertNil(contextDirectory)
        
    }
    
    func testThatItCanReopenAPreviouslyExistingDatabase() {
    
        // GIVEN
        let uuid = UUID()
        let firstStackExpectation = self.expectation(description: "Callback invoked")
        let testValue = "12345678"
        let testKey = "aassddffgg"
        weak var contextDirectory: ManagedObjectContextDirectory! = nil
        StorageStack.shared.createManagedObjectContextDirectory(
            forAccountWith: uuid,
            inContainerAt: self.storeURL
        ) { directory in
            contextDirectory = directory
            firstStackExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 1)
        
        // create an entry to check that it is reopening the same DB
        contextDirectory.uiContext.setPersistentStoreMetadata(testValue, key: testKey)
        let conversationTemp = ZMConversation.insertNewObject(in: contextDirectory.uiContext)
        contextDirectory.uiContext.forceSaveOrRollback()
        let objectID = conversationTemp.objectID
        
        // WHEN
        StorageStack.reset()
        let secondStackExpectation = self.expectation(description: "Callback invoked")
        
        StorageStack.shared.createManagedObjectContextDirectory(
            forAccountWith: uuid,
            inContainerAt: self.storeURL
        ) { directory in
            contextDirectory = directory
            secondStackExpectation.fulfill()
        }
        
        // THEN
        self.waitForExpectations(timeout: 1)
        XCTAssertEqual(contextDirectory.uiContext.persistentStoreCoordinator!.persistentStores.count, 1)

        guard let readValue = contextDirectory.uiContext.persistentStoreMetadata(forKey: testKey) as? String else {
            XCTFail("Can't read previous value from the context")
            return
        }
        guard let _ = try? contextDirectory.uiContext.existingObject(with: objectID) as? ZMConversation else {
            XCTFail("Can't find previous conversation in the context")
            return
        }
        XCTAssertEqual(readValue, testValue)
    }
    
    func testThatItPerformsMigrationCallbackWhenDifferentVersion() {
        
        // GIVEN
        let uuid = UUID()
        let completionExpectation = self.expectation(description: "Callback invoked")
        let migrationExpectation = self.expectation(description: "Migration started")
        
        
        
        // WHEN
        StorageStack.shared.createManagedObjectContextDirectory(
            forAccountWith: uuid,
            inContainerAt: self.storeURL,
            startedMigrationCallback: { _ in migrationExpectation.fulfill() }
        ) { directory in
            completionExpectation.fulfill()
        }
        
        // THEN
        self.waitForExpectations(timeout: 1)
    }
    
    func testThatItPerformsMigrationWhenStoreIsInOldLocation() {
        
        let oldLocations = PersistentStoreRelocator.possiblePreviousStoreLocations(sharedContainerURL: self.storeURL)
        let userID = UUID()
        let testValue = "12345678"
        let testKey = "aassddffgg"
        
        oldLocations.forEach { oldPath in
            
            // GIVEN
            StorageStack.reset()
            self.clearStorageFolder()
            
            // create a proper stack and set some values, so we have something to migrate
            let storeURL: URL = {
                // keep this variable in a scope, so contextDirectory is released at the end of scope
                let contextDirectory = self.createStorageStackAndWaitForCompletion(userID: userID)
                contextDirectory.uiContext.setPersistentStoreMetadata(testValue, key: testKey)
                contextDirectory.uiContext.forceSaveOrRollback()
                return contextDirectory.uiContext.persistentStoreCoordinator!.persistentStores.first!.url!
            }()
            StorageStack.reset()
            
            // move the stack to "old" location, to simulate that the database needs to be migrated from there
            let initialFolderWithDatabase = storeURL.deletingLastPathComponent()
            let legacyFolderWithDatabase = oldPath.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: legacyFolderWithDatabase)
            try? FileManager.default.createDirectory(at: legacyFolderWithDatabase.deletingLastPathComponent(), withIntermediateDirectories: true)
            try! FileManager.default.moveItem(at: initialFolderWithDatabase, to: legacyFolderWithDatabase)
            
            // expectations
            let migrationExpectation = self.expectation(description: "Migration started")
            let completionExpectation = self.expectation(description: "Stack initialization completed")
            
            // WHEN
            // create the stack, check that the value is there and that it calls the migration callback
            StorageStack.shared.createManagedObjectContextDirectory(
                forAccountWith: userID,
                inContainerAt: self.storeURL,
                startedMigrationCallback: { _ in migrationExpectation.fulfill() }
            ) { MOCs in
                defer { completionExpectation.fulfill() }
                guard let string = MOCs.uiContext.persistentStoreMetadata(forKey: testKey) as? String else {
                    XCTFail("Failed to find same value after migrating from \(oldPath.path)")
                    return
                }
                XCTAssertEqual(string, testValue)
            }
            
            // THEN
            self.waitForExpectations(timeout: 1)
            StorageStack.reset()
        }
    }
    
    func testThatItDoesNotInvokeTheMigrationCallback() {
        
        // GIVEN
        let uuid = UUID()
        let completionExpectation = self.expectation(description: "Callback invoked")
        let migrationExpectation = self.expectation(description: "Migration started")
        migrationExpectation.isInverted = true
        
        // WHEN
        StorageStack.shared.createManagedObjectContextDirectory(
            forAccountWith: uuid,
            inContainerAt: self.storeURL,
            startedMigrationCallback: { _ in migrationExpectation.fulfill() }
        ) { directory in
            completionExpectation.fulfill()
        }
        
        // THEN
        self.waitForExpectations(timeout: 1)
    }
}

extension StorageStackTests {
    
    fileprivate func createStorageStackAndWaitForCompletion(
            userID: UUID = UUID()
        ) -> ManagedObjectContextDirectory {
        
        let expectation = self.expectation(description: "Stack created")
        var contextDirectory: ManagedObjectContextDirectory? = nil
        
        StorageStack.shared.createManagedObjectContextDirectory(
            forAccountWith: userID,
            inContainerAt: self.storeURL
        ) { directory in
            contextDirectory = directory
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 500)
        return contextDirectory!
    }
    
}
