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

/// - seealso: https://en.wikipedia.org/wiki/Pairing_function#Cantor_pairing_function
fileprivate func pair<I: Integer>(_ a: I, _ b: I) -> I {
    return ((a + b) * (a + b + 1) / 2) + b
}

@objc public class ZMMovedIndex: NSObject {
    
    public let from: UInt
    public let to: UInt
    
    public init(from: UInt, to: UInt) {
        self.from = from
        self.to = to
        super.init()
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ZMMovedIndex else { return false }
        return other.from == self.from && other.to == self.to
    }
    
    public override var hash: Int {
        return Int(pair(from, to))
    }
}
