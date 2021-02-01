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

/// A type able to record analytic events.

public protocol AnalyticsLike {

    /// Record the given event.

    func tagEvent(_ event: AnalyticsEvent)

}

/// An event to be recorded for analytical purposes.

public struct AnalyticsEvent {

    /// The unique name of the event.

    public let name: String

    /// Additional data associated with the event.

    public var attributes: AnalyticsAttributes

    /// Create an event with the given name and attributes.

    public init(name: String, attributes: AnalyticsAttributes = [:]) {
        self.name = name
        self.attributes = attributes
    }

}

public typealias AnalyticsAttributes = [AnalyticsAttributeKey: AnalyticsAttributeValue]

public extension AnalyticsAttributes {

    var rawValue: [String: String] {
        return mapKeys(\.rawValue).mapValues(\.rawValue)
    }

}

/// A key denoting a particular analytics attribute.

public struct AnalyticsAttributeKey: Hashable {

    /// The unique string describing the key.

    public let rawValue: String

    /// Create a key with the given raw value.

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

}

/// A type that can be used an attribute value.

public protocol AnalyticsAttributeValue {

    /// The string representation of the value.

    var rawValue: String { get }

}
