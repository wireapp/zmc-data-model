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

private var zmLog = ZMSLog(tag: "SearchUserObserverCenter")

let SearchUserObserverCenterKey = "SearchUserObserverCenterKey"


extension NSManagedObjectContext {
    
    public var searchUserObserverCenter : SearchUserObserverCenter {
        if let observer = self.userInfo[SearchUserObserverCenterKey] as? SearchUserObserverCenter {
            return observer
        }
        
        let newObserver = SearchUserObserverCenter()
        self.userInfo[SearchUserObserverCenterKey] = newObserver
        return newObserver
    }
}

class SearchUserSnapshot  {
    
    /// Keys that we want to be notified for
    static let observableKeys = ["imageMediumData", "imageSmallProfileData", "isConnected", "user", "isPendingApprovalByOtherUser"]
    
    weak var searchUser : ZMSearchUser?
    let snapshotValues : [String : NSObject?]
    
    init(searchUser: ZMSearchUser, snapshotValues : [String : NSObject?]? = nil) {
        self.searchUser = searchUser
        self.snapshotValues = snapshotValues ?? SearchUserSnapshot.createSnapshots(searchUser: searchUser)
    }
    
    /// Creates a snapshot values for the observableKeys keys and stores them
    static func createSnapshots(searchUser: ZMSearchUser) -> [String : NSObject?] {
        return observableKeys.mapToDictionaryWithOptionalValue{
            let value = searchUser.value(forKey: $0)
            if let value = value as? NSObject {
                return value
            }
            if let value = value as? Bool {
                return NSNumber(value: value) as NSObject
            }
            return nil
        }
    }

    /// Creates new snapshot values for the observableKeys keys, compares them to the existing one 
    /// returns a new snapshot and the changes keys if keys changed
    /// or nil when nothing changed
    func updated() -> (snapshot: SearchUserSnapshot, changedKeys: [String])? {
        guard let searchUser = searchUser else { return nil }
        let newSnapshotValues = SearchUserSnapshot.createSnapshots(searchUser: searchUser)
        
        var changedKeys = [String]()
        newSnapshotValues.forEach{
            guard let oldValue = snapshotValues[$0.key] else {
                changedKeys.append($0.key)
                return
            }
            if oldValue != $0.value {
                changedKeys.append($0.key)
            }
        }

        if changedKeys.count > 0 {
            return (snapshot: SearchUserSnapshot(searchUser: searchUser, snapshotValues: newSnapshotValues),
                    changedKeys: changedKeys)
        }
        return nil
    }
}

@objc public class SearchUserObserverCenter : NSObject {
    
    /// Map of searchUser remoteID to snapshot
    var snapshots : [UUID : SearchUserSnapshot] = [:]
    
    /// Adds a snapshots for the specified searchUser if not already present
    public func addSearchUser(_ searchUser: ZMSearchUser) {
        guard let remoteID = searchUser.remoteIdentifier else {
            zmLog.warn("SearchUserObserverCenter: SearchUser does not have a remoteIdentifier? \(searchUser)")
            return 
        }
        snapshots[remoteID] = snapshots[remoteID] ?? SearchUserSnapshot(searchUser: searchUser)
    }
    
    /// Removes all snapshots for searchUsers that are not contained in this set
    /// This should be called when the searchDirectory changes
    public func searchDirectoryDidUpdate(newSearchUsers: [ZMSearchUser]){
        let remoteIDs = newSearchUsers.flatMap{$0.remoteIdentifier}
        let currentRemoteIds = Set(snapshots.keys)
        let toRemove = currentRemoteIds.subtracting(remoteIDs)
        toRemove.forEach{snapshots.removeValue(forKey: $0)}
    }
    
    /// Removes the snapshots for the specified searchUser
    public func removeSearchUser(_ searchUser: ZMSearchUser) {
        guard let remoteID = searchUser.remoteIdentifier else {
            zmLog.warn("SearchUserObserverCenter: SearchUser does not have a remoteIdentifier? \(searchUser)")
            return
        }
        snapshots.removeValue(forKey: remoteID)
    }
    
    /// Removes all snapshots
    /// This needs to be called when tearing down the search directory
    public func reset(){
        snapshots = [:]
    }
    
    /// Matches the userChangeInfo with the searchUser snapshots and updates those if needed
    func usersDidChange(changeInfos: [UserChangeInfo]){
        changeInfos.forEach{ info in
            guard info.nameChanged || info.imageMediumDataChanged || info.imageSmallProfileDataChanged || info.connectionStateChanged,
                  let user = info.user as? ZMUser,
                  let remoteID = user.remoteIdentifier,
                  let snapshot = snapshots[remoteID]
            else {
                return
            }
            
            guard let searchUser = snapshot.searchUser else {
                zmLog.warn("SearchUserObserverCenter: SearchUser was deallocated, but snapshot not removed. Did you forget to unregister as an observer?")
                snapshots.removeValue(forKey: remoteID)
                return
            }
            
            guard let (newSnapshot, changes) = snapshot.updated() else {
                return
            }
            
            snapshots[remoteID] = newSnapshot
            postNotification(searchUser: searchUser, changes: changes)
        }
        
    }
    
    /// Updates the snapshot of the given searchUser
    @objc public func notifyUpdatedSearchUser(_ searchUser : ZMSearchUser){
        guard let remoteID = searchUser.remoteIdentifier,
            let snapshot = snapshots[remoteID],
            let (newSnapshot, changes) = snapshot.updated()
        else { return }
        
        snapshots[remoteID] = newSnapshot
        postNotification(searchUser: searchUser, changes: changes)
        
    }
    
    /// Post a UserChangeInfo for the specified SearchUser
    func postNotification(searchUser: ZMSearchUser, changes: [String]) {
        let userChange = UserChangeInfo(object: searchUser)
        userChange.changedKeysAndOldValues = Dictionary(keys: changes, repeatedValue: .none as Optional<NSObject>)
        NotificationCenter.default.post(name: .SearchUserChange, object: searchUser, userInfo: ["changeInfo" : userChange])
    }
    
}

