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

class PotentialChangeDetector: ChangeDetector {

    // MARK: - Private properties

    private var modifiedObjects = ModifiedObjects()

    // MARK: - Methods

    func consumeChanges() -> [ChangeInfo] {
        var potentialChangesByObject = [ZMManagedObject: PotentialObjectChangeInfo.Changes]()

        modifiedObjects.updatedAndRefreshed.forEach {
            potentialChangesByObject[$0, default: []].insert(.updated)
        }

        modifiedObjects.inserted.forEach {
            potentialChangesByObject[$0, default: []].insert(.inserted)
        }

        modifiedObjects.deleted.forEach {
            potentialChangesByObject[$0, default: []].insert(.deleted)
        }

        reset()

        return potentialChangesByObject.map {
            ChangeInfo.potential(changes: .init(object: $0, changes: $1))
        }
    }

    func reset() {
        modifiedObjects = ModifiedObjects()
    }

    func add(changes: Changes, for object: ZMManagedObject) {
        detectChanges(for: ModifiedObjects(updated: [object]))
    }

    func detectChanges(for objects: ModifiedObjects) {
        modifiedObjects = modifiedObjects.merged(with: objects)
    }

}

// MARK: - Helper extensions

private extension Dictionary where Value: SetAlgebra {

    subscript(key: Key, default defaultValue: Value) -> Value {
        return self[key] ?? defaultValue
    }

}
