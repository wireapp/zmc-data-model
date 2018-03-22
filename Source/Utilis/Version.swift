//
//  Version.swift
//  WireDataModel
//
//  Created by Zeta on 22.03.18.
//  Copyright © 2018 Wire Swiss GmbH. All rights reserved.
//

import Foundation

@objc(ZMVersion) final public class Version: NSObject, Comparable {
    
    public private(set) var versionString: String
    public private(set) var arrayRepresentation: [Int]
    
    @objc(initWithVersionString:)
    public init(string: String) {
        versionString = string
        arrayRepresentation = Version.integerComponents(of: string)
        super.init()
    }
    
    private static func integerComponents(of string: String) -> [Int] {
        return string.components(separatedBy: ".").map {
            ($0 as NSString).integerValue
        }
    }
    
    @objc(compareWithVersion:)
    public func compare(with otherVersion: Version) -> ComparisonResult {
        guard otherVersion.arrayRepresentation.count > 0 else { return .orderedDescending }
        guard versionString != otherVersion.versionString else { return .orderedSame }
        
        for i in 0..<arrayRepresentation.count {
            guard otherVersion.arrayRepresentation.count != i else { return .orderedDescending }
            let selfNumber = arrayRepresentation[i]
            let otherNumber = otherVersion.arrayRepresentation[i]
            
            if selfNumber > otherNumber {
                return .orderedDescending
            } else if selfNumber < otherNumber {
                return .orderedAscending
            }
        }
        
        if arrayRepresentation.count < otherVersion.arrayRepresentation.count {
            return .orderedAscending
        }
        
        return .orderedSame
    }
    
    
    public override var description: String {
        return arrayRepresentation.map { "\($0)" }.joined(separator: ".")
    }
    
    public override var debugDescription: String {
        return String(format: "<%@ %p> %@", NSStringFromClass(type(of: self)), self, description)
    }
    
}

// MARK: - Operators

public func ==(lhs: Version, rhs: Version) -> Bool {
    return lhs.compare(with: rhs) == .orderedSame
}

public func <(lhs: Version, rhs: Version) -> Bool {
    return lhs.compare(with: rhs) == .orderedAscending
}
