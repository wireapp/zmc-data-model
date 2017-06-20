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


public protocol TupleKeyArrayType {
    associatedtype Key: Hashable
    associatedtype Value: Any
    var key: Key { get }
    var value: [Value] { get }
}

public struct TupleKeyArray<Key: Hashable, Value: Any>: TupleKeyArrayType {
    public let key: Key
    public let value: [Value]
}

extension Array where Element: TupleKeyArrayType {
    public func merge() -> [Element.Key: [Element.Value]] {
        let initialValue: [Element.Key: [Element.Value]] = [:]
        return self.reduce(initialValue) {
            var objectsForKey = $0[$1.key] ?? []
            objectsForKey.append(contentsOf: $1.value)
            var result = $0
            result[$1.key] = objectsForKey
            return result
        }
    }
}

public func findDuplicated<T: ZMManagedObject, Key: Hashable & CVarArg>(in context: NSManagedObjectContext, by keyPath: String) -> [Key: [T]] {
    
    guard let entity = NSEntityDescription.entity(forEntityName: T.entityName(), in: context),
          let attribute = entity.attributesByName[keyPath],
          let property = entity.propertiesByName[keyPath] else {
            fatal("Cannot preapare the fetch")
    }
    
    let request = NSFetchRequest<NSDictionary>()
    request.entity = entity
    request.propertiesToGroupBy = [attribute]
    request.propertiesToFetch = [property]
    request.resultType = .dictionaryResultType
    
    let result: [Key: [T]]
    do {
        let distinctIDs = try context.execute(request) as! NSAsynchronousFetchResult<NSDictionary>
        
        func fetchRequest<T>(for keyPath: String, value: Key) -> NSFetchRequest<T> {
            let innerFetchRequest = NSFetchRequest<T>()
            innerFetchRequest.predicate = NSPredicate(format: "%K == %@", keyPath, value)
            innerFetchRequest.entity = entity
            return innerFetchRequest
        }
        
        result = distinctIDs.finalResult!
            .map {
                $0[keyPath as NSString]! as! Key
            }.filter {
                return try! context.count(for: fetchRequest(for: keyPath, value: $0)) > 1
            }.map {
                return TupleKeyArray(key: $0, value: context.fetchOrAssert(request: fetchRequest(for: keyPath, value: $0)) as! [T])
            }.merge()
    } catch let error {
        fatal("Cannot perform the fetch: \(error)")
    }
    
    return result
}

extension Array where Element: NSObject {
    public func group<Key: Hashable>(by keyPath: String) -> [Key: [Element]] {
        return self.map {
            return TupleKeyArray(key: $0.value(forKey: keyPath) as! Key, value: [$0])
        }.merge()
    }
}
