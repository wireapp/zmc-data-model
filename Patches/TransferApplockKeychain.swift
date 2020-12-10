//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

struct TransferApplockKeychain {
    
    static func migrateKeychainItems(in moc: NSManagedObjectContext) {
        migrateIsApplockActiveState(in: moc)
    }
    
    // Save the enable state of the applock feature in the managedObjectContext instead of the keychain
    static func migrateIsApplockActiveState(in moc: NSManagedObjectContext) {
        let selfUser = ZMUser.selfUser(in: moc)
        
        guard let data = ZMKeychain.data(forAccount: FeatureName.lockApp.rawValue),
            data.count != 0 else {
                selfUser.isAppLockActive = false
                return
        }
        
        selfUser.isAppLockActive = String(data: data, encoding: .utf8) == "YES"
    }
    
    enum FeatureName: String {
        case lockApp = "lockApp"
    }
}
