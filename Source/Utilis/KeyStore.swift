//
//  KeyStore.swift
//  ZMCDataModel
//
//  Created by Marco Conti on 01/11/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation
import Cryptobox

public protocol KeyStore {
    
    var encryptionContext : EncryptionContext { get }
    
    /// Generates the last prekey (fallback prekey). This should not be
    /// generated more than once, or the previous last prekey will be invalidated.
    func lastPreKey() throws -> String
    
    /// Generates prekeys in a range. This should not be called more than once
    /// for a given range, or the previously generated prekeys will be invalidated.
    func generatePreKeys(_ count: UInt16 , start: UInt16) throws -> [(id: UInt16, prekey: String)]
    
}
