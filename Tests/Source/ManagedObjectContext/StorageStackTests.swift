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
        try? FileManager.default.removeItem(at: self.storeURL)
        try! FileManager.default.createDirectory(at: self.appURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        StorageStack.reset()
        super.tearDown()
        try? FileManager.default.removeItem(at: self.storeURL)
    }
    
    func testThatTheContextDirectoryIsRetainedInTheSingleton() {
        
        // GIVEN
        let uuid = UUID()
        let expectation = self.expectation(description: "Callback invoked")
        weak var contextDirectory: ManagedObjectContextDirectory? = nil

        // WHEN
        StorageStack.shared.createManagedObjectContextDirectory(
            forAccountWith: uuid,
            inContainerAt: self.storeURL
        ) { directory in
            contextDirectory = directory
            expectation.fulfill()
        }
        
        // THEN
        self.waitForExpectations(timeout: 0.5)
        XCTAssertNotNil(contextDirectory)
        
    }
    
    func testThatItCreatesSubfolderForStorageWithUUID() {
        
        // GIVEN
        let uuid = UUID()
        let expectation = self.expectation(description: "Callback invoked")
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.storeURL.path))

        // WHEN
        StorageStack.shared.createManagedObjectContextDirectory(
            forAccountWith: uuid,
            inContainerAt: self.storeURL
        ) { _ in
            expectation.fulfill()
        }
        
        // THEN
        self.waitForExpectations(timeout: 0.5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.storeURL.path))
    }
    
    func testThatTheContextDirectoryIsTornDown() {
        
        // GIVEN
        let uuid = UUID()
        let expectation = self.expectation(description: "Callback invoked")
        weak var contextDirectory: ManagedObjectContextDirectory? = nil
        
        StorageStack.shared.createManagedObjectContextDirectory(
            forAccountWith: uuid,
            inContainerAt: self.storeURL
        ) { directory in
            contextDirectory = directory
            expectation.fulfill()
        }
        
        // WHEN
        self.waitForExpectations(timeout: 0.5)
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
        
        self.waitForExpectations(timeout: 50000)
        
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
        self.waitForExpectations(timeout: 50000)
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
    
}
