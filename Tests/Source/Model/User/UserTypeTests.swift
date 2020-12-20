//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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

final class UserTypeTests: ModelObjectsTests {
    private var searchUser: ZMSearchUser!
    
    override func setUp() {
        super.setUp()
        
        searchUser = ZMSearchUser(contextProvider: self,
                                 name: name.capitalized,
                                 handle: name.lowercased(),
                                 accentColor: .brightOrange,
                                 remoteIdentifier: UUID())
    }
    
    override func tearDown() {
        
        super.tearDown()
    }

    func testThatZMSearchUserCanBeComparedWithIsEqualTo() {
        XCTAssert(searchUser.isEqualTo(searchUser))
    }

    func testThatDifferentZMSearchUserReturnFalseWhenComparing() {
        let anotherSearchUser =  ZMSearchUser(contextProvider: self,
                                              name: "another search user",
                                              handle: "another search user",
                                              accentColor: .softPink,
                                              remoteIdentifier: UUID())
        
        XCTAssertFalse(searchUser.isEqualTo(anotherSearchUser))
    }
    
    func testThatZMUserCanBeComparedWithIsEqualTo() {
        XCTAssert(selfUser.isEqualTo(selfUser))
    }

    func testThatDifferentZMUserReturnFalseWhenComparing() {
        let otherUser = ZMUser.insertNewObject(in: uiMOC)
        otherUser.remoteIdentifier = UUID()
        
        XCTAssertFalse(selfUser.isEqualTo(otherUser))
    }

    func testThatIsEqualToReturnFalseForDifferentTypesOfUsers() {
        XCTAssertFalse(searchUser.isEqualTo(selfUser))
    }
}

extension UserTypeTests: ZMManagedObjectContextProvider {
    
    var managedObjectContext: NSManagedObjectContext! {
        return uiMOC
    }
    
    var syncManagedObjectContext: NSManagedObjectContext! {
        return syncMOC
    }
    
}
