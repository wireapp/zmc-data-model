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

public let ZMParticipantRoleRoleValueKey      = "role"
public let ZMParticipantRoleMarkedToDeleteKey = "markedToDelete"
public let ZMParticipantRoleMarkedToInsertKey = "markedToInsert"

@objcMembers
public class ParticipantRole: ZMManagedObject {
    
    @NSManaged public var markedForDelete: Bool
    @NSManaged public var markedForInsert: Bool
    
    @NSManaged public var conversation: ZMConversation
    @NSManaged public var user: ZMUser
    @NSManaged public var role: Role

    public override static func entityName() -> String {
        return "ParticipantRole"
    }
    
    public override static func isTrackingLocalModifications() -> Bool {
        return true
    }
    
    open override func keysTrackedForLocalModifications() -> Set<String> {
        return [ZMParticipantRoleRoleValueKey,
                ZMParticipantRoleMarkedToDeleteKey,
                ZMParticipantRoleMarkedToInsertKey]
    }
    
    @objc
    static public func create(managedObjectContext: NSManagedObjectContext, user: ZMUser) -> ParticipantRole {
        let entry = ParticipantRole.insertNewObject(in: managedObjectContext)
        entry.user = user
        
        ///TODO: other flags init value?
        return entry
    }
}

