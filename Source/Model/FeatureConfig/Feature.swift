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

@objcMembers
public class Feature: ZMManagedObject {
    
   public enum Status: String, Codable {
     case enabled
     case disabled
   }
    private let zmLog = ZMSLog(tag: "Feature")
    
    @NSManaged public var name: String
    @NSManaged public var config: Data?
    @NSManaged private var statusValue: String
    
    public var status: Status {
        get {
            guard let status = Status(rawValue: statusValue) else {
                fatalError("Failed to decode Feature statusValue: \(statusValue)")
            }
            return status
        }
        set {
            statusValue = newValue.rawValue
        }
    }
    
    public override static func entityName() -> String {
        return "Feature"
    }
}
