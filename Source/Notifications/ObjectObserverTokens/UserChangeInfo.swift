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
import ZMCSystem

extension ZMUser : ObjectInSnapshot {
    
    static public var observableKeys : [String] {
        return ["name", "displayName", "accentColorValue", "imageMediumData", "imageSmallProfileData","emailAddress", "phoneNumber", "canBeConnected", "isConnected", "isPendingApprovalByOtherUser", "isPendingApprovalBySelfUser", "clients", "handle"]
    }

}


@objc open class UserChangeInfo : ObjectChangeInfo {

    public required init(object: NSObject) {
        self.user = object as! ZMBareUser
        super.init(object: object)
    }

    open var nameChanged : Bool {
        return !Set(arrayLiteral: "name", "displayName").isDisjoint(with: changedKeysAndOldValues.keys)
    }
    
    open var accentColorValueChanged : Bool {
        return changedKeysAndOldValues.keys.contains("accentColorValue")
    }

    open var imageMediumDataChanged : Bool {
        return changedKeysAndOldValues.keys.contains("imageMediumData")
    }

    open var imageSmallProfileDataChanged : Bool {
        return changedKeysAndOldValues.keys.contains("imageSmallProfileData")
    }

    open var profileInformationChanged : Bool {
        return !Set(arrayLiteral: "emailAddress", "phoneNumber").isDisjoint(with: changedKeysAndOldValues.keys)
    }

    open var connectionStateChanged : Bool {
        return !Set(arrayLiteral: "isConnected", "canBeConnected", "isPendingApprovalByOtherUser", "isPendingApprovalBySelfUser").isDisjoint(with: changedKeysAndOldValues.keys)
    }

    open var trustLevelChanged : Bool {
        return userClientChangeInfo != nil
    }

    open var clientsChanged : Bool {
        return changedKeysAndOldValues.keys.contains("clients")
    }

    public var handleChanged : Bool {
        return changedKeysAndOldValues.keys.contains("handle")
    }


    open let user: ZMBareUser
    open var userClientChangeInfo : UserClientChangeInfo?

}





