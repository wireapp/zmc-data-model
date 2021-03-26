//
// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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

class CoreDataStackTests_ClearStorage: ZMTBaseTest {

    let account: Account = Account(userName: "", userIdentifier: UUID())

    var applicationContainer: URL {
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("CoreDataStackTests")
    }

    func testThatStorageIsCleared_WhenUpgradingFromLegacyInstallation() {
        // given
        let existingFiles = createFilesInLegacyLocations()

        // when
        _ = CoreDataStack(account: account,
                          applicationContainer: applicationContainer,
                          inMemoryStore: false,
                          dispatchGroup: dispatchGroup)

        // then
        for file in existingFiles {
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path),
                           "\(file.path) should have been deleted")
        }
    }

    func testThatStorageIsNotCleared_WhenUpgradingFromSupportedInstallation() throws {
        // given
        let existingFiles = createFilesInLegacyLocations()
        try createAccountFolder()

        // when
        _ = CoreDataStack(account: account,
                          applicationContainer: applicationContainer,
                          inMemoryStore: false,
                          dispatchGroup: dispatchGroup)

        // then
        for file in existingFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path),
                           "\(file.path) should not have been deleted")
        }
    }

    // MARK: Helpers

    func createAccountFolder() throws {
        let accountFolder = CoreDataStack.accountFolder(accountIdentifier: account.userIdentifier,
                                                        applicationContainer: applicationContainer)

        try FileManager.default.createDirectory(at: accountFolder,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
    }

    func createFilesInLegacyLocations() -> [URL] {
        return previousStorageLocations.map { (location) -> URL in
            let fileManager = FileManager.default
            try? fileManager.createDirectory(at: location,
                                            withIntermediateDirectories: true,
                                            attributes: nil)


            let file = location.appendingPathComponent("file.bin", isDirectory: false)

            let success = fileManager.createFile(atPath: file.path,
                                                 contents: "hello".data(using: .utf8)!,
                                                 attributes: nil)

            XCTAssertTrue(success)

            return file
        }
        
    }

    /// Previous storage locations for the persistent store or key store
    var previousStorageLocations: [URL] {
        let accountID = account.userIdentifier.uuidString
        let bundleID = Bundle.main.bundleIdentifier!

        return [
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!,
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!,
            applicationContainer,
            applicationContainer.appendingPathComponent(bundleID),
            applicationContainer.appendingPathComponent(bundleID).appendingPathComponent(accountID),
            applicationContainer.appendingPathComponent(bundleID).appendingPathComponent(accountID).appendingPathComponent("store")
        ]
    }

}
