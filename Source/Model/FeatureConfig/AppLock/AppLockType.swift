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
import LocalAuthentication

/// An app lock abstraction.

public protocol AppLockType {

    var delegate: AppLockDelegate? { get set }

    /// Whether the app lock feature is availble to the user.

    var isAvailable: Bool { get }

    /// Whether the app lock on.

    var isActive: Bool { get set }

    /// Whether the app lock is mandatorily active.

    var isForced: Bool { get }

    /// The maximum number of seconds allowed in the background before the
    /// authentication is required.

    var timeout: UInt { get }

    /// Whether the app lock is currently locked.

    var isLocked: Bool { get }

    // TODO: revisit this. It's purpose is to communicate that
    // the preferred passcode is custom not device.

    var requiresBiometrics: Bool { get }

    // TODO: Rename to "isCustomPasscodeSet"
    /// Whether a custom passcode has been set.

    var isCustomPasscodeNotSet: Bool { get }

    /// Whether the user needs to be informed about configuration changes.

    var needsToNotifyUser: Bool { get set }

    /// Delete the stored passcode.

    func deletePasscode() throws

    /// Update the stored passcode.

    func updatePasscode(_ passcode: String) throws

    /// Open the app lock.

    func open() throws

    // TODO: document

    func evaluateAuthentication(passcodePreference: AppLockPasscodePreference,
                                description: String,
                                context: LAContextProtocol,
                                callback: @escaping (AppLockController.AuthenticationResult, LAContextProtocol) -> Void)

    // TODO: Document

    func evaluateAuthentication(customPasscode: String) -> AppLockController.AuthenticationResult

}

public extension AppLockType {

    func evaluateAuthentication(passcodePreference: AppLockPasscodePreference,
                                description: String,
                                callback: @escaping (AppLockController.AuthenticationResult, LAContextProtocol) -> Void) {

        evaluateAuthentication(passcodePreference: passcodePreference,
                               description: description,
                               context: LAContext(),
                               callback: callback)
    }
}
