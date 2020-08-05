////
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

class ManagedObjectContextDirectoryTests: DatabaseBaseTest {

    func testThatItStoresAndClearsDatabaseKeyOnAllContexts() {
        // Given
        let sut = createStorageStackAndWaitForCompletion()
        let databaseKey = "abc".data(using: .utf8)!

        // When
        sut.storeDatabaseKeyInAllContexts(databaseKey: databaseKey)

        // Then
        XCTAssertEqual(sut.uiContext.databaseKey, databaseKey)
        XCTAssertEqual(sut.syncContext.databaseKey, databaseKey)
        XCTAssertEqual(sut.searchContext.databaseKey, databaseKey)

        // When
        sut.clearDatabaseKeyInAllContexts()

        // Then
        XCTAssertNil(sut.uiContext.databaseKey)
        XCTAssertNil(sut.syncContext.databaseKey)
        XCTAssertNil(sut.searchContext.databaseKey)
    }

}
