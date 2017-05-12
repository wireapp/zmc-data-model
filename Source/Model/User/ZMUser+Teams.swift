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


public extension ZMUser {

    public var hasTeams: Bool {
        return memberships?.any { $0.team != nil } ?? false
    }

    public var teams: Set<Team>? {
        guard let memberships = memberships else { return nil }
        return Set(memberships.flatMap { $0.team })
    }

    public var activeTeams: Set<Team>? {
        guard let teams = teams else { return nil }
        return Set(teams.filter { $0.isActive })
    }

    public func isMember(of team: Team) -> Bool {
        return memberships?.any { team.isEqual($0.team) } ?? false
    }

    public func permissions(in team: Team) -> Permissions? {
        return memberships?.first { team.isEqual($0.team) }?.permissions ?? nil
    }

    public func canCreateConversation(in team: Team) -> Bool {
        return permissions(in: team)?.contains(.createConversation) ?? false
    }

    public func isGuest(of team: Team) -> Bool {
        return !isMember(of: team) && team.guests().contains(self)
    }

}
