////
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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
    public struct RichProfileField: Codable, Equatable {
        public var type: String
        public var value: String
        public init(type: String, value: String) {
            self.type = type
            self.value = value
        }
    }
    
    private enum Keys {
        static let RichProfile = "richProfile"
    }
    
    @NSManaged private  var primitiveRichProfile: Data?
    public var richProfile: [RichProfileField] {
        get {
            self.willAccessValue(forKey: Keys.RichProfile)
            let fields: [RichProfileField]
            if let data = primitiveRichProfile {
                fields = (try? JSONDecoder().decode([RichProfileField].self, from:data)) ?? []
            } else {
                fields = []
            }
            self.didAccessValue(forKey: Keys.RichProfile)
            return fields
        }
        set {
            if newValue != richProfile {
                self.willChangeValue(forKey: Keys.RichProfile)
                primitiveRichProfile = try? JSONEncoder().encode(newValue)
                self.didChangeValue(forKey: Keys.RichProfile)
            }
        }
    }
}
