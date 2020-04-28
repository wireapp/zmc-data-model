//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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
@testable import WireDataModel


class ZMMessageTests_Removal: BaseZMClientMessageTests {
    func testThatAMessageIsRemovedWhenAskForDeletionWithMessageHide() {
        // GIVEN
        
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let nonce = UUID.create()
        var textMessage: ZMTextMessage? = ZMTextMessage(nonce: nonce, managedObjectContext: uiMOC)
        textMessage?.visibleInConversation = conversation
        
        let hidden = MessageHide.with {
            $0.conversationID = conversation.remoteIdentifier!.transportString()
            $0.messageID = nonce.transportString()
        }
        
        // sanity check
        XCTAssertNotNil(textMessage)
        uiMOC.saveOrRollback()
        
        // WHEN
        performPretendingUiMocIsSyncMoc {
            ZMMessage.remove(remotelyHiddenMessage: hidden, inContext: self.uiMOC)
        }
        uiMOC.saveOrRollback()
        
        // THEN
        textMessage = ZMTextMessage.fetch(withNonce: nonce, for: conversation, in: uiMOC)
        XCTAssertNil(textMessage)
        XCTAssertEqual(conversation.allMessages.count, 0)
    }
    
    func testThatItDeletesTheMessageWithDelete() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let sender = ZMUser.insertNewObject(in: uiMOC)
        sender.remoteIdentifier = UUID.create()
        
        let nonce = UUID.create()
        var textMessage: ZMTextMessage? = ZMTextMessage(nonce: nonce, managedObjectContext: uiMOC)
        textMessage?.sender = sender
        textMessage?.visibleInConversation = conversation
        
        let deleted = MessageDelete.with {
            $0.messageID = nonce.transportString()
        }
        
        // sanity check
        XCTAssertNotNil(textMessage)
        uiMOC.saveOrRollback()
        
        // WHEN
        performPretendingUiMocIsSyncMoc {
            ZMMessage.remove(remotelyDeletedMessage: deleted, inConversation: conversation, senderID: textMessage!.sender!.remoteIdentifier, inContext: self.uiMOC)
        }
        uiMOC.saveOrRollback()
        
        // THEN
        textMessage = ZMTextMessage.fetch(withNonce: nonce, for: conversation, in: uiMOC)
        XCTAssertTrue(textMessage?.hasBeenDeleted ?? false)
    }

    func testThatItIgnoresDeleteWhenFromOtherUser() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let sender = ZMUser.insertNewObject(in: uiMOC)
        sender.remoteIdentifier = UUID.create()
        
        let nonce = UUID.create()
        var textMessage: ZMTextMessage? = ZMTextMessage(nonce: nonce, managedObjectContext: uiMOC)
        textMessage?.sender = sender
        textMessage?.visibleInConversation = conversation
        
        let deleted = MessageDelete.with {
            $0.messageID = nonce.transportString()
        }
        
        // sanity check
        XCTAssertNotNil(textMessage)
        uiMOC.saveOrRollback()
        
        // WHEN
        performPretendingUiMocIsSyncMoc {
            ZMMessage.remove(remotelyDeletedMessage: deleted, inConversation: conversation, senderID: UUID.create(), inContext: self.uiMOC)
        }
        uiMOC.saveOrRollback()
        
        // THEN
        textMessage = ZMTextMessage.fetch(withNonce: nonce, for: conversation, in: uiMOC)
        XCTAssertFalse(textMessage?.hasBeenDeleted ?? true)
    }
    
    func testThatItDoesNotDeleteTheDeletedMessageWithDelete() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let sender = ZMUser.insertNewObject(in: uiMOC)
        sender.remoteIdentifier = UUID.create()
        
        let nonce = UUID.create()
        var textMessage: ZMTextMessage? = ZMTextMessage(nonce: nonce, managedObjectContext: uiMOC)
        textMessage?.sender = sender
        textMessage?.hiddenInConversation = conversation
        
        XCTAssertTrue(textMessage!.hasBeenDeleted)
        
        let deleted = MessageDelete.with {
            $0.messageID = nonce.transportString()
        }
        
        // sanity check
        XCTAssertNotNil(textMessage)
        uiMOC.saveOrRollback()
        
        // WHEN
        performPretendingUiMocIsSyncMoc {
            self.performIgnoringZMLogError {
                ZMMessage.remove(remotelyDeletedMessage: deleted, inConversation: conversation, senderID: textMessage!.sender!.remoteIdentifier, inContext: self.uiMOC)
            }
        }
        uiMOC.saveOrRollback()
        
        // THEN
        textMessage = ZMTextMessage.fetch(withNonce: nonce, for: conversation, in: uiMOC)
        XCTAssertTrue(textMessage?.hasBeenDeleted ?? false)
    }
}
