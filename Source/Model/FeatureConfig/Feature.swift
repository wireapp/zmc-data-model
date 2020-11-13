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

public enum FeatureName: String, CaseIterable {
    
    case applock = "applock"
    case unknown = "unknown"
    
    public var configType: BaseConfig.Type {
        switch self {
        case .applock:
            return AppLockConfig.self
        default:
            return AppLockConfig.self
        }
    }
}

public enum FeatureStatus: String, CaseIterable {
    case enabled = "enabled"
    case disabled = "disabled"
    
    var status: Bool {
        switch self {
        case .enabled:
            return true
        case .disabled:
            return false
        }
    }
}

@objcMembers
public class Feature<ConfigType: Codable>: ZMManagedObject {
   
    @NSManaged public var rawName: String
    @NSManaged public var rawStatus: String
    @NSManaged public var rawConfig: Data?
    @NSManaged public var team: Team?
    
    var name: FeatureName {
        get {
            return FeatureName.allCases.first(where: { $0.rawValue == rawName }) ?? .unknown
        }
        set {
            rawName = newValue.rawValue
        }
    }
    
    var status: Bool {
        get {
            return FeatureStatus.allCases.first(where: { $0.rawValue == rawStatus })?.status ?? false
        }
        set {
            rawStatus = newValue
                ? FeatureStatus.enabled.rawValue
                : FeatureStatus.disabled.rawValue
        }
    }
    
    var config: ConfigType? {
        get {
            guard let rawConfig = rawConfig else {
                return nil
            }
            return try? JSONDecoder().decode(ConfigType.self, from: rawConfig)

        }
        set {
            rawConfig = try? JSONEncoder().encode(newValue)
        }
    }
    
    public override static func entityName() -> String {
        return "Feature"
    }
    
    @discardableResult
    public static func fetch(with name: FeatureName,
                             team: Team,
                             context: NSManagedObjectContext) -> Feature<ConfigType>? {
        precondition(context.zm_isSyncContext)
        
        let fetchRequest = NSFetchRequest<Feature>(entityName: Feature.entityName())
        fetchRequest.predicate = NSPredicate(format: "team == %@ && rawName == %@",
                                             team,
                                             name.rawValue)
        fetchRequest.fetchLimit = 1
        return context.fetchOrAssert(request: fetchRequest).first
    }
    
    @discardableResult
    public static func createOrUpdate(with name: FeatureName,
                                      status: Bool,
                                      config: ConfigType,
                                      team: Team,
                                      context: NSManagedObjectContext) -> Feature<ConfigType>? {
        precondition(context.zm_isSyncContext)
        
        if let existing = fetch(with: name, team: team, context: context) {
            existing.status = status
            existing.config = config
            return existing
        }
        
        let feature = insert(with: name,
                             status: status,
                             config: config,
                             team: team,
                             context: context)
        return feature
    }
    
    @discardableResult
    public static func insert(with name: FeatureName,
                              status: Bool,
                              config: ConfigType,
                              team: Team,
                              context: NSManagedObjectContext) -> Feature<ConfigType> {
        precondition(context.zm_isSyncContext)

        let feature = Feature<ConfigType>.insertNewObject(in: context)
        feature.name = name
        feature.status = status
        feature.config = config
        feature.team = team
        return feature
    }
}

public protocol BaseConfig {}

public struct AppLockConfig: Decodable, BaseConfig {
    let enforceAppLock: Bool
    let inactivityTimeoutSecs: UInt
    
    private enum CodingKeys: String, CodingKey {
        case enforceAppLock = "enforce_app_lock"
        case inactivityTimeoutSecs = "inactivity_timeout_secs"
    }
}
