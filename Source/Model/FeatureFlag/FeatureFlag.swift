//
//  FeatureFlag.swift
//  WireDataModel
//
//  Created by Marco Maddalena on 24/06/2020.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

@objcMembers
public class FeatureFlag: ZMManagedObject {
    public static let teamKey = #keyPath(FeatureFlag.team.name)
    
    @NSManaged public var isEnabled: Bool
    @NSManaged public var updatedTimestamp: Date
    @NSManaged public var team: Team?
    
    open override var ignoredKeys: Set<AnyHashable>? {
        return (super.ignoredKeys ?? Set())
            .union([#keyPath(updatedTimestamp)])
    }
    
    public override static func entityName() -> String {
        return "FeatureFlag"
    }
    
    public var updatedAt : Date? {
        return updatedTimestamp
    }
    
    public static func fetchOrCreate(with value: Bool,
                                     team: Team,
                                     context: NSManagedObjectContext) -> FeatureFlag {
        precondition(context.zm_isSyncContext)

        if let existing = team.featureFlag {
            return existing
        }

        let featureFlag = FeatureFlag.insertNewObject(in: context)
        featureFlag.isEnabled = value
        featureFlag.updatedTimestamp = Date()
        featureFlag.team = team
        return featureFlag
    }
    
    public static func insert(with value: Bool,
                              team: Team,
                              context: NSManagedObjectContext) {
        precondition(context.zm_isSyncContext)

        let featureFlag = FeatureFlag.insertNewObject(in: context)
        featureFlag.isEnabled = value
        featureFlag.updatedTimestamp = Date()
        featureFlag.team = team
        team.featureFlag = featureFlag
    }
}
