//
//  NSManagedObjectContext+TearDown.swift
//  WireDataModel
//
//  Created by Marco Conti on 19.07.17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension NSManagedObjectContext {
    
    /// Tear down the context. Using the context after this call results in
    /// undefined behavior.
    public func tearDown() {
        self.performGroupedBlockAndWait {
            self.userInfo.removeAllObjects()
            let objects = self.registeredObjects
            objects.forEach {
                self.refresh($0, mergeChanges: false)
            }
        }
    }
}
