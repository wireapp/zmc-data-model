//
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

@objcMembers
public class Role: ZMManagedObject {
    
    @NSManaged public var name: String?

    @NSManaged public var actions: Set<Action>
    @NSManaged public var participantRoles: Set<ParticipantRole>
    @NSManaged public var team: Team

    public override static func entityName() -> String {
        return "Role"
    }    
}
