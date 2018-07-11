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

final class PushTokenTests: XCTestCase {

    var sut: PushToken!
    
    override func setUp() {
        sut = PushToken(deviceToken: Data(bytes: [0x01, 0x02, 0x03]), appIdentifier: "some", transportType: "some", isRegistered: true)

        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testThatTokenIsEncodedProperly() {
        XCTAssertEqual(sut.deviceTokenString, "010203")
    }

    func testThatItReturnsCopyMarkedForDownload() {
        let toDownload = sut.markToDownload()
        XCTAssertFalse(sut.isMarkedForDownload)
        XCTAssertTrue(toDownload.isMarkedForDownload)
    }

    func testThatItReturnsCopyMarkedForDelete() {
        let toDelete = sut.markToDelete()
        XCTAssertFalse(sut.isMarkedForDeletion)
        XCTAssertTrue(toDelete.isMarkedForDeletion)
    }

    func testThatItResetsFlags() {
        let toDelete = sut.markToDelete()
        let toDownload = toDelete.markToDownload()
        let reset = toDownload.resetFlags()

        XCTAssertTrue(toDelete.isMarkedForDeletion)
        XCTAssertFalse(toDelete.isMarkedForDownload)

        XCTAssertTrue(toDownload.isMarkedForDownload)
        XCTAssertTrue(toDownload.isMarkedForDownload)

        XCTAssertFalse(reset.isMarkedForDownload)
        XCTAssertFalse(reset.isMarkedForDownload)
    }

    func testThatItCanBeInitializedFromLegacyToken() {
        let legacyToken = ZMPushToken(deviceToken: sut.deviceToken, identifier: sut.appIdentifier, transportType: sut.transportType, isRegistered: sut.isRegistered, isMarkedForDeletion: sut.isMarkedForDeletion)

        let pushToken = PushToken(pushToken: legacyToken)

        XCTAssertEqual(pushToken.deviceToken, sut.deviceToken)
        XCTAssertEqual(pushToken.appIdentifier, sut.appIdentifier)
        XCTAssertEqual(pushToken.transportType, sut.transportType)
        XCTAssertEqual(pushToken.isRegistered, sut.isRegistered)
        XCTAssertEqual(pushToken.isMarkedForDeletion, sut.isMarkedForDeletion)

        // We need to re-download it to make sure it is still valid
        XCTAssertTrue(pushToken.isMarkedForDownload)
    }
}
