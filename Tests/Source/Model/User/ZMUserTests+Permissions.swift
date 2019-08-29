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

import XCTest

class ZMUserTests_Permissions: ModelObjectsTests {
    
    var team: Team!
    var conversation: ZMConversation!
    
    override func setUp() {
        super.setUp()
        team = Team.insertNewObject(in: uiMOC)
        team.remoteIdentifier = .create()
        conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.remoteIdentifier = .create()
    }
    
    override func tearDown() {
        team = nil
        conversation = nil
        super.tearDown()
    }

    // MARK: Adding users
    
    func testThatAUserCanAddUsersToAConversation_WithoutTeamAndWithoutTeamRemoteIdentifier() {
        // when & then
        XCTAssert(ZMUser.selfUser(in: uiMOC).canAddUser(to: conversation))
    }
    
    func testThatAUserCantAddUsersToAConversation_WhereHeIsGuest() {
        // when
        conversation.teamRemoteIdentifier = team.remoteIdentifier
        
        // then
        XCTAssertFalse(ZMUser.selfUser(in: uiMOC).canAddUser(to: conversation))
    }
    
    func testThatAUserCantAddUsersToAConversation_WhereHeIsNotAnActiveMember() {
        // when
        conversation.isSelfAnActiveMember = false
        
        // then
        XCTAssertFalse(ZMUser.selfUser(in: uiMOC).canAddUser(to: conversation))
    }
    
    func testThatAUserCantAddUsersToAConversation_WhereHeIsMemberWithUnsufficientPermissions() {
        self.performPretendingUiMocIsSyncMoc {
            // when
            let selfUser = ZMUser.selfUser(in: self.uiMOC)
            let member = Member.getOrCreateMember(for: selfUser, in: self.team, context: self.uiMOC)
            member.permissions = Permissions.none
            self.conversation.team = self.team
            
            // then
            XCTAssertFalse(selfUser.canAddUser(to: self.conversation))
        }
    }
    
    func testThatAUserCanAddUsersToAConversation_WhereHeIsMemberWithSufficientPermissions() {
        self.performPretendingUiMocIsSyncMoc {
            // when
            self.conversation.team = self.team
            self.conversation.teamRemoteIdentifier = self.team.remoteIdentifier
            let selfUser = ZMUser.selfUser(in: self.uiMOC)
            let member = Member.getOrCreateMember(for: selfUser, in: self.team, context: self.uiMOC)
            member.permissions = .member
            
            // then
            XCTAssert(selfUser.canAddUser(to: self.conversation))
        }
    }
    
    // MARK: - Removing users

    func testThatAUserCanRemoveUsersFromAConversation_WithoutTeamAndWithoutTeamRemoteIdentifier() {
        // when & then
        XCTAssert(ZMUser.selfUser(in: uiMOC).canRemoveUser(from: conversation))
    }
    
    func testThatAUserCantRemoveUsersFromAConversation_WhereHeIsGuest() {
        // when
        conversation.teamRemoteIdentifier = team.remoteIdentifier
        
        // then
        XCTAssertFalse(ZMUser.selfUser(in: uiMOC).canRemoveUser(from: conversation))
    }
    
    func testThatAUserCantRemoveUsersFromAConversation_WhereHeIsNotAnActiveMember() {
        // when
        conversation.isSelfAnActiveMember = false
        
        // then
        XCTAssertFalse(ZMUser.selfUser(in: uiMOC).canRemoveUser(from: conversation))
    }
    
    func testThatAUserCantRemoveUsersFromAConversation_WhereHeIsMemberWithUnsufficientPermissions() {
        self.performPretendingUiMocIsSyncMoc {
            // when
            let selfUser = ZMUser.selfUser(in: self.uiMOC)
            let member = Member.getOrCreateMember(for: selfUser, in: self.team, context: self.uiMOC)
            member.permissions = Permissions.none
            self.conversation.team = self.team
            
            // then
            XCTAssertFalse(selfUser.canRemoveUser(from: self.conversation))
        }
    }
    
    func testThatAUserCanRemoveUsersFromAConversation_WhereHeIsMemberWithSufficientPermissions() {
        self.performPretendingUiMocIsSyncMoc {
            // when
            self.conversation.team = self.team
            self.conversation.teamRemoteIdentifier = self.team.remoteIdentifier
            let selfUser = ZMUser.selfUser(in: self.uiMOC)
            let member = Member.getOrCreateMember(for: self.selfUser, in: self.team, context: self.uiMOC)
            member.permissions = .member
            
            // then
            XCTAssert(selfUser.canRemoveUser(from: self.conversation))
        }
    }
    
    // MARK: Guests
    
    func testThatItDoesNotReportIsGuest_ForANonTeamConversation() {
        XCTAssertFalse(ZMUser.selfUser(in: uiMOC).isGuest(in: conversation))
    }
    
    func testThatItReportsIsGuest_ForANonTeamUserInATeamConversation() {
        // given
        conversation.team = team
        conversation.teamRemoteIdentifier = team.remoteIdentifier
        
        // then
        XCTAssertTrue(ZMUser.selfUser(in: uiMOC).isGuest(in: conversation))
    }
    
    func testThatItReportsIsGuest_WhenAConversationDoesNotHaveATeam() {
        // given
        conversation.teamRemoteIdentifier = team.remoteIdentifier
        
        // then
        XCTAssert(ZMUser.selfUser(in: uiMOC).isGuest(in: conversation))
    }
}
