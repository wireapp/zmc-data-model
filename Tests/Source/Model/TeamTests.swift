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


import WireTesting
@testable import WireDataModel


class TeamTests: BaseTeamTests {

    func testThatItCreatesANewTeamIfThereIsNone() {
        syncMOC.performGroupedBlockAndWait {
            let uuid = UUID.create()
            let sut = Team.fetchOrCreate(with: uuid, true, in: self.syncMOC)
            XCTAssertNotNil(sut)
            XCTAssertEqual(sut?.remoteIdentifier, uuid)
        }
    }

    func testThatItReturnsAnExistingTeamIfThereIsOne() {
        // given
        let sut = Team.insertNewObject(in: uiMOC)
        let uuid = UUID.create()
        sut.remoteIdentifier = uuid

        XCTAssert(uiMOC.saveOrRollback())
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.2))

        // when
        let existing = Team.fetchOrCreate(with: uuid, false, in: uiMOC)

        // then
        XCTAssertNotNil(existing)
        XCTAssertEqual(existing, sut)
    }

    func testThatItReturnsGuestsOfATeam() {
        do {
            // given
            let (team, _) = createTeamAndMember(for: .selfUser(in: uiMOC), with: .member)

            // we add actual team members as well
            createUserAndAddMember(to: team)
            createUserAndAddMember(to: team)

            let guest = ZMUser.insertNewObject(in: uiMOC)
            _ = try team.addConversation(with: [guest])

            // when
            let guests = team.guests()

            // then
            XCTAssertEqual(guests, [guest])
            XCTAssertTrue(guest.isGuest(of: team))
            XCTAssertFalse(guest.isMember(of: team))
        } catch {
            XCTFail("Eror: \(error)")
        }
    }

    func testThatItDoesNotReturnGuestsOfOtherTeams() {
        do {
            // given
            let (team1, _) = createTeamAndMember(for: .selfUser(in: uiMOC), with: .member)
            let (team2, _) = createTeamAndMember(for: .selfUser(in: uiMOC), with: .member)

            // we add actual team members as well
            createUserAndAddMember(to: team1)
            let (otherUser, _) = createUserAndAddMember(to: team2)

            let guest = ZMUser.insertNewObject(in: uiMOC)

            // when
            _ = try team1.addConversation(with: [guest])
            _ = try team2.addConversation(with: [otherUser])

            // then
            XCTAssertEqual(team2.guests(), [])
            XCTAssertEqual(team1.guests(), [guest])
            XCTAssertTrue(guest.isGuest(of: team1))
            XCTAssertFalse(guest.isGuest(of: team2))
            XCTAssertFalse(guest.isGuest(of: team2))
            XCTAssertFalse(otherUser.isGuest(of: team1))
            XCTAssertFalse(guest.isMember(of: team1))
            XCTAssertFalse(guest.isMember(of: team2))
        } catch {
            XCTFail("Eror: \(error)")
        }
    }
    
}
