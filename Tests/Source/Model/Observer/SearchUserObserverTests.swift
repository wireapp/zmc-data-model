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
    
    func testThatItNotifiesObserversWhenConnectingToASearchUserThatHasNoLocalUser(){
    
        // given
        let remoteID = UUID.create()
        let searchUser = ZMSearchUser(name: "Hans",
                                      handle: "hans",
                                      accentColor: .brightOrange,
                                      remoteID: remoteID,
                                      user: nil,
                                      syncManagedObjectContext: self.syncMOC,
                                      uiManagedObjectContext:self.uiMOC)!
        
        XCTAssertFalse(searchUser.isPendingApprovalByOtherUser)
        let token = UserChangeInfo.add(searchUserObserver: testObserver, for: searchUser, inManagedObjectContext:uiMOC)

        // expect
        let callbackCalled = expectation(description: "Connection callback was called")
        
        // when
        searchUser.connect(withMessageText: "Hey") { 
            callbackCalled.fulfill()
        }
        XCTAssert(waitForCustomExpectations(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(testObserver.receivedChangeInfo.count, 1)
        guard let note = testObserver.receivedChangeInfo.first else { return XCTFail()}
        XCTAssertEqual(note.user as? ZMSearchUser, searchUser)
        XCTAssertTrue(note.connectionStateChanged)
        
        UserChangeInfo.remove(searchUserObserver: token, for: searchUser)
    }
 
    func testThatItNotifiesObserverWhenConnectingToALocalUser() {
    
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        XCTAssert(uiMOC.saveOrRollback())

        let searchUser = ZMSearchUser(name: "Hans",
                                      handle: "hans",
                                      accentColor: .brightOrange,
                                      remoteID: nil,
                                      user: user,
                                      syncManagedObjectContext: self.syncMOC,
                                      uiManagedObjectContext:self.uiMOC)!
        
        let testObserver2 = TestSearchUserObserver()
        let token1 = UserChangeInfo.add(observer: testObserver, for: user)
        let token2 = UserChangeInfo.add(searchUserObserver: testObserver2, for: searchUser, inManagedObjectContext:uiMOC)
        
        // expect
        let callbackCalled = expectation(description: "Connection callback was called")
        
        // when
        searchUser.connect(withMessageText: "Hey") {
            callbackCalled.fulfill()
        }
        XCTAssert(uiMOC.saveOrRollback())
        XCTAssert(waitForCustomExpectations(withTimeout: 0.5))
        
        // when
        XCTAssertTrue(searchUser.user.isPendingApprovalByOtherUser)
        XCTAssertEqual(testObserver.receivedChangeInfo.count, 1)
        XCTAssertEqual(testObserver2.receivedChangeInfo.count, 1)
        
        if let note1 = testObserver.receivedChangeInfo.first {
            XCTAssertEqual(note1.user as? ZMUser, user)
            XCTAssertTrue(note1.connectionStateChanged)
        } else {
            XCTFail("Did not receive UserChangeInfo for ZMUser")
        }

        if let note2 = testObserver2.receivedChangeInfo.first {
            XCTAssertEqual(note2.user as? ZMSearchUser, searchUser)
            XCTAssertTrue(note2.connectionStateChanged)
        } else {
            XCTFail("Did not receive UserChangeInfo for ZMSearchUser")
        }
        
        UserChangeInfo.remove(observer: token1, for: user)
        UserChangeInfo.remove(searchUserObserver: token2, for: searchUser)
    }
}
