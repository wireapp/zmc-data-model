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

/*
 
 
 - (void)testThatWeCanStoreMetadataInStore
 {
 XCTAssertNil([self.uiMOC persistentStoreMetadataForKey:@"TestKey"]);
 [self.uiMOC setPersistentStoreMetadata:@"value_172653" forKey:@"TestKey"];
 XCTAssertEqualObjects([self.uiMOC persistentStoreMetadataForKey:@"TestKey"], @"value_172653");
 }
 
 - (void)testThatItSavesMetadataWhenSaveIsSuccessfull;
 {
 //given
 NSManagedObjectContext *sut = self.alternativeTestMOC;
 NSString *key = @"Good stuff", *value = @"Jambon";
 [sut setPersistentStoreMetadata:value forKey:key];
 
 //when
 [sut saveOrRollback]; //will save
 
 //then
 XCTAssertNil(sut.userInfo[@"ZMMetadataKey"]);
 XCTAssertNotNil([sut persistentStoreMetadataForKey:key]);
 XCTAssertEqualObjects([sut persistentStoreMetadataForKey:key], value);
 }
 
 - (void)testThatItRevertsMetadataWhenRollback;
 {
 //given
 NSManagedObjectContext *sut = self.alternativeTestMOC;
 NSString *key = @"Good stuff", *value = @"Jambon";
 [sut setPersistentStoreMetadata:value forKey:key];
 [sut enableForceRollback];
 
 //when
 [sut saveOrRollback]; // will rollback
 
 //then
 XCTAssertNil(sut.userInfo[@"ZMMetadataKey"]);
 XCTAssertNil([sut persistentStoreMetadataForKey:key]);
 }
 

 
 
 */

class NSPersistentStoreMetadataTests : BaseZMMessageTests {
    
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
