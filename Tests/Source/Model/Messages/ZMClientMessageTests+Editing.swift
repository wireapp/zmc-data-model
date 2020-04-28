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

class ZMClientMessageTests_Editing: BaseZMClientMessageTests {
    func testThatItEditsTheMessage() {
        // GIVEN
        let conversationID = UUID.create()
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.remoteIdentifier = conversationID
        
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID.create()
        
        let nonce = UUID.create()
        let message = ZMClientMessage(nonce: nonce, managedObjectContext: uiMOC)
        message.sender = user
        let data = try? GenericMessage(content: Text(content: "text")).serializedData()
        message.add(data)
        conversation.append(message)
        
        let edited = MessageEdit.with {
            $0.replacingMessageID = nonce.transportString()
            $0.text = Text(content: "editedText")
        }
        
        let genericMessage = GenericMessage(content: edited)
        
        let updateEvent = createUpdateEvent(nonce, conversationID: conversationID, genericMessage: genericMessage, senderID: message.sender!.remoteIdentifier)
        
        // WHEN
        var editedMessage: ZMClientMessage?
        performPretendingUiMocIsSyncMoc {
            editedMessage = ZMClientMessage.editMessage(withEdit: edited, forConversation: conversation, updateEvent: updateEvent, inContext: self.uiMOC, prefetchResult: ZMFetchRequestBatchResult())
        }
        
        // THEN
        XCTAssertEqual(editedMessage?.messageText, "editedText")
    }
}

class ZMClientMessageTests_TextMessageData : BaseZMClientMessageTests {
    
    func testThatItUpdatesTheMesssageText_WhenEditing(){
        
        // given
        let conversation = ZMConversation.insertNewObject(in:uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let message = conversation.append(text: "hello") as! ZMClientMessage
        message.delivered = true
        
        // when
        message.textMessageData?.editText("good bye", mentions: [], fetchLinkPreview: false)
        
        // then
        XCTAssertEqual(message.textMessageData?.messageText, "good bye")
    }
    
    func testThatItClearReactions_WhenEditing(){
        
        // given
        let conversation = ZMConversation.insertNewObject(in:uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let message = conversation.append(text: "hello") as! ZMClientMessage
        message.delivered = true
        message.addReaction("🤠", forUser: selfUser)
        XCTAssertFalse(message.reactions.isEmpty)
        
        // when
        message.textMessageData?.editText("good bye", mentions: [], fetchLinkPreview: false)
        
        // then
        XCTAssertTrue(message.reactions.isEmpty)
    }
    
    func testThatItKeepsQuote_WhenEditing(){
        
        // given
        let conversation = ZMConversation.insertNewObject(in:uiMOC)
        conversation.remoteIdentifier = UUID.create()
        
        let quotedMessage = conversation.append(text: "Let's grab some lunch") as! ZMClientMessage
        let message = conversation.append(text: "Yes!", replyingTo: quotedMessage) as! ZMClientMessage
        message.delivered = true
        XCTAssertTrue(message.hasQuote)
        
        // when
        message.textMessageData?.editText("good bye", mentions: [], fetchLinkPreview: false)
        
        // then
        XCTAssertTrue(message.hasQuote)
    }
    
}
