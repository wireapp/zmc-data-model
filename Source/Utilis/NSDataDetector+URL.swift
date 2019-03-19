//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

extension NSDataDetector {

    /**
     * Returns a list of URLs in the specified text message.
     * - parameter text: The text to check.
     * - returns: The list of detected URLs, or an empty array if detection failed.
     */

    @objc(detectLinksInText:)
    public static func detectLinks(in text: String) -> [URL] {
        let textRange = NSRange(text.startIndex ..< text.endIndex, in: text)

        do {
            let urlDetector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = urlDetector.matches(in: text, options: [], range: textRange)
            return matches.compactMap(\.url)
        } catch {
            return []
        }
    }

}
