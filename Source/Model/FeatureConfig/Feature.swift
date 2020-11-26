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

private let zmLog = ZMSLog(tag: "Feature")

@objcMembers
public class Feature: ZMManagedObject {

    // MARK: - Types

    // IMPORTANT
    //
    // Only add new cases to these enums. Deleting or modifying the raw values
    // of these cases may lead to a corrupt database.

    public enum Name: String, Codable, CaseIterable {
        case appLock
    }

    public enum Status: String, Codable {
        case enabled
        case disabled
    }

    // MARK: - Properties

    @NSManaged private var nameValue: String
    @NSManaged private var statusValue: String
    @NSManaged public var configData: Data?

    @NSManaged public var team: Team?

    public var name: Name {
        get {
            guard let name = Name(rawValue: nameValue) else {
                fatalError("Failed to decode nameValue: \(nameValue)")
            }

            return name
        }

        set {
            nameValue = newValue.rawValue
        }
    }
    
    public var status: Status {
        get {
            guard let status = Status(rawValue: statusValue) else {
                fatalError("Failed to decode statusValue: \(statusValue)")
            }

            return status
        }
        set {
            statusValue = newValue.rawValue
        }
    }

    // MARK: - Methods
    
    public override static func entityName() -> String {
        return "Feature"
    }

    public override static func sortKey() -> String {
        return #keyPath(Feature.nameValue)
    }

    @discardableResult
    public static func fetch(name: Name,
                             context: NSManagedObjectContext) -> Feature? {
        
        let fetchRequest = NSFetchRequest<Feature>(entityName: Feature.entityName())
        fetchRequest.predicate = NSPredicate(format: "nameValue == %@", name.rawValue)
        fetchRequest.fetchLimit = 2

        let results = context.fetchOrAssert(request: fetchRequest)
        require(results.count <= 1, "More than instance for feature: \(name.rawValue)")
        return results.first
    }

    @discardableResult
    public static func createOrUpdate(name: Name,
                                      status: Status,
                                      config: Data?,
                                      team: Team,
                                      context: NSManagedObjectContext) -> Feature {
        if let existing = fetch(name: name, context: context) {
            existing.status = status
            existing.configData = config
            existing.team = team
            existing.needsToBeUpdatedFromBackend = false
            return existing
        }
        
        let feature = insert(name: name,
                             status: status,
                             config: config,
                             team: team,
                             context: context)
        return feature
    }
    
    @discardableResult
    public static func insert(name: Name,
                              status: Status,
                              config: Data?,
                              team: Team,
                              context: NSManagedObjectContext) -> Feature {
        let feature = Feature.insertNewObject(in: context)
        feature.name = name
        feature.status = status
        feature.configData = config
        feature.team = team
        return feature
    }

}
