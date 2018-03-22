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

class BackupMetadataTests: XCTest {
    
    var url: URL!
    
    override func setUp() {
        super.setUp()
        let documentsURL = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        url = URL(fileURLWithPath: documentsURL).appendingPathComponent(name!)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        url = nil
        super.tearDown()
    }
    
    func testThatItWritesMetadataToURL() throws {
        // Given
        let date = Date()
        let userIdentifier = UUID.create()
        let clientIdentifier = UUID.create().transportString()
        let sut = BackupMetadata(
            appVersion: "3.9",
            modelVersion: "24.2.8",
            creationTime: date,
            userIdentifier: userIdentifier,
            clientIdentifier: clientIdentifier
        )
        
        // When & Then
        try sut.write(to: url)
        XCTAssert(FileManager.default.fileExists(atPath: url.path))
    }
    
    func testThatItReadsMetadataFromURL() throws {
        // Given
        let date = Date()
        let userIdentifier = UUID.create()
        let clientIdentifier = UUID.create().transportString()
        let sut = BackupMetadata(
            appVersion: "3.9",
            modelVersion: "24.2.8",
            creationTime: date,
            userIdentifier: userIdentifier,
            clientIdentifier: clientIdentifier
        )
        
        try sut.write(to: url)
        
        // When
        let decoded = try BackupMetadata(url: url)
        
        // Then
        XCTAssert(decoded == sut)
    }
    
    func testThatItVerifiesValidMetadata() {
        XCTFail()
    }
    
    func testThatItThrowsAnErrorForNewerAppVersionBackupVerification() {
        XCTFail()
    }
    
    func testThatItThrowsAnErrorForWrongUser() {
        XCTFail()
    }
    
    func testThatItThrowsAnErrorForWrongUserClient() {
        XCTFail()
    }
    
    func testThatItThrowsAnErrorForNoUserRemoteIdentifier() {
        XCTFail()
    }
    
    func testThatItThrowsAnErrorForNoUserClientRemoteIdentifier() {
        XCTFail()
    }
    
}
