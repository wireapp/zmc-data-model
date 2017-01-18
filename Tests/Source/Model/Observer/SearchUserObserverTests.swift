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

class SearchUserObserverTests : NotificationDispatcherTests {
    
    class TestSearchUserObserver : NSObject, ZMUserObserver {
        
        var receivedChangeInfo : [UserChangeInfo] = []
        
        func userDidChange(_ changes: UserChangeInfo) {
            receivedChangeInfo.append(changes)
        }
    }
    
    var testObserver : TestSearchUserObserver!
    
    override func setUp() {
        super.setUp()
        testObserver = TestSearchUserObserver()
    }
    
    override func tearDown() {
        testObserver = nil
        uiMOC.searchUserObserverCenter.reset()
        super.tearDown()
    }
    
    func testThatItNotifiesTheObserverOfASmallProfilePictureChange() {
        
        // given
        let remoteID = UUID.create()
        let searchUser = ZMSearchUser(name: "Hans",
                                      handle: "hans",
                                      accentColor: .brightOrange,
                                      remoteID: remoteID,
                                      user: nil,
                                      syncManagedObjectContext: self.syncMOC,
                                      uiManagedObjectContext:self.uiMOC)!
        
        let token = UserChangeInfo.add(searchUserObserver: testObserver, for: searchUser, inManagedObjectContext:uiMOC)
        
        // when
        searchUser.notifyNewSmallImageData(self.verySmallJPEGData(), searchUserObserverCenter: uiMOC.searchUserObserverCenter)
        
        // then
        XCTAssertEqual(testObserver.receivedChangeInfo.count, 1)
        if let note = testObserver.receivedChangeInfo.first {
            XCTAssertTrue(note.imageSmallProfileDataChanged)
        }
        UserChangeInfo.remove(searchUserObserver: token, for: searchUser)
    }
    
    func testThatItNotifiesTheObserverOfASmallProfilePictureChangeIfTheInternalUserUpdates() {
        
        // given
        let user = ZMUser.insertNewObject(in:self.uiMOC)
        user.remoteIdentifier = UUID.create()
        self.uiMOC.saveOrRollback()
        let searchUser = ZMSearchUser(name: "Foo",
                                      handle: "foo",
                                      accentColor: .brightYellow,
                                      remoteID: user.remoteIdentifier,
                                      user: user,
                                      syncManagedObjectContext: self.syncMOC,
                                      uiManagedObjectContext:self.uiMOC)!
        
        let token = UserChangeInfo.add(searchUserObserver: testObserver, for: searchUser, inManagedObjectContext:uiMOC)
        
        // when
        user.smallProfileRemoteIdentifier = UUID.create()
        user.imageSmallProfileData = self.verySmallJPEGData()
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(testObserver.receivedChangeInfo.count, 1)
        if let note = testObserver.receivedChangeInfo.first {
            XCTAssertTrue(note.imageSmallProfileDataChanged)
        }
        UserChangeInfo.remove(searchUserObserver: token, for: searchUser)
    }
    
    func testThatItStopsNotifyingAfterUnregisteringTheToken() {
        
        // given
        let remoteID = UUID.create()
        let searchUser = ZMSearchUser(name: "Hans",
                                      handle: "hans",
                                      accentColor: .brightOrange,
                                      remoteID: remoteID,
                                      user: nil,
                                      syncManagedObjectContext: self.syncMOC,
                                      uiManagedObjectContext:self.uiMOC)!
        
        let token = UserChangeInfo.add(searchUserObserver: testObserver, for: searchUser, inManagedObjectContext:uiMOC)
        UserChangeInfo.remove(searchUserObserver: token, for: searchUser)
        
        // when
        searchUser.notifyNewSmallImageData(self.verySmallJPEGData(), searchUserObserverCenter: uiMOC.searchUserObserverCenter)
        
        // then
        XCTAssertEqual(testObserver.receivedChangeInfo.count, 0)
    }
    
    
}
