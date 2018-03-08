//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

extension ZMConversation {

    // MARK: User Categories

    var serviceUsers: Set<ZMUser> {
        return services(in: otherActiveParticipants.set as! Set<ZMUser>)
    }

    func services(in set: Set<ZMUser>) -> Set<ZMUser> {
        return set.filtered { $0.isServiceUser }
    }

    func categorizeUsers(in usersSet: Set<ZMUser>) -> (services: Set<ZMUser>, users: Set<ZMUser>) {
        let services = self.services(in: usersSet)
        let users = usersSet.subtracting(services)
        return (services, users)
    }

    // MARK: Mentions

    func textMentionsServices(_ text: String) -> Bool {
        return text.starts(with: "@bots ")
    }

    @objc(mentionsInText:)
    func mentions(in text: String) -> [ZMMention] {
        var mentionedUsers: [ZMUser] = []

        if textMentionsServices(text) {
            mentionedUsers.append(contentsOf: serviceUsers)
        }

        return ZMMentionBuilder.build(mentionedUsers)
    }

}
