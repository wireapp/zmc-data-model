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

import XCTest

@testable import WireDataModel

class ZMConversationTests_Confirmations: ZMConversationTestsBase {


    func testThatConfirmUnreadMessagesAsRead_DoesntConfirmAlreadyReadMessages() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        
        let user1 = createUser()!
        let user2 = createUser()!
        
        let message1 = conversation.append(text: "text1") as! ZMClientMessage
        let message2 = conversation.append(text: "text2") as! ZMClientMessage
        let message3 = conversation.append(text: "text3") as! ZMClientMessage
        let message4 = conversation.append(text: "text4") as! ZMClientMessage
        
        [message1, message2, message3, message4].forEach({ $0.expectsReadConfirmation = true })
        
        message1.sender = user2
        message2.sender = user1
        message3.sender = user2
        message4.sender = user1
        
        conversation.conversationType = .group
        conversation.lastReadServerTimeStamp = message1.serverTimestamp
        
        // when
        var confirmMessages = conversation.confirmUnreadMessagesAsRead(until: .distantFuture)
        
        // then
        XCTAssertEqual(confirmMessages.count, 2)
        
        if (confirmMessages[0].genericMessage?.confirmation.firstMessageId != message2.nonce?.transportString()) {
            // Confirm messages order is not stable so we need swap if they are not in the expected order
            confirmMessages.swapAt(0, 1)
        }
        
        XCTAssertEqual(confirmMessages[0].genericMessage?.confirmation.firstMessageId, message2.nonce?.transportString())
        XCTAssertEqual(confirmMessages[0].genericMessage?.confirmation.moreMessageIds as! [String], [message4.nonce!.transportString()])
        XCTAssertEqual(confirmMessages[1].genericMessage?.confirmation.firstMessageId, message3.nonce?.transportString())
        XCTAssertNil(confirmMessages[1].genericMessage?.confirmation.moreMessageIds)
    }
    
    func testThatConfirmUnreadMessagesAsRead_DoesntConfirmMessageAfterTheTimestamp() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        
        let user1 = createUser()!
        let user2 = createUser()!
        
        let message1 = conversation.append(text: "text1") as! ZMClientMessage
        let message2 = conversation.append(text: "text2") as! ZMClientMessage
        let message3 = conversation.append(text: "text3") as! ZMClientMessage
        
        [message1, message2, message3].forEach({ $0.expectsReadConfirmation = true })
        
        message1.sender = user1
        message2.sender = user1
        message3.sender = user2
        
        conversation.conversationType = .group
        conversation.lastReadServerTimeStamp = .distantPast
        
        // when
        var confirmMessages = conversation.confirmUnreadMessagesAsRead(until: message2.serverTimestamp!)
        
        // then
        XCTAssertEqual(confirmMessages.count, 1)
        XCTAssertEqual(confirmMessages[0].genericMessage?.confirmation.firstMessageId, message1.nonce?.transportString())
        XCTAssertEqual(confirmMessages[0].genericMessage?.confirmation.moreMessageIds as! [String], [message2.nonce!.transportString()])
    }
    
    func testThatConfirmSentMessagesAsDelivered() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        
        let user1 = createUser()!
        let user2 = createUser()!
        
        let message1 = conversation.append(text: "text1") as! ZMClientMessage
        let message2 = conversation.append(text: "text2") as! ZMClientMessage
        let message3 = conversation.append(text: "text3") as! ZMClientMessage
        
        [message1, message2, message3].forEach({ $0.markAsSent() })
        
        message1.sender = user1
        message2.sender = user1
        message3.sender = user2
        
        conversation.conversationType = .group
        conversation.lastReadServerTimeStamp = .distantPast
        
        // when
        let confirmMessages = conversation.confirmMessagesAsDelivered()
        
        // then
        XCTAssertEqual(confirmMessages.count, 1)
        
        let confirmation = confirmMessages[0].genericMessage?.confirmation
        XCTAssertNotNil(confirmation)
        XCTAssertEqual(confirmation?.type, ZMConfirmationType.DELIVERED)
        XCTAssertEqual(confirmation?.firstMessageId, message1.nonce?.transportString())
        XCTAssertEqual(confirmation?.moreMessageIds as! [String],
                       [message2.nonce!.transportString(), message3.nonce?.transportString()])
    }
}
