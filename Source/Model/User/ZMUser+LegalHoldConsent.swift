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

extension ZMUser {

    /// The user's consent to being exposed to legal hold devices.

    public var legalHoldConsent: LegalHoldConsent {
        get {
            guard let value = LegalHoldConsent(rawValue: legalHoldConsentValue) else {
                fatalError("Failed to decode legalHoldConsentValue")
            }

            return value
        }

        set {
            legalHoldConsentValue = newValue.rawValue
        }
    }

    @NSManaged private var legalHoldConsentValue: Int16

}

/// Values describing consent to being exposed to legal hold devices.

public enum LegalHoldConsent: Int16 {

    /// The user does not consent to being exposed to legal hold devices.

    case notGiven = 0

    /// Consent has been requested from the user.

    case pending = 1

    /// The user consents to being exposed to legal hold devices.

    case given = 2
}
