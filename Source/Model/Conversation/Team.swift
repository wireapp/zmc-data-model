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


public protocol TeamType {

    var conversations: Set<ZMConversation> { get }
    var name: String? { get }
    var teamPictureAssetKey: String? { get }
    var isActive: Bool { get set }
    var remoteIdentifier: UUID? { get }

}


public class Team: ZMManagedObject, TeamType {

    @NSManaged public var conversations: Set<ZMConversation>
    @NSManaged public var members: Set<Member>
    @NSManaged public var name: String?
    @NSManaged public var teamPictureAssetKey: String?
    @NSManaged public var isActive: Bool

    @NSManaged private var remoteIdentifier_data: Data?

    public var remoteIdentifier: UUID? {
        get { return remoteIdentifier_data.flatMap { NSUUID(uuidBytes: $0.withUnsafeBytes(UnsafePointer<UInt8>.init)) } as UUID? }
        set { remoteIdentifier_data = (newValue as NSUUID?)?.data() }
    }

    public override static func entityName() -> String {
        return "Team"
    }

    override public static func sortKey() -> String {
        return #keyPath(Team.name)
    }

    public override static func isTrackingLocalModifications() -> Bool {
        return false
    }

    @objc(fetchOrCreateTeamWithRemoteIdentifier:createIfNeeded:inContext:)
    public static func fetchOrCreate(with identifier: UUID, _ create: Bool, in context: NSManagedObjectContext) -> Team? {
        precondition(!create || context.zm_isSyncContext, "Needs to be called on the sync context")
        if let existing = Team.fetch(withRemoteIdentifier: identifier, in: context) {
            return existing
        } else if create {
            let team = Team.insertNewObject(in: context)
            team.remoteIdentifier = identifier
            return team
        }

        return nil
    }
}


public enum TeamError: Error {
    case insufficientPermissions
}


extension Team {

    public func addConversation(with participants: Set<ZMUser>) throws -> ZMConversation? {
        guard ZMUser.selfUser(in: managedObjectContext!).canCreateConversation(in: self) else { throw TeamError.insufficientPermissions }
        switch participants.count {
        case 1: return ZMConversation.fetchOrCreateTeamConversation(in: managedObjectContext!, withParticipant: participants.first!, team: self)
        default: return ZMConversation.insertGroupConversation(into: managedObjectContext!, withParticipants: Array(participants), in: self)
        }
    }

}
