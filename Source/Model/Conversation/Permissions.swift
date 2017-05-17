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


public struct Permissions: OptionSet {

    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    // MARK: - Base Values
    public static let createConversation       = Permissions(rawValue: 1 << 0)
    public static let deleteConversation       = Permissions(rawValue: 1 << 1)
    public static let addTeamMember            = Permissions(rawValue: 1 << 2)
    public static let removeTeamMember         = Permissions(rawValue: 1 << 3)
    public static let addConversationMember    = Permissions(rawValue: 1 << 4)
    public static let removeConversationMember = Permissions(rawValue: 1 << 5)
    public static let getMemberPermissions     = Permissions(rawValue: 1 << 6)
    public static let getTeamConversations     = Permissions(rawValue: 1 << 7)
    public static let getBilling               = Permissions(rawValue: 1 << 8)
    public static let setBilling               = Permissions(rawValue: 1 << 9)
    public static let setTeamData              = Permissions(rawValue: 1 << 10)
    public static let deleteTeam               = Permissions(rawValue: 1 << 11)

    // MARK: - Common Combined Values
    public static let member: Permissions = [.createConversation, .deleteConversation, .addConversationMember, .removeConversationMember, .getTeamConversations, .getMemberPermissions]
    public static let admin: Permissions  = [.member, .addTeamMember, .removeTeamMember, .setTeamData]
    public static let owner: Permissions  = [.admin, .getBilling, .setBilling, .deleteTeam]

}


// MARK: - Transport Data


extension Permissions {

    public init(payload: [String]) {
        var permissions: Permissions = []
        payload.flatMap(Permissions.init).forEach { permissions.formUnion($0) }
        self = permissions
    }

    public init?(string: String) {
        switch string {
        case "CreateConversation": self = .createConversation
        case "DeleteConversation": self = .deleteConversation
        case "AddTeamMember": self = .addTeamMember
        case "RemoveTeamMember": self = .removeTeamMember
        case "AddConversationMember": self = .addConversationMember
        case "RemoveConversationMember": self = .removeConversationMember
        case "GetMemberPermissions": self = .getMemberPermissions
        case "GetTeamConversations": self = .getTeamConversations
        case "GetBilling": self = .getBilling
        case "SetBilling": self = .setBilling
        case "SetTeamData": self = .setTeamData
        case "DeleteTeam": self = .deleteTeam
        default: return nil
        }
    }
}


// MARK: - Debugging


extension Permissions: CustomDebugStringConvertible {

    private static let descriptions: [Permissions: String] = [
        .createConversation: "CreateConversation",
        .deleteConversation: "DeleteConversation",
        .addTeamMember: "AddTeamMember",
        .removeTeamMember: "RemoveTeamMember",
        .addConversationMember: "AddConversationMember",
        .removeConversationMember: "RemoveConversationMember",
        .getMemberPermissions: "GetMemberPermissions",
        .getTeamConversations: "GetTeamConversations",
        .getBilling : "GetBilling",
        .setBilling: "SetBilling",
        .setTeamData: "SetTeamData",
        .deleteTeam: "DeleteTeam"
    ]

    public var debugDescription: String {
        return "[\(Permissions.descriptions.filter { contains($0.0) }.map { $0.1 }.joined(separator: ", "))]"
    }

}


extension Permissions: Hashable {

    public var hashValue : Int {
        return rawValue.hashValue
    }

}

// MARK: - Objective-C Interoperability


@objc public enum PermissionsObjC: Int {
    case none = 0, member, admin, owner

    var permissions: Permissions {
        switch self {
        case .none: return Permissions(rawValue: 0)
        case .member: return .member
        case .admin: return .admin
        case .owner: return .owner
        }
    }
}

extension Member {

    @objc public func setPermissionsObjC(_ permissionsObjC: PermissionsObjC) {
        permissions = permissionsObjC.permissions
    }
    
}
