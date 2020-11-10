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

import XCTest
@testable import WireDataModel


class ZMUserTests_AnalyticsIdentifier: ModelObjectsTests {

    func testTheAnalyticsIdentifierIsAutomaticallyGenerated() {
        // Given
        let sut = createUser(selfUser: true, inTeam: true)

        // Then
        XCTAssertNotNil(sut.analyticsIdentifier)
    }

    func testTheAnalyticsIdentifierIsNotAutomaticallyGenerated() {
        // Given, then
        XCTAssertNil(createUser(selfUser: true, inTeam: false).analyticsIdentifier)
        XCTAssertNil(createUser(selfUser: false, inTeam: false).analyticsIdentifier)
        XCTAssertNil(createUser(selfUser: false, inTeam: true).analyticsIdentifier)
    }

    func testTheAnalyticsIdentifierIsNotRegeneratedIfAValueExists() {
        // Given
        let sut = createUser(selfUser: true, inTeam: true)
        let existingIdentifier = sut.analyticsIdentifier
        XCTAssertNotNil(existingIdentifier)

        // Then
        XCTAssertEqual(sut.analyticsIdentifier, existingIdentifier)
    }

    func testTheAnalyticsIdentifierIsEncodedAsUUIDTransportString() {
        // Given
        let sut = createUser(selfUser: true, inTeam: true)

        // Then
        XCTAssertNotNil(sut.analyticsIdentifier)
        XCTAssertNotNil(UUID(uuidString: sut.analyticsIdentifier!))
    }

    // MARK: - Helpers

    private func createUser(selfUser: Bool, inTeam: Bool) -> ZMUser {
        let user = selfUser ? self.selfUser! : createUser(in: uiMOC)
        guard inTeam else { return user }
        createMembership(in: uiMOC, user: user, team: createTeam(in: uiMOC))
        return user
    }
    
}
