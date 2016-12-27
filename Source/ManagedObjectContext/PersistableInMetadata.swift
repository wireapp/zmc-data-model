//
//  PersistableInMetadata.swift
//  ZMCDataModel
//
//  Created by Marco Conti on 27/12/2016.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension NSManagedObjectContext {
    
    public func setPersistentStore(metadata: String?, for key: String) {
        if let string = metadata {
            self.setPersistentStore(string as NSString, forKey: key)
        } else {
            self.setPersistentStore(nil, forKey: key)
        }
    }
}
