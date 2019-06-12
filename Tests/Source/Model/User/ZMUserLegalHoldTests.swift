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
import WireDataModel

class ZMUserLegalHoldTests: ModelObjectsTests {

    func testThatLegalHoldStatusIsDisabled_ByDefault() {
        // GIVEN
        let selfUser = ZMUser.selfUser(in: uiMOC)

        // THEN
        XCTAssertEqual(selfUser.legalHoldStatus, .disabled)
    }

    func testThatLegalHoldStatusIsPending_AfterReceivingRequest() {
        // GIVEN
        let selfUser = ZMUser.selfUser(in: uiMOC)

        // WHEN
        let request = LegalHoldRequest.mockRequest(for: selfUser)
        selfUser.userDidReceiveLegalHoldRequest(request)

        let legalHoldClient = UserClient.insertNewObject(in: uiMOC)
        legalHoldClient.deviceClass = .legalHold
        legalHoldClient.type = .legalHold
        legalHoldClient.user = selfUser

        selfUser.userDidAcceptLegalHoldRequest(request)

        // THEN
        XCTAssertEqual(selfUser.legalHoldStatus, .enabled)
    }

    func testThatLegalHoldStatusIsEnabled_AfterAcceptingRequest() {
        // GIVEN
        let selfUser = ZMUser.selfUser(in: uiMOC)

        // WHEN
        let request = LegalHoldRequest.mockRequest(for: selfUser)
        selfUser.userDidReceiveLegalHoldRequest(request)

        // THEN
        XCTAssertEqual(selfUser.legalHoldStatus, .pending(request))
    }

    func testThatItDoesntClearPendingStatus_AfterAcceptingWrongRequest() {
        // GIVEN
        let selfUser = ZMUser.selfUser(in: uiMOC)

        let otherUser = ZMUser.insert(in: uiMOC, name: "Bob the Other User")
        otherUser.remoteIdentifier = UUID()

        // WHEN
        let selfRequest = LegalHoldRequest.mockRequest(for: selfUser)
        selfUser.userDidReceiveLegalHoldRequest(selfRequest)

        let otherRequest = LegalHoldRequest.mockRequest(for: otherUser)
        selfUser.userDidReceiveLegalHoldRequest(otherRequest)
        selfUser.userDidAcceptLegalHoldRequest(otherRequest)

        // THEN
        XCTAssertFalse(selfRequest == otherRequest)
        XCTAssertEqual(selfUser.legalHoldStatus, .pending(selfRequest))
    }


    func testThatLegalHoldStatusIsEnabled_AfterAddingClient() {
        // GIVEN
        let selfUser = ZMUser.selfUser(in: uiMOC)

        // WHEN
        let legalHoldClient = UserClient.insertNewObject(in: uiMOC)
        legalHoldClient.deviceClass = .legalHold
        legalHoldClient.type = .legalHold
        legalHoldClient.user = selfUser

        // THEN
        XCTAssertEqual(selfUser.legalHoldStatus, .enabled)
    }

}


extension LegalHoldRequest {

    static func mockRequest(for user: ZMUser) -> LegalHoldRequest {
        if user.remoteIdentifier == nil {
            XCTFail()
            return LegalHoldRequest(requesterIdentifier: UUID(), targetUserIdentifier: UUID(), clientIdentifier: UUID(), lastPrekey: Data())
        }

        return LegalHoldRequest(requesterIdentifier: UUID(), targetUserIdentifier: user.remoteIdentifier!, clientIdentifier: UUID(), lastPrekey: Data())
    }

}
