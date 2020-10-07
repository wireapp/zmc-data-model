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

class DetailedChangeDetector: ChangeDetector {

    // MARK: - Properties

    private unowned let context: NSManagedObjectContext

    private var allChanges = [ZMManagedObject: Changes]()
    private let snapshotCenter: SnapshotCenter
    private let affectingKeysStore: DependencyKeyStore

    var changeInfo: [ObjectChangeInfo] {
        return allChanges.compactMap {
            ObjectChangeInfo.changeInfo(for: $0, changes: $1)
        }
    }

    // MARK: - Life cycle

    init(classIdentifiers: [ClassIdentifier], managedObjectContext: NSManagedObjectContext) {
        context = managedObjectContext
        snapshotCenter = SnapshotCenter(managedObjectContext: context)
        affectingKeysStore = DependencyKeyStore(classIdentifiers: classIdentifiers)
    }

    // MARK: - Methods

    func reset() {
        allChanges = [:]
        snapshotCenter.clearAllSnapshots()
    }

    func add(changes: Changes, for object: ZMManagedObject) {
        allChanges = allChanges.merged(with: [object: changes])
    }

    func detectChanges(for objects: ModifiedObjects) {
        snapshotCenter.createSnapshots(for: objects.inserted)
        detectChanges(for: objects.updated.union(objects.refreshed))
        detectChangesCausedByInsertionOrDeletion(for: objects.inserted)
        detectChangesCausedByInsertionOrDeletion(for: objects.deleted)
    }

    private func detectChanges(for changedObjects: Set<ZMManagedObject>) {

        func getChangedKeysSinceLastSave(object: ZMManagedObject) -> Set<String> {
            var changedKeys = Set(object.changedValues().keys)

            if changedKeys.isEmpty || object.isFault  {
                // If the object is a fault, calling changedValues() will return an empty set.
                // Luckily we created a snapshot of the object before the merge happend which
                // we can use to compare the values.
                changedKeys = snapshotCenter.extractChangedKeysFromSnapshot(for: object)
            } else {
                snapshotCenter.updateSnapshot(for: object)
            }

            return changedKeys
        }

        // Check for changed keys and affected keys.
        let changes: [ZMManagedObject: Changes] = changedObjects.mapToDictionary{ object in
            // (1) Get all the changed keys since last Save.
            let changedKeys = getChangedKeysSinceLastSave(object: object)
            guard !changedKeys.isEmpty else { return nil }

            // (2) Get affected changes.
            detectChangesCausedByChangeInObjects(updatedObject: object, knownKeys: changedKeys)

            // (3) Map the changed keys to affected keys, remove the ones that we are not reporting.
            let affectedKeys = changedKeys
                .map { affectingKeysStore.observableKeysAffectedByValue(object.classIdentifier, key: $0) }
                .reduce(Set()) { $0.union($1) }

            guard !affectedKeys.isEmpty else { return nil }
            return Changes(changedKeys: affectedKeys)
        }

        // (4) Merge the changes with the other ones.
        allChanges = allChanges.merged(with: changes)
    }

    private func detectChangesCausedByChangeInObjects(updatedObject: ZMManagedObject, knownKeys: Set<String>) {
        // (1) All Updates in other objects resulting in changes on others,
        // e.g. changing a users name affects the conversation displayName.
        guard let object = updatedObject as? SideEffectSource else { return }
        let changedObjectsAndKeys = object.affectedObjectsAndKeys(keyStore: affectingKeysStore, knownKeys: knownKeys)
        allChanges = allChanges.merged(with: changedObjectsAndKeys)
    }

    private func detectChangesCausedByInsertionOrDeletion(for objects: Set<ZMManagedObject>) {
        // All inserts or deletes of other objects resulting in changes in others,
        // e.g. inserting a user affects the conversation displayName.
        objects.forEach { obj in
            guard let object = obj as? SideEffectSource else { return }
            let changedObjectsAndKeys = object.affectedObjectsForInsertionOrDeletion(keyStore: affectingKeysStore)
            allChanges = allChanges.merged(with: changedObjectsAndKeys)
        }
    }

}
