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

import XCTest
@testable import WireDataModel

class ZMMessageTests_SystemMessages: BaseZMMessageTests {

    func testThatOnlyRecoverableDecryptionErrorsAreReportedAsRecoverable() throws {
        let allEncryptionErrors = [
            CBOX_STORAGE_ERROR,
            CBOX_SESSION_NOT_FOUND,
            CBOX_DECODE_ERROR,
            CBOX_REMOTE_IDENTITY_CHANGED,
            CBOX_INVALID_SIGNATURE,
            CBOX_INVALID_MESSAGE,
            CBOX_DUPLICATE_MESSAGE,
            CBOX_TOO_DISTANT_FUTURE,
            CBOX_OUTDATED_MESSAGE,
            CBOX_UTF8_ERROR,
            CBOX_NUL_ERROR,
            CBOX_ENCODE_ERROR,
            CBOX_IDENTITY_ERROR,
            CBOX_PREKEY_NOT_FOUND,
            CBOX_PANIC,
            CBOX_INIT_ERROR,
            CBOX_DEGENERATED_KEY
        ]
        
        let recoverableEncryptionErrors = [
            CBOX_TOO_DISTANT_FUTURE,
            CBOX_DEGENERATED_KEY,
            CBOX_PREKEY_NOT_FOUND
        ]
        
        for encryptionError in allEncryptionErrors {
            assertDecryptionErrorIsReportedAsRecoverable(
                encryptionError,
                recoverable: recoverableEncryptionErrors.contains(encryptionError))
        }
    }
    
    private func assertDecryptionErrorIsReportedAsRecoverable(_ decryptionError: CBoxResult,
                                                              recoverable: Bool,
                                                              file: StaticString = #file,
                                                              line: UInt = #line) {
        // given
        let systemMessage = ZMSystemMessage(nonce: UUID(), managedObjectContext: uiMOC)
        systemMessage.systemMessageType = .decryptionFailed
        systemMessage.decryptionErrorCode = NSNumber(value: decryptionError.rawValue)
        
        // then
        XCTAssertEqual(systemMessage.isDecryptionErrorRecoverable, recoverable, file: file, line: line)
    }

}
