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

public class ZMConversationRecentMessagesTest: ZMBaseManagedObjectTest {
    func createConversation() -> ZMConversation {
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        return conversation
    }
    
    func testThatItFetchesRecentMessages() throws {
        // GIVEN
        let conversation = createConversation()
        
        // WHEN
        (0...40).forEach { i in
            conversation.appendMessage(withText: "\(i)")
        }
        
        // THEN
        XCTAssertEqual(conversation.recentMessages.count, 30)
        XCTAssertNotNil(conversation.recentMessages[0].textMessageData)
        XCTAssertEqual(conversation.recentMessages[0].textMessageData!.messageText, "40")
    }
    
    func testThatItDoesNotIncludeMessagesFromOtherConversations() {
        // GIVEN
        let conversation = createConversation()
        let otherConversation = createConversation()
        
        // WHEN
        (1...10).forEach { i in
            conversation.appendMessage(withText: "\(i)")
        }
        
        (1...10).forEach { i in
            otherConversation.appendMessage(withText: "Other \(i)")
        }
        
        // THEN
        XCTAssertEqual(conversation.recentMessages.count, 10)
        XCTAssertNotNil(conversation.recentMessages[0].textMessageData)
        XCTAssertEqual(conversation.recentMessages[0].textMessageData!.messageText, "10")
        
        XCTAssertEqual(otherConversation.recentMessages[0].textMessageData!.messageText, "Other 10")

    }
}
