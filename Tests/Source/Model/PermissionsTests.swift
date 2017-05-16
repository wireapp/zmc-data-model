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


class PermissionsTests: BaseZMClientMessageTests {

    private let allPermissions: Permissions = [
        .createConversation,
        .deleteConversation,
        .addTeamMember,
        .removeTeamMember,
        .addConversationMember,
        .removeConversationMember,
        .getBilling,
        .setBilling,
        .setTeamData
    ]

    func testThatDefaultValueDoesNotHaveAnyPermissions() {
        // given
        let sut = Permissions(rawValue: 0)

        // then
        XCTAssertFalse(sut.contains(.createConversation))
        XCTAssertFalse(sut.contains(.deleteConversation))
        XCTAssertFalse(sut.contains(.addTeamMember))
        XCTAssertFalse(sut.contains(.removeTeamMember))
        XCTAssertFalse(sut.contains(.addConversationMember))
        XCTAssertFalse(sut.contains(.removeConversationMember))
        XCTAssertFalse(sut.contains(.getBilling))
        XCTAssertFalse(sut.contains(.setBilling))
        XCTAssertFalse(sut.contains(.setTeamData))
    }

    func testMemberPermissions() {
        XCTAssertEqual(Permissions.member, [.createConversation, .deleteConversation, .addConversationMember, .removeConversationMember])
    }

    func testAdminPermissions() {
        // given
        let adminPermissions: Permissions = [
            .createConversation,
            .deleteConversation,
            .addConversationMember,
            .removeConversationMember,
            .addTeamMember,
            .removeTeamMember
        ]

        // then
        XCTAssertEqual(Permissions.admin, adminPermissions)
    }

    func testOwnerPermissions() {
        XCTAssertEqual(Permissions.owner, allPermissions)
    }

    // MARK: - Transport Data

    func testThatItCreatesPermissionsFromStrings() {
        XCTAssertNil(Permissions(string: ""))
        XCTAssertEqual(Permissions(string: "CreateConversation"), .createConversation)
        XCTAssertEqual(Permissions(string: "DeleteConversation"), .deleteConversation)
        XCTAssertEqual(Permissions(string: "AddTeamMember"), .addTeamMember)
        XCTAssertEqual(Permissions(string: "RemoveTeamMember"), .removeTeamMember)
        XCTAssertEqual(Permissions(string: "AddConversationMember"), .addConversationMember)
        XCTAssertEqual(Permissions(string: "RemoveConversationMember"), .removeConversationMember)
        XCTAssertEqual(Permissions(string: "GetBilling"), .getBilling)
        XCTAssertEqual(Permissions(string: "SetBilling"), .setBilling)
        XCTAssertEqual(Permissions(string: "SetTeamData"), .setTeamData)
        XCTAssertEqual(Permissions(string: "Member"), .member)
        XCTAssertEqual(Permissions(string: "Admin"), .admin)
        XCTAssertEqual(Permissions(string: "Owner"), .owner)
    }

    func testThatItCreatesPermissionsFromPayload() {
        XCTAssertEqual(Permissions(payload: ["CreateConversation"]), .createConversation)
        XCTAssertEqual(Permissions(payload: ["CreateConversation", "DeleteConversation"]), [.createConversation, .deleteConversation])
        XCTAssertEqual(Permissions(payload: ["Admin"]), .admin)
        XCTAssertEqual(Permissions(payload: ["Admin", "Owner"]), .owner)
    }

    func testThatItCreatesEmptyPermissionsFromEmptyPayload() {
        XCTAssertEqual(Permissions(payload: []), [])
    }

    // MARK: - Objective-C Interoperability

    func testThatItCreatesTheCorrectSwiftPermissions() {
        XCTAssertEqual(PermissionsObjC.member.permissions, .member)
        XCTAssertEqual(PermissionsObjC.admin.permissions, .admin)
        XCTAssertEqual(PermissionsObjC.owner.permissions, .owner)
    }

    func testThatItSetsObjectiveCPermissions() {
        // given
        let member = Member.insertNewObject(in: uiMOC)

        // when
        member.setPermissionsObjC(.admin)

        // then
        XCTAssertEqual(member.permissions, .admin)
    }

}
