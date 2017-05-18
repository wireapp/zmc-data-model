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


    public enum TransportString: String {
        case createConversation = "CreateConversation"
        case deleteConversation = "DeleteConversation"
        case addTeamMember = "AddTeamMember"
        case removeTeamMember = "RemoveTeamMember"
        case addConversationMember = "AddConversationMember"
        case removeConversationMember = "RemoveConversationMember"
        case getMemberPermissions = "GetMemberPermissions"
        case getTeamConversations = "GetTeamConversations"
        case getBilling  = "GetBilling"
        case setBilling = "SetBilling"
        case setTeamData = "SetTeamData"
        case deleteTeam = "DeleteTeam"

        var permissions: Permissions {
            switch self {
            case .createConversation: return .createConversation
            case .deleteConversation: return .deleteConversation
            case .addTeamMember: return .addTeamMember
            case .removeTeamMember: return .removeTeamMember
            case .addConversationMember: return .addConversationMember
            case .removeConversationMember: return .removeConversationMember
            case .getMemberPermissions: return .getMemberPermissions
            case .getTeamConversations: return .getTeamConversations
            case .getBilling: return .getBilling
            case .setBilling: return .setBilling
            case .setTeamData: return .setTeamData
            case .deleteTeam: return .deleteTeam
            }
        }
    }

}


// MARK: - Transport Data


extension Permissions {

    public init(payload: [String]) {
        var permissions: Permissions = []
        payload.flatMap(Permissions.init).forEach { permissions.formUnion($0) }
        self = permissions
    }

    public init?(string: String) {
        guard let value = Permissions.TransportString(rawValue: string)?.permissions else { return nil }
        self = value
    }
}


// MARK: - Debugging


extension Permissions: CustomDebugStringConvertible {

    private static let descriptions: [Permissions: Permissions.TransportString] = [
        .createConversation: .createConversation,
        .deleteConversation: .deleteConversation,
        .addTeamMember: .addTeamMember,
        .removeTeamMember: .removeTeamMember,
        .addConversationMember: .addConversationMember,
        .removeConversationMember: .removeConversationMember,
        .getMemberPermissions: .getMemberPermissions,
        .getTeamConversations: .getTeamConversations,
        .getBilling : .getBilling,
        .setBilling: .setBilling,
        .setTeamData: .setTeamData,
        .deleteTeam: .deleteTeam
    ]

    public var debugDescription: String {
        return "[\(Permissions.descriptions.filter { contains($0.0) }.map { $0.1.rawValue }.joined(separator: ", "))]"
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
