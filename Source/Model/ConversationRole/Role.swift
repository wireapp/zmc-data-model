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
public final class Role: ZMManagedObject {
    public static let nameKey = #keyPath(Role.name)
    public static let teamKey = #keyPath(Role.team)
    public static let conversationKey = #keyPath(Role.conversation)
    public static let actionsKey = #keyPath(Role.actions)
    public static let participantRolesKey = #keyPath(Role.participantRoles)

    @NSManaged public var name: String?

    @NSManaged public var actions: Set<Action>
    @NSManaged public var participantRoles: Set<ParticipantRole>
    @NSManaged public var team: Team?
    @NSManaged public var conversation: ZMConversation?

    public override static func entityName() -> String {
        return "Role"
    }
    
    public override static func isTrackingLocalModifications() -> Bool {
        return false
    }
    
    @objc
    @discardableResult
    static public func create(managedObjectContext: NSManagedObjectContext,
                              name: String,
                              conversation: ZMConversation) -> Role {
        let entry = Role.insertNewObject(in: managedObjectContext)
        entry.name = name
        entry.conversation = conversation
        return entry
    }
    
    @objc
    @discardableResult
    static public func create(managedObjectContext: NSManagedObjectContext,
                              name: String,
                              team: Team) -> Role {
        let entry = Role.insertNewObject(in: managedObjectContext)
        entry.name = name
        entry.team = team
        return entry
    }

    @objc
    static func fetchExistingRole(with conversationRole: String, in context: NSManagedObjectContext) -> Role? {
        let fetchRequest = NSFetchRequest<Role>(entityName: Role.entityName())
        fetchRequest.predicate = NSPredicate(format: "%K == %@", Role.nameKey, conversationRole)
        fetchRequest.fetchLimit = 1
        
        return context.fetchOrAssert(request: fetchRequest).first
    }

    @discardableResult
    public static func createOrUpdate(with payload: [String: Any],
                                      team: Team?,
                                      conversation: ZMConversation,
                                      context: NSManagedObjectContext
        ) -> Role? {
        guard let conversationRole = payload["conversation_role"] as? String,
            let actionNames = payload["actions"] as? [String]
            else { return nil }
        
        let fetchedRole = fetchExistingRole(with: conversationRole, in: context)

        let role = fetchedRole ?? Role.insertNewObject(in: context)
        
        actionNames.forEach() { actionName in
            let action = Action.fetchExistingAction(with: actionName, role: role, in: context)
            
            if action == nil {
                let newAction = Action.insertNewObject(in: context)
                newAction.name = actionName
                
                role.actions.insert(newAction)
            }
            
        }

        role.team = team
        role.conversation = conversation
        role.name = conversationRole

        return role
    }
}
