////
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

import XCTest
import WireDataModel

class LinkDetectionTests: XCTestCase {

    func testThatItDetectsNoLinks() {
        // GIVEN
        let text = "Hello!"

        // WHEN
        let detectedLinks = NSDataDetector.detectLinks(in: text)

        // THEN
        XCTAssertEqual(detectedLinks, [])
    }

    func testThatItDetectsOneLink() {
        // GIVEN
        let text = "Hello! https://wire.com"

        // WHEN
        let detectedLinks = NSDataDetector.detectLinks(in: text)

        // THEN
        XCTAssertEqual(detectedLinks, [URL(string: "https://wire.com")!])
    }

    func testThatItDetectsLinksWithSpecialCharacters() {
        // GIVEN
        let text = "Read this! fr.wikipedia.org/wiki/panda_géant"

        // WHEN
        let detectedLinks = NSDataDetector.detectLinks(in: text)

        // THEN
        XCTAssertEqual(detectedLinks, [URL(string: "http://fr.wikipedia.org/wiki/panda_g%C3%A9ant")!])
    }

    func testThatItDetectsLinkWithPunycode() {
        // GIVEN
        let text = "Read this! https://🐼.com"

        // WHEN
        let detectedLinks = NSDataDetector.detectLinks(in: text)

        // THEN
        XCTAssertEqual(detectedLinks, [URL(string: "https://xn--hp8h.com")!])
    }

    func testThatItDetectsMultipleLinks() {
        // GIVEN
        let text = "Read these! https://🐼.com fr.wikipedia.org/wiki/panda_géant"

        // WHEN
        let detectedLinks = NSDataDetector.detectLinks(in: text)

        // THEN
        XCTAssertEqual(detectedLinks, [URL(string: "https://xn--hp8h.com")!, URL(string: "http://fr.wikipedia.org/wiki/panda_g%C3%A9ant")!])
    }

}

