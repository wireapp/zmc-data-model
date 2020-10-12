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

import Foundation
import XCTest
@testable import WireDataModel

final class PotentialChangeDetectorTests: BaseZMMessageTests {

    typealias Sut = PotentialChangeDetector

    // MARK: - Helpers

    func createObject() -> ZMManagedObject {
        return ZMConversation.insertNewObject(in: uiMOC)
    }

    // MARK: - Tests

    func test_it_consumes_changes() {
        // Given
        let sut = Sut()
        sut.detectChanges(for: ModifiedObjects(inserted: [createObject()]))

        // When
        let changes = sut.consumeChanges()
        let moreChanges = sut.consumeChanges()

        // Then
        XCTAssertFalse(changes.isEmpty)
        XCTAssertTrue(moreChanges.isEmpty)
    }

    func test_it_resets() {
        // Given
        let sut = Sut()
        sut.detectChanges(for: ModifiedObjects(inserted: [createObject()]))

        // When
        sut.reset()

        // Then
        let changes = sut.consumeChanges()
        XCTAssertTrue(changes.isEmpty)
    }

    func test_it_detects_modified_objects() {
        // Given
        let sut = Sut()
        let updatedObject = createObject()
        let refreshedObject = createObject()
        let insertedObject = createObject()
        let deletedObject = createObject()

        let modifiedObjects = ModifiedObjects(
            updated: [updatedObject],
            refreshed: [refreshedObject],
            inserted: [insertedObject],
            deleted: [deletedObject]
        )

        // When
        sut.detectChanges(for: modifiedObjects)

        // Then
        let changes = sut.consumeChanges().compactMap(\.potentialChanges)

        XCTAssertEqual(changes.count, 4)
        XCTAssertTrue(changes.contains(.init(object: updatedObject, changes: .updated)))
        XCTAssertTrue(changes.contains(.init(object: refreshedObject, changes: .updated)))
        XCTAssertTrue(changes.contains(.init(object: insertedObject, changes: .inserted)))
        XCTAssertTrue(changes.contains(.init(object: deletedObject, changes: .deleted)))
    }

    func test_it_accumulates_detected_changes() {
        // Given
        let sut = Sut()
        let object1 = createObject()
        let object2 = createObject()
        let object3 = createObject()
        let object4 = createObject()

        // When
        sut.detectChanges(for:
            ModifiedObjects(
                updated: [object1],
                refreshed: [object2],
                inserted: [object3],
                deleted: [object4]
            )
        )

        sut.detectChanges(for:
            ModifiedObjects(
                updated: [object4],
                refreshed: [object3],
                inserted: [object2],
                deleted: [object1]
            )
        )

        // Then
        let changes = sut.consumeChanges().compactMap(\.potentialChanges)

        XCTAssertEqual(changes.count, 4)
        XCTAssertTrue(changes.contains(.init(object: object1, changes: [.updated, .deleted])))
        XCTAssertTrue(changes.contains(.init(object: object2, changes: [.updated, .inserted])))
        XCTAssertTrue(changes.contains(.init(object: object3, changes: [.inserted, .updated])))
        XCTAssertTrue(changes.contains(.init(object: object4, changes: [.deleted, .updated])))
    }

    func test_it_adds_changes() {
        // Given
        let sut = Sut()
        let object1 = createObject()

        // When
        // Changed keys are irrelevant because we're only interested that there was a change.
        sut.add(changes: Changes(changedKeys: []), for: object1)

        // Then
        let changes = sut.consumeChanges().compactMap(\.potentialChanges)

        XCTAssertEqual(changes.count, 1)
        XCTAssertTrue(changes.contains(.init(object: object1, changes: .updated)))
    }


}

extension PotentialObjectChangeInfo: Equatable {

    public static func == (lhs: PotentialObjectChangeInfo, rhs: PotentialObjectChangeInfo) -> Bool {
        return lhs.object === rhs.object && lhs.changes == rhs.changes
    }

}
