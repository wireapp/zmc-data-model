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

/// A type that can be used an attribute value.

public protocol AnalyticsAttributeValue {

    /// The string representation of the value.

    var analyticsValue: String { get }

}

extension UUID: AnalyticsAttributeValue {

    public var analyticsValue: String {
        return transportString()
    }

}

extension Int: AnalyticsAttributeValue {

    public var analyticsValue: String {
        return String(describing: self)
    }

}

extension String: AnalyticsAttributeValue {

    public var analyticsValue: String {
        return self
    }

}

extension TeamRole: AnalyticsAttributeValue {

    public var analyticsValue: String {
        switch self {
            case .member, .admin, .owner:
                return "member"
            case .partner:
                return "external"
            case .none:
                return "wireless"
        }
    }

}
