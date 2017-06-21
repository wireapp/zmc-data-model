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

extension NSManagedObjectContext {
    public func findDuplicated<T: ZMManagedObject, Key: Hashable>(by keyPath: String) -> [Key: [T]] {
        
        guard let entity = NSEntityDescription.entity(forEntityName: T.entityName(), in: self),
              let attribute = entity.attributesByName[keyPath] else {
                fatal("Cannot preapare the fetch")
        }
        
        let keyPathExpression = NSExpression(forKeyPath: keyPath)
        let countExpression = NSExpression(forFunction: "count:", arguments: [keyPathExpression])
        
        let countExpressionDescription = NSExpressionDescription()
        countExpressionDescription.name = "count"
        countExpressionDescription.expression = countExpression
        countExpressionDescription.expressionResultType = .integer32AttributeType

        let request = NSFetchRequest<NSNumber>()
        request.entity = entity
        request.propertiesToFetch = [attribute, countExpressionDescription]
        request.propertiesToGroupBy = [attribute]
        request.resultType = .dictionaryResultType
        
        do {
            let distinctIDAndCount = try self.execute(request) as! NSAsynchronousFetchResult<NSDictionary>
            
            guard let finalResult = distinctIDAndCount.finalResult else {
                return [:]
            }
            
            let ids = finalResult.filter {
                ($0["count"] as? Int ?? 0) > 1
            }.flatMap {
                $0["remoteIdentifier"] as? String
            }

            let fetchAllDuplicatesRequest = NSFetchRequest<T>()
            fetchAllDuplicatesRequest.entity = entity
            fetchAllDuplicatesRequest.predicate = NSPredicate(format: "%K IN %@", argumentArray: [keyPath, ids])

            return self.fetchOrAssert(request: fetchAllDuplicatesRequest).group(by: keyPath)
            
        } catch let error {
            fatal("Cannot perform the fetch: \(error)")
        }
        
        return [:]
    }
}

extension Array where Element: NSObject {
    public func group<Key: Hashable>(by keyPath: String) -> [Key: [Element]] {
        return self.map {
            return TupleKeyArray(key: $0.value(forKey: keyPath) as! Key, value: [$0])
        }.merge()
    }
}
