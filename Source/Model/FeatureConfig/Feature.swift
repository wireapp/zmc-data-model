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

//public enum FeatureName_Old: String, CaseIterable {
//    case applock = "applock"
//    case unknown = "unknown"
//}
//
//public enum FeatureStatus: String, CaseIterable {
//    case enabled = "enabled"
//    case disabled = "disabled"
//
//    var status: Bool {
//        switch self {
//        case .enabled:
//            return true
//        case .disabled:
//            return false
//        }
//    }
//}

@objcMembers
public class Feature: ZMManagedObject {
   
    @NSManaged public var name: String
    @NSManaged public var status: String
    @NSManaged public var config: Data?
    
//    var name: FeatureName_Old {
//        get {
//            return FeatureName_Old.allCases.first(where: { $0.rawValue == rawName }) ?? .unknown
//        }
//        set {
//            rawName = newValue.rawValue
//        }
//    }
//
//    var status: Bool {
//        get {
//            return FeatureStatus.allCases.first(where: { $0.rawValue == rawStatus })?.status ?? false
//        }
//        set {
//            rawStatus = newValue
//                ? FeatureStatus.enabled.rawValue
//                : FeatureStatus.disabled.rawValue
//        }
//    }
//
//    var config: ConfigType? {
//        get {
//            guard let rawConfig = rawConfig else {
//                return nil
//            }
//            return try? JSONDecoder().decode(ConfigType.self, from: rawConfig)
//
//        }
//        set {
//            rawConfig = try? JSONEncoder().encode(newValue)
//        }
//    }
    
    public override static func entityName() -> String {
        return "Feature"
    }
    
    @discardableResult
    public static func fetch(_ featureName: String,
                                   context: NSManagedObjectContext) -> Feature? {
        
        let fetchRequest = NSFetchRequest<Feature>(entityName: Feature.entityName())
        fetchRequest.predicate = NSPredicate(format: "name == %@", featureName)
        fetchRequest.fetchLimit = 1
        return context.fetchOrAssert(request: fetchRequest).first
    }
    
    @discardableResult
    public static func createOrUpdate(_ featureName: String,
                                      status: String,
                                      config: Data?,
                                      context: NSManagedObjectContext) -> Feature? {
        if let existing = fetch(featureName, context: context) {
            existing.status = status
            existing.config = config
            return existing
        }

        let feature = insert(featureName,
                             status: status,
                             config: config,
                             context: context)
        return feature
    }
    
    @discardableResult
    public static func insert(_ featureName: String,
                              status: String,
                              config: Data?,
                              context: NSManagedObjectContext) -> Feature {
        let feature = Feature.insertNewObject(in: context)
        feature.name = featureName
        feature.status = status
        feature.config = config
        return feature
    }
}

//public struct AppLockConfig: Codable {
//    let enforceAppLock: Bool
//    let inactivityTimeoutSecs: UInt
//
//    private enum CodingKeys: String, CodingKey {
//        case enforceAppLock = "enforce_app_lock"
//        case inactivityTimeoutSecs = "inactivity_timeout_secs"
//    }
//}
