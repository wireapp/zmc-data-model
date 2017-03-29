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

import Foundation


struct OrderedSetState<T: Hashable> {

    var array : [T]
    var order : [T : Int]
    
    init(array: [T]) {
        guard array.count == Set(array).count else {
            fatalError("Array contains duplicate items")
        }
        var order = [T: Int]()
        for (idx, item) in array.enumerated() {
            order[item] = idx
        }
        
        self.array = array
        self.order = order
    }
    
    @discardableResult mutating func move(item: T, to: Int) -> Int? {
        guard let oldIndex = order[item] else { return nil }
        
        array.remove(at: oldIndex)
        array.insert(item, at: to)
        for i in [oldIndex, to].sorted() {
            order[array[i]] = i
        }
        return oldIndex
    }
}

public enum MoveType {
    case tableView, uiCollectionView
}

struct MovedIndex {
    let from : Int
    let to: Int
}


struct ChangedIndexes<T : Hashable> {

    let startState : OrderedSetState<T>
    let endState : OrderedSetState<T>
    let updatedObjects : Set<T>

    let deletedIndexes : IndexSet
    let insertedIndexes : IndexSet
    let updatedIndexes : IndexSet
    let movedIndexes : [MovedIndex]
    let moveType : MoveType
    
    /// Calculates the inserts, deletes, moves and updates comparing two sets of ordered, distinct objects
    /// @param startState: State before the updates
    /// @param endState: State after the updates
    /// @param updatedObjects: Objects that need to be reloaded
    /// @param moveType: depending on viewController, default is uiCollectionView
    init(start: OrderedSetState<T>, end : OrderedSetState<T>, updated: Set<T>, moveType: MoveType = .uiCollectionView) {
        let (deletedIndexes, insertedIndexes, updatedIndexes, movedIndexes) = type(of: self).calculateChanges(start: start, end: end, updated: updated, moveType: moveType)
        
        self.startState = start
        self.endState = end
        self.updatedObjects = updated
        
        self.deletedIndexes = deletedIndexes
        self.insertedIndexes = insertedIndexes
        self.updatedIndexes = updatedIndexes
        self.movedIndexes = movedIndexes
        self.moveType = moveType
    }
    
    static func calculateChanges(start: OrderedSetState<T>, end: OrderedSetState<T>, updated: Set<T>, moveType: MoveType) -> ( deletedIndexes: IndexSet, insertedIndexes: IndexSet, updatedIndexes: IndexSet, movedIndexes: [MovedIndex])
    {
        var deletedIndexes = IndexSet()
        var updatedIndexes = IndexSet()
        var insertedObjects = end.order // when iterating through the collection we remove the items we found. This way the only items remaining will be inserted objects
        var intermediateState = [T]()
        
        for (idx, item) in start.array.enumerated() {
            if insertedObjects.removeValue(forKey: item) != nil {
                intermediateState.append(item)
                if updated.contains(item){
                    updatedIndexes.insert(idx)
                }
            } else {
                deletedIndexes.insert(idx)
            }
        }
        
        // sort inserted indexes in ascending order to avoid out of bounds inserts
        let ascInsertedIndexes = insertedObjects.values.sorted()
        
        // Insert inserted objects and calculate changes
        ascInsertedIndexes.forEach{intermediateState.insert(end.array[$0], at: $0)}
        let movedIndexes = calculateMoves(start: start, end: end, afterDeletesAndInserts: intermediateState, moveType: moveType)
        
        return (deletedIndexes: deletedIndexes,
                insertedIndexes: IndexSet(ascInsertedIndexes),
                updatedIndexes: updatedIndexes,
                movedIndexes: movedIndexes)
    }
    
    static func calculateMoves(start: OrderedSetState<T>, end: OrderedSetState<T>, afterDeletesAndInserts: [T], moveType: MoveType) -> [MovedIndex]
    {
        var intermediateState = afterDeletesAndInserts
        var movedIndexes = [MovedIndex]()
        
        if moveType == .uiCollectionView {
            // Moved `from` indexes are referring to the index in the startState
            // Moves must be calculated comparing the endState the immediately updated intermediate state

            // If the intermediate value at the index is different from the endValue:
            // (1) add a move from the index in the startState to the index in endState
            // (2) search for the position of the endValue in the intermediate state, move the item to the current index
            // (3) continue at next index
            for idx in (0..<intermediateState.endIndex) {
                let intermediateValue = intermediateState[idx]
                let endValue = end.array[idx]
                if intermediateValue != endValue {
                    if let oldIdx = start.order[endValue] {
                        movedIndexes.append(MovedIndex(from: oldIdx, to: idx))
                        if let intIdx = intermediateState.index(of: endValue) {
                            intermediateState.remove(at: intIdx)
                            intermediateState.insert(endValue, at: idx)
                        }
                    }
                }
            }
        }
        else if moveType == .tableView {
            // Moved `from` indexes are referring to the index in the intermediate state
            // Moves must be calculated comparing the endState the immediately updated intermediate state

            // If the intermediate value at the index is different from the endValue:
            // (1) search for the position of the endValue in the intermediate state, move the item to the current index
            // (2) add a move from the index in the intermediate state to the index in endState
            // (3) continue at next index

            for idx in (0..<intermediateState.endIndex) {
                let intermediateValue = intermediateState[idx]
                let endValue = end.array[idx]
                if intermediateValue != endValue {
                    if let intIdx = intermediateState.index(of: endValue) {
                        intermediateState.remove(at: intIdx)
                        intermediateState.insert(endValue, at: idx)
                        movedIndexes.append(MovedIndex(from: intIdx, to: idx))
                    }
                }
            }
        } else {
            fatalError("Unknown moveType \(moveType)")
        }
        return movedIndexes
    }
    
    func enumerateMovedIndexes(block: (_ from: Int, _ to: Int) -> Void) {
        for pair in movedIndexes {
            block(Int(pair.from), Int(pair.to))
        }
    }
}

