//
//  File.swift
//  ZMCDataModel
//
//  Created by Marco Conti on 01/02/2017.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension NSManagedObjectContext {
    
    /// Applies the required patches for the current version of the persisted data
    public func applyPersistedDataPatchesForCurrentVersion() {
        PersistedDataPatch.applyAll(in: self)
    }
}
