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

import Foundation
import XCTest
@testable import WireDataModel

class ZMConversationMentionsTests: ZMConversationTestsBase {

    var conversation: ZMConversation!

    override func setUp() {
        super.setUp()
        conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.remoteIdentifier = UUID()
        uiMOC.saveOrRollback()
    }

    override func tearDown() {
        uiMOC.zm_fileAssetCache.wipeCaches()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        conversation = nil
        super.tearDown()
    }

    func testThatItCategorizesUsersCorrectly() {

        let regularUser1 = ZMUser.insertNewObject(in: uiMOC)
        regularUser1.remoteIdentifier = UUID.create()

        let regularUser2 = ZMUser.insertNewObject(in: uiMOC)
        regularUser2.remoteIdentifier = UUID.create()

        let serviceUser1 = ZMUser.insertNewObject(in: uiMOC)
        serviceUser1.serviceIdentifier = UUID.create().transportString()
        serviceUser1.providerIdentifier = UUID.create().transportString()

        let serviceUser2 = ZMUser.insertNewObject(in: uiMOC)
        serviceUser2.serviceIdentifier = UUID.create().transportString()
        serviceUser2.providerIdentifier = UUID.create().transportString()

        let users: Set<ZMUser> = [regularUser1, regularUser2, serviceUser1, serviceUser2]
        let (services, regularUsers) = conversation.categorizeUsers(in: users)

        XCTAssertEqual(regularUsers.count, 2)
        XCTAssertEqual(services.count, 2)

        XCTAssertEqual(regularUsers, [regularUser1, regularUser2])
        XCTAssertEqual(services, [serviceUser1, serviceUser2])

    }

    func testThatItDetectsServiceMentions() {

        let regularUser1 = ZMUser.insertNewObject(in: uiMOC)
        regularUser1.remoteIdentifier = UUID.create()

        let regularUser2 = ZMUser.insertNewObject(in: uiMOC)
        regularUser2.remoteIdentifier = UUID.create()

        let serviceUser1 = ZMUser.insertNewObject(in: uiMOC)
        serviceUser1.remoteIdentifier = UUID.create()
        serviceUser1.serviceIdentifier = UUID.create().transportString()
        serviceUser1.providerIdentifier = UUID.create().transportString()
        serviceUser1.name = "GitHub"

        let serviceUser2 = ZMUser.insertNewObject(in: uiMOC)
        serviceUser2.remoteIdentifier = UUID.create()
        serviceUser2.name = "Wire"
        serviceUser2.serviceIdentifier = UUID.create().transportString()
        serviceUser2.providerIdentifier = UUID.create().transportString()

        conversation.conversationType = .group
        conversation.addParticipants([regularUser1, regularUser2, serviceUser1, serviceUser2])

        let botMentions = Set(conversation.mentions(in: "@bots Hello"))
        let expectedMentions = Set(ZMMentionBuilder.build([serviceUser1, serviceUser2]))
        XCTAssertEqual(botMentions, expectedMentions)

        let noBotMentions = conversation.mentions(in: "Hello")
        XCTAssertTrue(noBotMentions.isEmpty)

    }

}
