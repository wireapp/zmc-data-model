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
import XCTest

class NSPersistentStoreMetadataTests : BaseZMMessageTests {
    
    var shouldUseInMemoryStore : Bool {
        return false
    }
    
    override func setUp() {
        super.setUp()
    }
    override func tearDown() {
        super.tearDown()
    }
}

extension NSPersistentStoreMetadataTests {
    
    func testThatItStoresMetadataInMemory() {
        
        // GIVEN
        let data = "foo"
        let key = "boo"
        
        // WHEN
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        
        // THEN
        XCTAssertEqual(data, self.uiMOC.persistentStoreMetadata(key: key) as? String)
    }
    
    func testThatItDeletesMetadataFromMemory() {
        
        // GIVEN
        let data = "foo"
        let key = "boo"
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        
        // WHEN
        self.uiMOC.setPersistentStoreMetadata(nil as String?, key: key)
        
        // THEN
        XCTAssertEqual(nil, self.uiMOC.persistentStoreMetadata(key: key) as? String)
    }
    
    func testThatMetadataAreNotPersisted() {
        
        // GIVEN
        let data = "foo"
        let key = "boo"
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        
        // WHEN
        self.resetUIandSyncContextsAndResetPersistentStore(false)
        
        // THEN
        XCTAssertEqual(nil, self.uiMOC.persistentStoreMetadata(key: key) as? String)
    }
    
    func testThatItPersistsMetadataWhenSaving() {
        
        // GIVEN
        let data = "foo"
        let key = "boo"
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        
        // WHEN
        self.uiMOC.saveOrRollback()
        self.resetUIandSyncContextsAndResetPersistentStore(false)
        
        // THEN
        XCTAssertEqual(data, self.uiMOC.persistentStoreMetadata(key: key) as? String)
    }
    
    func testThatItDiscardsMetadataWhenRollingBack() {
        
        // GIVEN
        let data = "foo"
        let key = "boo"
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        
        // WHEN
        self.uiMOC.enableForceRollback()
        self.uiMOC.saveOrRollback()
        
        // THEN
        XCTAssertEqual(nil, self.uiMOC.persistentStoreMetadata(key: key) as? String)
        
        // AFTER
        self.uiMOC.disableForceRollback()
    }
    
    func testThatItDeletesAlreadySetMetadataInMemory() {
        
        // GIVEN
        let data = "foo"
        let key = "boo"
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        self.uiMOC.saveOrRollback()
        
        // WHEN
        self.uiMOC.setPersistentStoreMetadata(nil as String?, key: key)
        
        // THEN
        XCTAssertEqual(nil, self.uiMOC.persistentStoreMetadata(key: key) as? String)
    }
    
    func testThatItDiscardsDeletesAlreadySetMetadataInMemory() {
        
        // GIVEN
        let data = "foo"
        let key = "boo"
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        self.uiMOC.saveOrRollback()
        self.uiMOC.setPersistentStoreMetadata(nil as String?, key: key)
        
        // WHEN
        self.resetUIandSyncContextsAndResetPersistentStore(false)
        
        // THEN
        XCTAssertEqual(data, self.uiMOC.persistentStoreMetadata(key: key) as? String)
    }
    
    func testThatItDeletesAlreadySetMetadataFromStore() {
        
        // GIVEN
        let data = "foo"
        let key = "boo"
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        self.uiMOC.saveOrRollback()
        self.uiMOC.setPersistentStoreMetadata(nil as String?, key: key)
        
        // WHEN
        self.uiMOC.saveOrRollback()
        self.resetUIandSyncContextsAndResetPersistentStore(false)
        
        // THEN
        XCTAssertEqual(nil, self.uiMOC.persistentStoreMetadata(key: key) as? String)
    }
}

// MARK: - What can be saved
extension NSPersistentStoreMetadataTests {
    
    func checkThatItCanSave<T: Equatable & SwiftPersistableInMetadata>(data: T, file: StaticString = #file, line: UInt = #line) {
        
        // GIVEN
        let key = "boo"
        self.uiMOC.setPersistentStoreMetadata(data, key: key)
        
        // WHEN
        self.uiMOC.saveOrRollback()
        self.resetUIandSyncContextsAndResetPersistentStore(false)
        
        // THEN
        XCTAssertEqual(data, self.uiMOC.persistentStoreMetadata(key: key) as? T, file: file, line: line)
    }
    
    func testThatItCanStoreStrings() {
        self.checkThatItCanSave(data: "Foo")
    }
    
    func testThatItCanStoreDates() {
        self.checkThatItCanSave(data: Date())
    }
    
    func testThatItCanStoreData() {
        self.checkThatItCanSave(data: Data(bytes: [21,3])
    }
    
    func testThatItCanStoreArrayOfString() {
        self.checkThatItCanSave(data: ["foo", "bar"])
    }
}
