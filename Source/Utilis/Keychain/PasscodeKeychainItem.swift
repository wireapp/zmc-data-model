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

public enum PasscodeKeychainItem: KeychainItem {

    case passcode(_ uuid: SelfUserIdentifier)

    public var uniqueIdentifier: String {
        return "com.wire.passcode.\(userIdentifier)"
    }

    var userIdentifier: String {
        switch self {
        case .passcode(let selfUserIdentifier):
            return selfUserIdentifier.transportString()
        }
    }
    
    public var queryForGettingValue: [CFString: Any] {
        let query: [CFString: Any]

        switch self {
        case .passcode:
            query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: uniqueIdentifier,
                     kSecReturnData: true]
        }

        return query
    }

    public func queryForSetting(value: Data) -> [CFString: Any] {
        let query: [CFString: Any]

        switch self {
        case .passcode:
            query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: uniqueIdentifier,
                     kSecValueData: value]
        }

        return query
    }
}

// MARK: - Migration rules

public extension PasscodeKeychainItem {
    
    static func migratePasscode(in moc: NSManagedObjectContext) {
        let selfUser = ZMUser.selfUser(in: moc)
        
        guard let data = try? Keychain.fetchItem(Deprecated_PasscodeKeychainItem.passcode) else {
            return
        }
        
        do {
            try Keychain.updateItem(PasscodeKeychainItem.passcode(selfUser.remoteIdentifier), value: data)
        } catch {
            fatalError("Failed to migrate passcode: \(error)")
        }
    }
    
    enum Deprecated_PasscodeKeychainItem: KeychainItem {
        case passcode
        
        public var uniqueIdentifier: String {
            return "com.wire.passcode"
        }
        
        public var queryForGettingValue: [CFString: Any] {
            let query: [CFString: Any]
            
            switch self {
            case .passcode:
                query = [kSecClass: kSecClassGenericPassword,
                         kSecAttrAccount: uniqueIdentifier,
                         kSecReturnData: true]
            }
            
            return query
        }
        
        public func queryForSetting(value: Data) -> [CFString: Any] {
            let query: [CFString: Any]
            
            switch self {
            case .passcode:
                query = [kSecClass: kSecClassGenericPassword,
                         kSecAttrAccount: uniqueIdentifier,
                         kSecValueData: value]
            }
            
            return query
        }
    }
}
