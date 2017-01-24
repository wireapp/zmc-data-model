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

    static let UserClientChangeInfoKey = "clientChanges"
    
    static func changeInfo(for user: ZMUser, changes: Changes) -> UserChangeInfo? {
        guard changes.changedKeys.count > 0 || changes.originalChanges.count > 0 else { return nil }

        var originalChanges = changes.originalChanges
        let clientChanges = originalChanges.removeValue(forKey: UserClientChangeInfoKey) as? [NSObject : [String : Any]]
        
        if let clientChanges = clientChanges {
            var userClientChangeInfos = [UserClientChangeInfo]()
            clientChanges.forEach {
                let changeInfo = UserClientChangeInfo(object: $0)
                changeInfo.changedKeysAndOldValues = $1 as! [String : NSObject?]
                userClientChangeInfos.append(changeInfo)
            }
            originalChanges[UserClientChangeInfoKey] = userClientChangeInfos as NSObject?
        }
        guard originalChanges.count > 0 || changes.changedKeys.count > 0 else { return nil }
        
        let changeInfo = UserChangeInfo(object: user)
        changeInfo.changedKeysAndOldValues = originalChanges
        changeInfo.changedKeys = changes.changedKeys
        return changeInfo
    }
    
    public required init(object: NSObject) {
        self.user = object as! ZMBareUser
        super.init(object: object)
    }

    open var nameChanged : Bool {
        return changedKeysContain(keys: "name", "displayName")
    }
    
    open var accentColorValueChanged : Bool {
        return changedKeysContain(keys: "accentColorValue")
    }

    open var imageMediumDataChanged : Bool {
        return changedKeysContain(keys: "imageMediumData")
    }

    open var imageSmallProfileDataChanged : Bool {
        return changedKeysContain(keys: "imageSmallProfileData")
    }

    open var profileInformationChanged : Bool {
        return changedKeysContain(keys: "emailAddress", "phoneNumber")
    }

    open var connectionStateChanged : Bool {
        return changedKeysContain(keys: "isConnected", "canBeConnected", "isPendingApprovalByOtherUser", "isPendingApprovalBySelfUser")
    }

    open var trustLevelChanged : Bool {
        return userClientChangeInfos.count != 0
    }

    open var clientsChanged : Bool {
        return changedKeysContain(keys: "clients")
    }

    public var handleChanged : Bool {
        return changedKeysContain(keys: "handle")
    }


    open let user: ZMBareUser
    open var userClientChangeInfos : [UserClientChangeInfo] {
        return changedKeysAndOldValues[UserChangeInfo.UserClientChangeInfoKey] as? [UserClientChangeInfo] ?? []
    }

    
    // MARK Registering UserObservers
    @objc(addUserObserver:forUser:)
    public static func add(observer: ZMUserObserver, for user: ZMUser) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .UserChange,
                                                      object: user,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? UserChangeInfo
                else { return }
            
            observer.userDidChange(changeInfo)
        }
    }
    
    @objc(removeUserObserver:forUser:)
    public static func remove(observer: NSObjectProtocol, for user: ZMUser?) {
        NotificationCenter.default.removeObserver(observer, name: .UserChange, object: user)
    }
    
    
    // MARK Registering SearchUserObservers
    @objc(addSearchUserObserver:forSearchUser:inManagedObjectContext:)
    public static func add(searchUserObserver observer: ZMUserObserver,
                           for user: ZMSearchUser,
                           inManagedObjectContext context: NSManagedObjectContext) -> NSObjectProtocol
    {
        context.searchUserObserverCenter.addSearchUser(user)
        return NotificationCenter.default.addObserver(forName: .SearchUserChange,
                                                      object: user,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? UserChangeInfo
                else { return }
            
            observer.userDidChange(changeInfo)
        }
    }
    
    @objc(removeSearchUserObserver:forSearchUser:)
    public static func remove(searchUserObserver observer: NSObjectProtocol,
                              for user: ZMSearchUser?)
    {
        NotificationCenter.default.removeObserver(observer, name: .SearchUserChange, object: user)
    }
    
    @objc(addSearchUserObserver:forSearchUser:inUserSession:)
    public static func add(searchUserObserver observer: ZMUserObserver,
                           for user: ZMSearchUser,
                           inUserSession userSession: ZMManagedObjectContextProvider) -> NSObjectProtocol
    {
        return add(searchUserObserver: observer, for: user, inManagedObjectContext: userSession.managedObjectContext)
    }

}





