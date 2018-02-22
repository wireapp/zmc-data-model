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

public struct ConversationAccessMode: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let invite    = ConversationAccessMode(rawValue: 1 << 0)
    public static let code      = ConversationAccessMode(rawValue: 1 << 1)
    public static let `private` = ConversationAccessMode(rawValue: 1 << 2)
    
    public static let legacy    = invite
    public static let teamOnly  = ConversationAccessMode()
    public static let allowGuests: ConversationAccessMode = [.invite, .code]
}

extension ConversationAccessMode: Hashable {
    public var hashValue: Int {
        return self.rawValue
    }
}

public extension ConversationAccessMode {
    internal static let stringValues: [ConversationAccessMode: String] = [.invite: "invite",
                                                                          .code:   "code",
                                                                          .`private`: "private"]

    public var stringValue: [String] {
        return ConversationAccessMode.stringValues.flatMap { self.contains($0) ? $1 : nil }
    }
    
    public init(values: [String]) {
        var result = ConversationAccessMode()
        ConversationAccessMode.stringValues.forEach {
            if values.contains($1) {
                result.formUnion($0)
            }
        }
        self = result
    }
}

public extension ZMConversation {
    @NSManaged @objc dynamic internal var accessModeStrings: [String]?
    
    public var allowGuests: Bool {
        get {
            return accessMode != .teamOnly
        }
        set {
            accessMode = newValue ? .allowGuests : .teamOnly
            // TODO: set access role
        }
    }
    
    // The conversation access mode is stored as comma separated string in CoreData, cf. `acccessModeStrings`.
    public var accessMode: ConversationAccessMode? {
        get {
            guard let strings = self.accessModeStrings else {
                return nil
            }

            return ConversationAccessMode(values: strings)
        }
        set {
            guard let value = newValue else {
                accessModeStrings = nil
                return
            }
            accessModeStrings = value.stringValue
        }
    }
    
}

