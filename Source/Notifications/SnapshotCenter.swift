//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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

struct Snapshot {
    let attributes : [String : NSObject?]
    let toManyRelationships : [String : Int]
    let wasFaulted : Bool
}

class SnapshotCenter {
    
    private unowned var managedObjectContext: NSManagedObjectContext
    private var snapshots : [NSManagedObjectID : Snapshot] = [:]
    // TODO Sabine: When do we get rid of those?
    /// This function needs to be called when the sync context saved and we receive the NSManagedObjectContextDidSave notification and before the changes are merged into the UI context
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    func willMergeChanges(changes: [NSManagedObjectID]){
        // TODO Sabine do I need to wrap this in a block?
        managedObjectContext.performGroupedBlock { [weak self] in
            guard let `self` = self else { return }
            self.snapshots = changes.mapToDictionary{ objectID in
                guard let obj = (try? self.managedObjectContext.existingObject(with: objectID)) else { return nil }
                if obj.isFault {
                    return Snapshot(attributes : [:], toManyRelationships : [:], wasFaulted: true)
                }
                let attributes = Array(obj.entity.attributesByName.keys)
                let attributesDict = attributes.mapToDictionaryWithOptionalValue{obj.primitiveValue(forKey: $0) as? NSObject}
                let relationShips = obj.entity.relationshipsByName
                let relationshipsDict : [String : Int] = relationShips.mapping(keysMapping: {$0}, valueMapping: { (key, relationShipDescription) in
                    guard relationShipDescription.isToMany else { return nil}
                    return (obj.primitiveValue(forKey: key) as? Countable)?.count
                })
                return Snapshot(attributes : attributesDict, toManyRelationships : relationshipsDict, wasFaulted: false)
            }
        }
    }
    
    /// Before merging the sync into the ui context, we create a snapshot of all changed objects
    /// This function compares the snapshot values to the current ones and returns all keys and new values where the value changed due to the merge
    func extractChangedKeysFromSnapshot(for object: ZMManagedObject) -> Set<String> {
        guard let snapshot = snapshots[object.objectID] else { return Set()}
        var changedKeys = Set<String>()
        snapshot.attributes.forEach{
            let currentValue = object.value(forKey: $0) as? NSObject
            if currentValue != $1  {
                changedKeys.insert($0)
            }
        }
        snapshot.toManyRelationships.forEach{
            guard let count = (object.value(forKey: $0) as? Countable)?.count, count != $1 else { return }
            changedKeys.insert($0)
        }
        print(snapshot, changedKeys)
        snapshots.removeValue(forKey: object.objectID)
        return changedKeys
    }
    
    func clearSnapshots(){
        snapshots = [:]
    }
}
