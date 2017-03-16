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

let previewProfileAssetIdentifierKey = #keyPath(ZMUser.previewProfileAssetIdentifier)
let completeProfileAssetIdentifierKey = #keyPath(ZMUser.completeProfileAssetIdentifier)

extension ZMUser {
    public var previewProfileAssetIdentifier: String {
        set {
            modifyValue(newValue, forKey: previewProfileAssetIdentifierKey)
        }
        get {
            return getValue(forKey: previewProfileAssetIdentifierKey)
        }
    }
    
    public var completeProfileAssetIdentifier: String {
        set {
            modifyValue(newValue, forKey: completeProfileAssetIdentifierKey)
        }
        get {
            return getValue(forKey: completeProfileAssetIdentifierKey)
        }
    }
    
    fileprivate func modifyValue(_ value: Any?, forKey key: String) {
        willChangeValue(forKey: key)
        setPrimitiveValue(value, forKey: key)
        didChangeValue(forKey: key)
        setLocallyModifiedKeys([key])
    }
    
    fileprivate func getValue<T>(forKey key: String) -> T {
        willAccessValue(forKey: key)
        let value = primitiveValue(forKey: key) as! T
        didAccessValue(forKey: key)
        return value
    }
}
