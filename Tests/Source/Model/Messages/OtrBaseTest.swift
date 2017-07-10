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
import XCTest

class OtrBaseTest: XCTestCase {
    override func setUp() {
        super.setUp()
        
        //clean stored cryptobox files
        if let items =  (try? FileManager.default.contentsOfDirectory(at: OtrBaseTest.sharedContainerURL, includingPropertiesForKeys: nil, options: [])) {
            items.forEach{ try? FileManager.default.removeItem(at: $0) }
        }
    }
    
    static var sharedContainerURL : URL {
        return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
    
    static func otrDirectoryURL(accountIdentifier: UUID) -> URL {
        return FileManager.keyStoreURLForAccount(with: accountIdentifier, in: sharedContainerURL, createParentIfNeeded: true)
    }
    
    static var legacyOtrDirectory : URL {
        return FileManager.keyStoreURLForAccount(with: nil, in: sharedContainerURL, createParentIfNeeded: true)
    }
    
    static func otrDirectory(accountIdentifier: UUID) -> URL {
        var url : URL?
        do {
            url = self.otrDirectoryURL(accountIdentifier: accountIdentifier)
            try FileManager.default.createDirectory(at: url!, withIntermediateDirectories: true, attributes: nil)
        }
        catch let err as NSError {
            if (url == nil) {
                fatal("Unable to initialize otrDirectory = error: \(err)")
            }
        }
        return url!
    }
}
