//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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
@testable import WireDataModel

/**
 * Tests for calculating the state of external users presence in a team conversation.
 *
 * Expected matrix:
 *
 * +---------------------------------------------------------------------------------+
 * | Conversation Type | Self User  | Other Users          | Expected State For Self |
 * |-------------------|------------|----------------------|-------------------------|
 * | 1:1               | Personal   | Personal             | None                    |
 * | 1:1               | Personal   | Team                 | None                    |
 * | 1:1               | Team       | Team                 | None                    |
 * | 1:1               | Team       | Personal             | None                    |
 * | 1:1               | Team       | Service              | None                    |
 * |-------------------|------------|----------------------|-------------------------|
 * | Group             | Personal   | Personal             | None                    |
 * | Group             | Personal   | Team                 | None                    |
 * | Group             | Team       | Team                 | None                    |
 * | Group             | Other Team | Team                 | None                    |
 * | Group             | Other Team | Personal             | None                    |
 * | Group             | Team       | Service              | None                    |
 * | Group             | Team       | Personal             | Only Guests             |
 * | Group             | Team       | Other Team           | Only Guests             |
 * | Group             | Team       | Team & Service       | Only Services           |
 * | Group             | Other Team | Team & Service       | Only Services           |
 * | Group             | Other Team | Personal & Service   | Only Services           |
 * | Group             | Team       | Personal & Service   | Guests & Services       |
 * | Group             | Team       | Other Team & Service | Guests & Services       |
 * +---------------------------------------------------------------------------------+
 */

class ZMConversationExternalParticipantsStateTests: ZMConversationTestsBase {

    enum RelativeUserState {
        case personal
        case memberOfHostingTeam
        case memberOfOtherTeam
        case service
    }

    func testOneToOneCases() {
        // Personal Users
        assertMatrixRow(.oneOnOne, selfUser: .personal, otherUsers: [.personal], expectedResult: .none)
        assertMatrixRow(.oneOnOne, selfUser: .personal, otherUsers: [.memberOfHostingTeam], expectedResult: .none)

        // Team
        assertMatrixRow(.oneOnOne, selfUser: .memberOfHostingTeam, otherUsers: [.memberOfHostingTeam], expectedResult: .none)
        assertMatrixRow(.oneOnOne, selfUser: .memberOfHostingTeam, otherUsers: [.personal], expectedResult: .none)
        assertMatrixRow(.oneOnOne, selfUser: .memberOfHostingTeam, otherUsers: [.service], expectedResult: .none)
    }

    func testGroupCases() {
        // None
        assertMatrixRow(.group, selfUser: .personal, otherUsers: [.personal], expectedResult: .none)
        assertMatrixRow(.group, selfUser: .personal, otherUsers: [.memberOfHostingTeam], expectedResult: .none)
        assertMatrixRow(.group, selfUser: .memberOfHostingTeam, otherUsers: [.memberOfHostingTeam], expectedResult: .none)
        assertMatrixRow(.group, selfUser: .memberOfOtherTeam, otherUsers: [.memberOfHostingTeam], expectedResult: .none)
        assertMatrixRow(.group, selfUser: .memberOfOtherTeam, otherUsers: [.personal], expectedResult: .none)
        assertMatrixRow(.group, selfUser: .memberOfHostingTeam, otherUsers: [.service], expectedResult: .none)

        // Only Guests
        assertMatrixRow(.group, selfUser: .memberOfHostingTeam, otherUsers: [.personal], expectedResult: .onlyGuests)
        assertMatrixRow(.group, selfUser: .memberOfHostingTeam, otherUsers: [.memberOfOtherTeam], expectedResult: .onlyGuests)

        // Only Services
        assertMatrixRow(.group, selfUser: .memberOfHostingTeam, otherUsers: [.memberOfHostingTeam, .service], expectedResult: .onlyServices)
        assertMatrixRow(.group, selfUser: .memberOfOtherTeam, otherUsers: [.memberOfHostingTeam, .service], expectedResult: .onlyServices)
        assertMatrixRow(.group, selfUser: .memberOfOtherTeam, otherUsers: [.personal, .service], expectedResult: .onlyServices)

        // Guests and Services
        assertMatrixRow(.group, selfUser: .memberOfHostingTeam, otherUsers: [.personal, .service], expectedResult: .guestsAndServices)
        assertMatrixRow(.group, selfUser: .memberOfHostingTeam, otherUsers: [.memberOfOtherTeam, .service], expectedResult: .guestsAndServices)
    }

    // MARK: - Helpers

    func createConversationWithSelfUser() -> ZMConversation {
        let conversation = createConversation(in: uiMOC)
        conversation.internalAddParticipants([selfUser])
        conversation.isSelfAnActiveMember = true
        return conversation
    }

    func assertMatrixRow(_ conversationType: ZMConversationType, selfUser selfUserType: RelativeUserState, otherUsers: [RelativeUserState], expectedResult: ZMConversationExternalParticipantsState, file: StaticString = #file, line: UInt = #line) {
        // 1) Create the conversation
        let conversation = createConversationWithSelfUser()
        conversation.conversationType = conversationType

        var hostingTeam: Team?

        switch selfUserType {
        case .memberOfHostingTeam:
            let team = createTeam(in: uiMOC)
            hostingTeam = team
            conversation.team = team
            createMembership(in: uiMOC, user: selfUser, team: team)

        case .memberOfOtherTeam:
            let otherTeam = createTeam(in: uiMOC)
            createMembership(in: uiMOC, user: selfUser, team: otherTeam)

        case .personal:
            break

        case .service:
            XCTFail("Self-user cannot be a service", file: file, line: line)
        }

        for otherUserType in otherUsers {
            switch otherUserType {
            case .memberOfHostingTeam:
                if hostingTeam == nil {
                    let team = createTeam(in: uiMOC)
                    hostingTeam = team
                    conversation.team = team
                }

                let otherTeamUser = createUser(in: uiMOC)
                conversation.internalAddParticipants([otherTeamUser])
                createMembership(in: uiMOC, user: otherTeamUser, team: hostingTeam!)

            case .memberOfOtherTeam:
                let otherTeam = createTeam(in: uiMOC)
                let otherUser = createUser(in: uiMOC)
                conversation.internalAddParticipants([otherUser])
                createMembership(in: uiMOC, user: otherUser, team: otherTeam)

            case .personal:
                let otherUser = createUser(in: uiMOC)
                conversation.internalAddParticipants([otherUser])

            case .service:
                let service = createService(in: uiMOC, named: "Bob the Robot")
                conversation.internalAddParticipants([service as! ZMUser])
            }
        }

        uiMOC.saveOrRollback()
        XCTAssertEqual(conversation.externalParticipantsState, expectedResult, file: file, line: line)
    }

}
