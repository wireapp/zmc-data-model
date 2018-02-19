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
import WireSystem
import WireImages

protocol Cache {
    
    /// Returns the asset data for a given key. This will probably cause I/O
    func assetData(_ key: String) -> Data?
    
    /// Returns the file URL (if any) for a given key.
    func assetURL(_ key: String) -> URL?
    
    /// Stores the asset data for a given key. This will probably cause I/O
    func storeAssetData(_ data: Data, key: String)
    
    /// Stores the asset data for a source url that must be a local file. This will probably cause I/O
    func storeAssetFromURL(_ url: URL, key: String)
    
    /// Deletes the data for a key. This will cause I/O
    func deleteAssetData(_ key: String)
    
    /// Checks if the data exists in the cache. Faster than checking the data itself
    func hasDataForKey(_ key: String) -> Bool
}
