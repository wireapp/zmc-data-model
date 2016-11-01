//
//  ZMBaseManagedObjectTest.swift
//  ZMCDataModel
//
//  Created by Marco Conti on 01/11/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMBaseManagedObjectTest {
    
    @objc public func createClient(user: ZMUser, createSessionWithSelfUser: Bool, managedObjectContext: NSManagedObjectContext) -> UserClient {
        if user.remoteIdentifier == nil {
            user.remoteIdentifier = UUID.create()
        }
        
        let userClient = UserClient.insertNewObject(in: managedObjectContext)
        userClient.remoteIdentifier = NSString.createAlphanumerical()
        userClient.user = user
        
        if createSessionWithSelfUser {
            let selfClient = ZMUser.selfUser(in: managedObjectContext).selfClient()!
            self.performPretendingUiMocIsSyncMoc {
                let key = try! selfClient.keysStore.lastPreKey()
                _ = selfClient.establishSessionWithClient(userClient, usingPreKey: key)
            }
        }
        return userClient
    }
}
