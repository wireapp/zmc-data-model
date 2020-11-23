//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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

public extension Team {

    @NSManaged var features: Set<Feature>

}

public extension Set where Element == Feature {

    var appLock: Feature.AppLock? {
        guard let feature = first(where: { $0.name == .appLock }) else { return nil }
        return Feature.AppLock(from: feature)
    }

}

public extension Feature {

    struct AppLock {

        // MARK: - Properties

        let name: Name
        let status: Status
        let config: Config

        // MARK: - Life cycle

        init?(from feature: Feature) {
            guard
                feature.name == .appLock,
                let data = feature.configData,
                let config = try? JSONDecoder().decode(Config.self, from: data)
            else {
                return nil
            }

            self.name = feature.name
            self.status = feature.status
            self.config = config
        }

        // MARK: - Types

        struct Config: Codable {
            let enforceAppLock: Bool
            let inactivityTimeoutSecs: UInt
        }

    }

}
