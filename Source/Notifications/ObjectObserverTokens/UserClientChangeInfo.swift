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

@objc public protocol UserClientObserverOpaqueToken: NSObjectProtocol {
}

public protocol UserClientObserver: NSObjectProtocol {
    func userClientDidChange(_ changeInfo: UserClientChangeInfo)
}

// MARK: - Observing
// TODO Sabine: should we reuse the old ones?
//extension UserClient {
//    
//    public func addObserver(_ observer: UserClientObserver) -> UserClientObserverOpaqueToken? {
//        guard let managedObjectContext = self.managedObjectContext
//            else { return .none }
//        
//        return UserClientObserverToken(observer: observer, managedObjectContext: managedObjectContext, userClient: self)
//    }
//    
//    public static func removeObserverForUserClientToken(_ token: UserClientObserverOpaqueToken) {
//        if let token = token as? UserClientObserverToken {
//            token.tearDown()
//        }
//    }
//}

// MARK: - Observing
extension UserClient {
    public override var description: String {
        return "Client: \(remoteIdentifier), user name: \(user?.name) email: \(user?.emailAddress) platform: \(deviceClass), label: \(label), model: \(model)"
    }
    
}

extension UserClient: ObjectInSnapshot {

    static public var observableKeys : [String] {
        return [ZMUserClientTrusted_ByKey, ZMUserClientIgnored_ByKey, ZMUserClientNeedsToNotifyUserKey, ZMUserClientFingerprintKey]
    }
}

public enum UserClientChangeInfoKey: String {
    case TrustedByClientsChanged = "trustedByClientsChanged"
    case IgnoredByClientsChanged = "ignoredByClientsChanged"
    case FingerprintChanged = "fingerprintChanged"
}

@objc open class UserClientChangeInfo : ObjectChangeInfo {

    public required init(object: NSObject) {
        self.userClient = object as! UserClient
        super.init(object: object)
    }

    open var trustedByClientsChanged : Bool {
        return changedKeysAndOldValues.keys.contains(ZMUserClientTrusted_ByKey)
    }
    open var ignoredByClientsChanged : Bool {
        return changedKeysAndOldValues.keys.contains(ZMUserClientIgnored_ByKey)
    }

    open var fingerprintChanged : Bool {
        return changedKeysAndOldValues.keys.contains(ZMUserClientNeedsToNotifyUserKey)
    }

    open var needsToNotifyUserChanged : Bool {
        return changedKeysAndOldValues.keys.contains(ZMUserClientFingerprintKey)
    }

    open let userClient: UserClient
}

