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

import Foundation
import XCTest
@testable import WireDataModel

class SelfUserParticipantMigrationTests: DiskDatabaseTest {
    
    override func setUp() {
        super.setUp()
        
        // Batch update doesn't inform the MOC of any changes so we disable caching in order to fetch directly from the store
        moc.stalenessInterval = 0.0
    }
    
    func testMigrationIsSelfAnActiveMemberToTheParticipantRoles() {
        // Given
        let conversation = createConversation()
        conversation.isSelfAnActiveMember = true
        self.moc.saveOrRollback()
        
        // When
        WireDataModel.ZMConversation.migrateIsSelfAnActiveMemberToTheParticipantRoles(in: moc)
        
        // Then
        let hasSelfUser = conversation.participantRoles.contains(where: { (role) -> Bool in
            role.user.isSelfUser == true
        })
        XCTAssertTrue(hasSelfUser)
    }
}
