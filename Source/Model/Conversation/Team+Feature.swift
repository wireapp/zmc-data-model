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

extension Team {

    @NSManaged private var features: Set<Feature>

    /// Fetch a particular team feature.
    ///
    /// - Parameters:
    ///     - type: The type of the desired feature. The available features
    ///             are typically found in the namespace `Feature`.
    ///
    /// - Returns:
    ///     The feature object.

    public func feature<T: FeatureLike>(for type: T.Type) -> T? {
        guard let feature = features.first(where: { $0.name == T.name }) else { return nil }
        return T(feature: feature)
    }

}
