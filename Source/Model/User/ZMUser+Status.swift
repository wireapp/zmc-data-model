//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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


public enum WorkStatus : Int {
    case none, vacation, sick, workFromHome
}

extension ZMUser {
    
    public static func connectionsAndTeamMembers(in context: NSManagedObjectContext) -> Set<ZMUser> {
        var connectionsAndTeamMembers : Set<ZMUser> = Set()
        
        let selfUser = ZMUser.selfUser(in: context)
        let request = NSFetchRequest<ZMUser>(entityName: ZMUser.entityName())
        request.predicate = ZMUser.predicateForConnectedNonBotUsers
        
        let connectedUsers = context.fetchOrAssert(request: request)
        connectionsAndTeamMembers.formUnion(connectedUsers)
        
        if let teamUsers = selfUser.team?.members.flatMap({ $0.user }) {
            connectionsAndTeamMembers.formUnion(teamUsers)
        }
        
        return connectionsAndTeamMembers
    }
    
    public var workStatus : WorkStatus {
        get {
            self.willAccessValue(forKey: WorkStatusKey)
            let value = (self.primitiveValue(forKey: WorkStatusKey) as? NSNumber) ?? NSNumber(value: 0)
            self.didAccessValue(forKey: WorkStatusKey)
            
            return WorkStatus(rawValue: value.intValue) ?? .none
        }
        
        set {
            self.willChangeValue(forKey: WorkStatusKey)
            self.setPrimitiveValue(NSNumber(value: newValue.rawValue), forKey: WorkStatusKey)
            self.didChangeValue(forKey: WorkStatusKey)
        }
    }
    
}
