//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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


public class Member: ZMManagedObject {

    @NSManaged public var team: Team?
    @NSManaged public var user: ZMUser?

    @NSManaged private var permissionsRawValue: Int32

    public var permissions: Permissions {
        get { return Permissions(rawValue: permissionsRawValue) }
        set { permissionsRawValue = newValue.rawValue }
    }

    public override static func entityName() -> String {
        return "Member"
    }

    public override static func isTrackingLocalModifications() -> Bool {
        return false
    }

    public static func getOrCreateMember(for user: ZMUser, in team: Team, context: NSManagedObjectContext) -> Member {
        if let existing = user.membership(in: team) {
            return existing
        }

        let member = insertNewObject(in: context)
        member.team = team
        member.user = user
        return member
    }

}
