//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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

class ZMConversationUniquingTests: ZMBaseManagedObjectTest {

    func testThatItKeepsOnlySingleConversationWithSameRemoteIdentifier() {
        // GIVEN
        let uuid = UUID()
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.remoteIdentifier = uuid

        // WHEN
        let other = ZMConversation.insertNewObject(in: self.uiMOC)
        other.remoteIdentifier = uuid
        self.uiMOC.saveOrRollback()
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        let fetch = NSFetchRequest<ZMConversation>(entityName: ZMConversation.entityName())
        let uuidData = (uuid as NSUUID).data() as NSData
        fetch.predicate = NSPredicate(format: "%K == %@", ZMConversation.remoteIdentifierDataKey()!, uuidData)
        let found = self.uiMOC.fetchOrAssert(request: fetch)

        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.remoteIdentifier, uuid)

    }
}
