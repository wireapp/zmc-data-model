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

private var zmLog = ZMSLog(tag: "DisplayNameGenerator")


@objcMembers public class DisplayNameGenerator : NSObject {
    private var idToPersonNameMap : [NSManagedObjectID: PersonName] = [:]
    weak private var managedObjectContext: NSManagedObjectContext?
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init()
    }
    
    // MARK : Accessors

    public func personName(for user: ZMUser) -> PersonName {
        if user.objectID.isTemporaryID {
            try! managedObjectContext!.obtainPermanentIDs(for: [user])
        }
        if let name = idToPersonNameMap[user.objectID], name.rawFullName == (user.name ?? "") {
            return name
        }
        let newName = PersonName.person(withName: user.name ?? "", schemeTagger: nil)
        idToPersonNameMap[user.objectID] = newName
        return newName
    }
    
    public func givenName(for user: ZMUser) -> String? {
        return personName(for: user).givenName
    }
    
    public func initials(for user: ZMUser) -> String? {
        return personName(for: user).initials
    }
}
