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
import XCTest
@testable import WireDataModel

class StorageStackTests: DatabaseBaseTest {
    
    func testThatTheContextDirectoryIsRetainedInTheSingleton() {

        // WHEN
        weak var contextDirectory: ManagedObjectContextDirectory? = self.createStorageStackAndWaitForCompletion()

        // THEN
        XCTAssertNotNil(contextDirectory)
    }
    
    func testThatItCreatesSubfolderForStorageWithUUID() {
        
        // GIVEN
        let userID = UUID()
        let accountFolder = StorageStack.accountFolder(accountIdentifier: userID, applicationContainer: self.applicationContainer)
        
        // WHEN
        _ = self.createStorageStackAndWaitForCompletion(userID: userID)

        // THEN
        XCTAssertTrue(FileManager.default.fileExists(atPath: accountFolder.path))
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
            accountIdentifier: uuid,
            applicationContainer: self.applicationContainer
        ) { directory in
            contextDirectory = directory
            firstStackExpectation.fulfill()
        }
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 1))
        
        // create an entry to check that it is reopening the same DB
        contextDirectory.uiContext.setPersistentStoreMetadata(testValue, key: testKey)
        let conversationTemp = ZMConversation.insertNewObject(in: contextDirectory.uiContext)
        contextDirectory.uiContext.forceSaveOrRollback()
        let objectID = conversationTemp.objectID
        
        // WHEN
        StorageStack.reset()
        let secondStackExpectation = self.expectation(description: "Callback invoked")
        
        StorageStack.shared.createManagedObjectContextDirectory(
            accountIdentifier: uuid,
            applicationContainer: self.applicationContainer
        ) { directory in
            contextDirectory = directory
            secondStackExpectation.fulfill()
        }
        
        // THEN
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 1))
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
        let storeFile = StorageStack.accountFolder(accountIdentifier: uuid, applicationContainer: self.applicationContainer).appendingPersistentStoreLocation
        try! FileManager.default.createDirectory(at: storeFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // copy old version database into the expected location
        guard let source = Bundle(for: type(of: self)).url(forResource: "store2-3", withExtension: "wiredatabase") else {
            XCTFail("missing resource")
            return
        }
        let destination = URL(string: storeFile.absoluteString)!
        try! FileManager.default.copyItem(at: source, to: destination)
        
        // WHEN
        var contextDirectory: ManagedObjectContextDirectory? = nil
        StorageStack.shared.createManagedObjectContextDirectory(
            accountIdentifier: uuid,
            applicationContainer: self.applicationContainer,
            startedMigrationCallback: { _ in migrationExpectation.fulfill() }
        ) { directory in
            contextDirectory = directory
            completionExpectation.fulfill()
        }
        
        // THEN
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 2))
        guard let uiContext = contextDirectory?.uiContext else {
            XCTFail("No context")
            return
        }
        let messageCount = try! uiContext.count(for: ZMClientMessage.sortedFetchRequest()!)
        XCTAssertGreaterThan(messageCount, 0)
        
    }
    
    func testThatItPerformsMigrationWhenStoreIsInOldLocation() {
        
        let oldLocations = PersistentStoreRelocator.possiblePreviousStoreFiles(applicationContainer: self.applicationContainer)
        let userID = UUID()
        let testValue = "12345678"
        let testKey = "aassddffgg"
        
        [oldLocations.first!].forEach { oldPath in
            
            // GIVEN
            StorageStack.reset()
            self.clearStorageFolder()
            
            self.createLegacyStore(filePath: oldPath) { contextDirectory in
                contextDirectory.uiContext.setPersistentStoreMetadata(testValue, key: testKey)
                contextDirectory.uiContext.forceSaveOrRollback()
            }
            
            // expectations
            let migrationExpectation = self.expectation(description: "Migration started")
            let completionExpectation = self.expectation(description: "Stack initialization completed")
            
            // WHEN
            // create the stack, check that the value is there and that it calls the migration callback
            StorageStack.shared.createManagedObjectContextDirectory(
                accountIdentifier: userID,
                applicationContainer: self.applicationContainer,
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
            XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 1))
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
            accountIdentifier: uuid,
            applicationContainer: self.applicationContainer,
            startedMigrationCallback: { _ in migrationExpectation.fulfill() }
        ) { directory in
            completionExpectation.fulfill()
        }
        
        // THEN
        self.waitForExpectations(timeout: 1)
    }
}

// MARK: - Legacy User ID

extension StorageStackTests {
    
    func testThatItReturnsNilWhenLegacyStoreDoesNotExist() {
        
        // GIVEN
        let completionExpectation = self.expectation(description: "Callback invoked")
        let migrationExpectation = self.expectation(description: "Migration invoked")
        migrationExpectation.isInverted = true
        
        // WHEN
        StorageStack.shared.fetchUserIDFromLegacyStore(
            applicationContainer: self.applicationContainer,
            startedMigrationCallback: { migrationExpectation.fulfill() }
        ) { userID in
            completionExpectation.fulfill()
            XCTAssertNil(userID)
        }
        
        // THEN
        self.waitForExpectations(timeout: 0.5)
    }
    
    func testThatItReturnsNilWhenLegacyStoreExistsButThereIsNoUser() {
        
        // GIVEN
        let oldLocations = PersistentStoreRelocator.possiblePreviousStoreFiles(applicationContainer: self.applicationContainer)
        
        oldLocations.forEach { oldPath in
            
            let completionExpectation = self.expectation(description: "Callback invoked")
            let migrationExpectation = self.expectation(description: "Migration invoked")
            migrationExpectation.isInverted = true
            self.createLegacyStore(filePath: oldPath)
            
            // WHEN
            StorageStack.shared.fetchUserIDFromLegacyStore(
                applicationContainer: self.applicationContainer,
                startedMigrationCallback: { migrationExpectation.fulfill() }
            ) { userID in
                completionExpectation.fulfill()
                XCTAssertNil(userID)
            }
            
            // THEN
            self.wait(for: [completionExpectation, migrationExpectation], timeout: 0.5)
            StorageStack.reset()
            self.clearStorageFolder()
        }
    }
    
    func testThatItReturnsUserIDFromLegacyStoreWhenItExists() {
        
        // GIVEN
        let oldLocations = PersistentStoreRelocator.possiblePreviousStoreFiles(applicationContainer: self.applicationContainer)
        
        oldLocations.forEach { oldPath in
            
            let userID = UUID()
            let completionExpectation = self.expectation(description: "Callback invoked")
            let migrationExpectation = self.expectation(description: "Migration invoked")
            migrationExpectation.isInverted = true
            
            self.createLegacyStore(filePath: oldPath) { contextDirectory in
                ZMUser.selfUser(in: contextDirectory.uiContext).remoteIdentifier = userID
                contextDirectory.uiContext.forceSaveOrRollback()
            }
            
            // WHEN
            StorageStack.shared.fetchUserIDFromLegacyStore(
                applicationContainer: self.applicationContainer,
                startedMigrationCallback: { migrationExpectation.fulfill() }
            ) { fetchedUserID in
                completionExpectation.fulfill()
                XCTAssertEqual(userID, fetchedUserID)
            }
            
            // THEN
            self.wait(for: [completionExpectation, migrationExpectation], timeout: 0.5)
            StorageStack.reset()
            clearStorageFolder()
        }
    }
}











