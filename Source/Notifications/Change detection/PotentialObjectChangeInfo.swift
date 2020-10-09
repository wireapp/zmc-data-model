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

public class PotentialObjectChangeInfo {

    let object: NSObject
    let changes: Changes

    init(object: NSObject, changes: Changes) {
        self.object = object
        self.changes = changes
    }

}

extension PotentialObjectChangeInfo {

    public struct Changes: OptionSet {

        static let none = Changes(rawValue: 0 << 0)
        static let updated = Changes(rawValue: 0 << 1)
        static let inserted = Changes(rawValue: 0 << 2)
        static let deleted = Changes(rawValue: 0 << 3)

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

    }

}
