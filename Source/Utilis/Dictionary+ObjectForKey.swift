//
//  Dictionary+ObjectForKey.swift
//  WireDataModel
//
//  Created by David Henner on 03.04.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

public extension Dictionary {
    func string(forKey key: String) -> String? {
        return (self as NSDictionary).string(forKey: key)
    }
    
    func optionalString(forKey key: String) -> String? {
        return (self as NSDictionary).optionalString(forKey: key)
    }
    
    func dictionary(forKey key: String) -> [String: AnyObject]? {
        return (self as NSDictionary).dictionary(forKey: key)
    }
}
