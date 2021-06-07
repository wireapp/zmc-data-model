//
// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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

class ZMUserTests_Team: ModelObjectsTests {

    func testThatItCreatesMembershipIfUserBelongsToSelfUserTeamOnAnExistingUser() {
        // given
        let userID = UUID()
        let teamID = UUID()
        let team = Team.insertNewObject(in: uiMOC)
        let user = ZMUser.insertNewObject(in: uiMOC)
        team.remoteIdentifier = teamID
        user.remoteIdentifier = userID
        user.teamIdentifier = teamID

        // when
        performPretendingUiMocIsSyncMoc {
            user.createOrDeleteMembershipIfBelongingToTeam()
        }

        // then
        XCTAssertEqual(user.membership?.team, team)
    }

    func testThatItDoesNotCreateMembershipIfUserIsDeleted() {
        // given
        let userID = UUID()
        let teamID = UUID()
        let team = Team.insertNewObject(in: uiMOC)
        let user = ZMUser.insertNewObject(in: uiMOC)
        team.remoteIdentifier = teamID
        user.remoteIdentifier = userID
        user.teamIdentifier = teamID
        user.markAccountAsDeleted(at: Date())

        // when
        user.createOrDeleteMembershipIfBelongingToTeam()

        // then
        XCTAssertNil(user.membership)
    }

    func testThatItDoesNotCreateMembershipIfUserBelongsExternalTeamOnAnExistingUser() {
        // given
        let userID = UUID()
        let teamID = UUID()
        let externalTeamID = UUID()
        let team = Team.insertNewObject(in: uiMOC)
        let user = ZMUser.insertNewObject(in: uiMOC)
        team.remoteIdentifier = teamID
        user.remoteIdentifier = userID
        user.teamIdentifier = externalTeamID

        // when
        user.createOrDeleteMembershipIfBelongingToTeam()

        // then
        XCTAssertNil(user.membership)
    }

    func testThatItDeletesMembershipIfUserBelongsToSelfUserTeamOnAnExistingUserWhoIsMarkedAsDeleted() {
        // given
        let userID = UUID()
        let teamID = UUID()
        let team = Team.insertNewObject(in: uiMOC)
        let user = ZMUser.insertNewObject(in: uiMOC)
        let membership = Member.insertNewObject(in: uiMOC)
        team.remoteIdentifier = teamID
        user.remoteIdentifier = userID
        user.teamIdentifier = teamID
        user.markAccountAsDeleted(at: Date())
        membership.user = user
        membership.team = team

        // when
        user.createOrDeleteMembershipIfBelongingToTeam()

        // then
        XCTAssertTrue(membership.isDeleted);
    }

}
