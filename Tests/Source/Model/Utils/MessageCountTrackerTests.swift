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


import Foundation
@testable import WireDataModel


private class DateCreator {
    var nextDate: Date!

    func create() -> Date {
        return nextDate
    }
}


private class MockCountFetcher: CountFetcherType {

    var callCount = 0

    func fetchNumberOfLegacyMessages(_ completion: @escaping (MessageCount) -> Void) {
        callCount += 1
    }
}


class MessageCountTrackerTests: BaseZMMessageTests {

    fileprivate var mockFetcher: MockCountFetcher!

    override func setUp() {
        super.setUp()
        mockFetcher = MockCountFetcher()
    }

    override func tearDown() {
        mockFetcher = nil
        super.tearDown()
    }


    func testThatItTracksTheMessageCountInitially() {
        // Given
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let currentDate = Date()
        let dateCreator = DateCreator()
        dateCreator.nextDate = currentDate

        guard let sut = LegacyMessageTracker(
            managedObjectContext: syncMOC,
            userDefaults: defaults,
            createDate: dateCreator.create,
            countFetcher: mockFetcher
        ) else { return XCTFail("Unable to create SUT") }

        // When
        XCTAssertNil(sut.lastTrackDate)
        XCTAssertTrue(sut.shouldTrack())
        sut.trackLegacyMessageCount()

        // Then
        XCTAssertEqual(sut.lastTrackDate, currentDate)
        XCTAssertEqual(mockFetcher.callCount, 1)
    }

    func testThatItDoesNotTrackTheMessageCountWhenItTrackedInTheLast14Days() {
        // Given
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let currentDate = Date()
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: currentDate)

        let dateCreator = DateCreator()
        dateCreator.nextDate = currentDate

        guard let sut = LegacyMessageTracker(
            managedObjectContext: syncMOC,
            userDefaults: defaults,
            createDate: dateCreator.create,
            countFetcher: mockFetcher
            ) else { return XCTFail("Unable to create SUT") }

        // When
        sut.lastTrackDate = oneWeekAgo
        XCTAssertFalse(sut.shouldTrack())
        sut.trackLegacyMessageCount()

        // Then
        XCTAssertEqual(sut.lastTrackDate, oneWeekAgo)
        XCTAssertEqual(mockFetcher.callCount, 0)
    }

    func testThatItTracksTheMessageCountWhenItTrackedTheLastTimeBeforeMoreThan14Days() {
        // Given
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let currentDate = Date()
        let fifteenDaysAgo = Calendar.current.date(byAdding: .day, value: -15, to: currentDate)

        let dateCreator = DateCreator()
        dateCreator.nextDate = currentDate

        guard let sut = LegacyMessageTracker(
            managedObjectContext: syncMOC,
            userDefaults: defaults,
            createDate: dateCreator.create,
            countFetcher: mockFetcher
            ) else { return XCTFail("Unable to create SUT") }

        // When
        sut.lastTrackDate = fifteenDaysAgo
        XCTAssertTrue(sut.shouldTrack())
        sut.trackLegacyMessageCount()

        // Then
        XCTAssertEqual(sut.lastTrackDate, currentDate)
        XCTAssertEqual(mockFetcher.callCount, 1)
    }

}

