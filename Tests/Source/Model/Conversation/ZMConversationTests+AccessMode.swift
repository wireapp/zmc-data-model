//
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

import Foundation
import XCTest
@testable import WireDataModel

class ZMConversationAccessModeTests: ZMConversationTestsBase {
    func conversation() -> ZMConversation {
        return ZMConversation.insertNewObject(in: self.uiMOC)
    }
    
    var sut: ZMConversation!
    
    override func setUp() {
        super.setUp()
        sut = conversation()
    }
    
    override func tearDown() {
        super.tearDown()
        sut = nil
    }
    
    func testThatItCanSetTheMode() {
        // when
        sut.accessMode = .allowGuests
        // then
        XCTAssertEqual(sut.accessMode, .allowGuests)
    }
    
    func testDefaultMode() {
        // when & then
        XCTAssertEqual(sut.accessMode, nil)
    }
    
    func testThatItCanReadTheMode() {
        // when
        sut.accessMode = []
        // then
        XCTAssertEqual(sut.accessMode, [])
    }

    func testThatItIgnoresAccessModeStringsKey() {
        // given
        sut.accessModeStrings = ["invite"]
        // when
        XCTAssertTrue(self.uiMOC.saveOrRollback())
        // then
        XCTAssertFalse(sut.keysThatHaveLocalModifications.contains("accessModeStrings"))
    }
    
    let testSet: [(ConversationAccessMode?, [String]?)] = [(nil, nil),
                                                           (ConversationAccessMode(), []),
                                                           (ConversationAccessMode.code, ["code"]),
                                                           (ConversationAccessMode.invite, ["invite"]),
                                                           (ConversationAccessMode.legacy, ["invite"]),
                                                           (ConversationAccessMode.allowGuests, ["code", "invite"])]
    
    func testThatModeSetWithOptionSetReflectedInStrings() {
        testSet.forEach {
            // when
            sut.accessMode = $0
            // then
            if let strings = $1 {
                XCTAssertEqual(sut.accessModeStrings!, strings)
            }
            else {
                XCTAssertTrue(sut.accessModeStrings == nil)
            }
        }
    }
    
    func testThatModeSetWithStringsIsReflectedInOptionSet() {
        testSet.forEach {
            // when
            sut.accessModeStrings = $1
            // then
            if let optionSet = $0 {
                XCTAssertEqual(sut.accessMode!, optionSet)
            }
            else {
                XCTAssertTrue(sut.accessMode == nil)
            }
        }
    }
    
}

