//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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
@testable import WireDataModel

final class ConversationParticipantsTests : ZMConversationTestsBase {
    
    func testThatActiveParticipantsExcludesUsersMarkedForDeletion() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()!
        let user2 = createUser()!
        
        sut.internalAddParticipants([user1, user2])
        
        XCTAssertEqual(sut.lastServerSyncedActiveParticipants.count, 2)
        XCTAssertEqual(sut.activeParticipants.count, 3)

        // WHEN
        sut.minus(userSet: Set([user2]), isFromLocal: true)
        
        let selfUser = sut.managedObjectContext.map(ZMUser.selfUser)
        
        // THEN
        XCTAssertEqual(sut.lastServerSyncedActiveParticipants, Set([user1, user2]))
        XCTAssertEqual(sut.activeParticipants, Set([user1, selfUser]))
    }
    
    func testThatActiveParticipantsIncludesUsersMarkedForInsertion() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()!
        let user2 = createUser()!
        
        sut.internalAddParticipants([user1])

        // WHEN
        sut.add(user: user2, isFromLocal: true)

        // THEN
        XCTAssertEqual(sut.lastServerSyncedActiveParticipants, Set([user1]))
        XCTAssertEqual(sut.activeParticipants, Set([user1, user2, selfUser]))
    }
    
    func testThatRemoveThenAddParticipants() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()!
        let user2 = createUser()!
        
        sut.internalAddParticipants([user1, user2])
        
        XCTAssertEqual(sut.lastServerSyncedActiveParticipants.count, 2)
        XCTAssertEqual(sut.activeParticipants.count, 3)
        
        // WHEN
        sut.minus(userSet: Set([user2]), isFromLocal: true)
        sut.add(user: user2, isFromLocal: true)

        let selfUser = sut.managedObjectContext.map(ZMUser.selfUser)
        
        // THEN
        XCTAssertEqual(sut.lastServerSyncedActiveParticipants, Set([user1, user2]))
        XCTAssertEqual(sut.activeParticipants, Set([user1, user2, selfUser]))
        
        XCTAssertFalse(user2.participantRoles.first!.markedForDeletion)
        XCTAssertFalse(user2.participantRoles.first!.markedForInsertion)
    }

    func testThatAddThenRemoveParticipants() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()!
        let user2 = createUser()!
        
        sut.internalAddParticipants([user1])
        
        // WHEN
        sut.add(user: user2, isFromLocal: true)
        sut.minus(userSet: Set([user2]), isFromLocal: true)
        uiMOC.processPendingChanges()

        // THEN
        XCTAssertEqual(sut.lastServerSyncedActiveParticipants, Set([user1]))
        XCTAssertEqual(sut.activeParticipants, Set([user1, selfUser]))

        XCTAssert(user2.participantRoles.isEmpty, "\(user2.participantRoles)")
    }
}
