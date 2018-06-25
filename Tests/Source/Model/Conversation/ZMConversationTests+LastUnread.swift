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

// TODO jacob split up this test class into multiple files
class ZMConversationTests_LastUnread: ZMConversationTestsBase {
    
    // MARK: - Unread Count
    
    // TODO jacob
    func testThatLastUnreadKnockDateIsSetWhenMessageInserted() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    // TODO jacob
    func testThatLastUnreadMissedCallDateIsSetWhenMessageInserted() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testThatUnreadCountIsUpdatedWhenMessageIsInserted() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let timestamp = Date()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            let message = ZMClientMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            message.serverTimestamp = timestamp
            message.visibleInConversation = conversation
            
            // when
            conversation.updateTimestampsAfterInsertingMessage(message)
            
            // then
            XCTAssertEqual(conversation.estimatedUnreadCount, 1)
        }
    }
    
    func testThatUnreadCountIsUpdatedWhenMessageIsDeleted() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let timestamp = Date()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            let message = ZMClientMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            message.serverTimestamp = timestamp
            message.visibleInConversation = conversation
            conversation.updateTimestampsAfterInsertingMessage(message)
            XCTAssertEqual(conversation.estimatedUnreadCount, 1)
            
            // when
            message.visibleInConversation = nil
            conversation.updateTimestampsAfterDeletingMessage()
            
            // then
            XCTAssertEqual(conversation.estimatedUnreadCount, 0)
        }
    }
    
    // MARK: - Modified Date
    
    func testThatModifiedDateIsUpdatedWhenMessageInserted() {
        // given
        let timestamp = Date()
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.serverTimestamp = timestamp
        
        // when
        conversation.updateTimestampsAfterInsertingMessage(message)
        
        // then
        XCTAssertEqual(conversation.lastModifiedDate, timestamp)
    }
    
    func testThatModifiedDateIsNotUpdatedWhenMessageWhichShouldNotUpdateModifiedDateIsInserted() {
        // given
        let timestamp = Date()
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = ZMSystemMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.systemMessageType = .participantsRemoved
        message.serverTimestamp = timestamp
        
        // when
        conversation.updateTimestampsAfterInsertingMessage(message)
        
        // then
        XCTAssertNil(conversation.lastModifiedDate)
    }
        
    // MARK: - Last Read Date
    
    func testThatLastReadDateIsUpdatedWhenMessageFromSelfUserInserted() {
        // given
        let timestamp = Date()
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.serverTimestamp = timestamp
        message.sender = selfUser
        
        // when
        conversation.updateTimestampsAfterInsertingMessage(message)
        
        // then
        XCTAssertEqual(conversation.lastReadServerTimeStamp, timestamp)
    }
    
    func testThatLastReadDateIsNotUpdatedWhenMessageFromOtherUserInserted() {
        // given
        let otherUser = createUser()
        let timestamp = Date()
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.serverTimestamp = timestamp
        message.sender = otherUser
        
        // when
        conversation.updateTimestampsAfterInsertingMessage(message)
        
        // then
        XCTAssertNil(conversation.lastReadServerTimeStamp)
    }
    
    
    // MARK: - First Unread Message
    
    func testThatItReturnsTheFirstUnreadMessageIfWeHaveItLocally() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        
        // when
        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.visibleInConversation = conversation
        
        // then
        XCTAssertEqual(conversation.firstUnreadMessage as? ZMClientMessage, message)
    }
    
    func testThatItReturnsNilIfTheLastReadServerTimestampIsMoreRecent() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.visibleInConversation = conversation
        
        // when
        conversation.lastReadServerTimeStamp = message.serverTimestamp
        
        // then
        XCTAssertNil(conversation.firstUnreadMessage)
    }
    
    func testThatItSkipsMessagesWhichDoesntGenerateUnreadDotsDirectlyBeforeFirstUnreadMessage() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        
        // when
        let messageWhichDoesntGenerateUnreadDot = ZMSystemMessage(nonce: UUID(), managedObjectContext: uiMOC)
        messageWhichDoesntGenerateUnreadDot.systemMessageType = .participantsAdded
        messageWhichDoesntGenerateUnreadDot.visibleInConversation = conversation
        
        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.visibleInConversation = conversation
        
        // then
        XCTAssertEqual(conversation.firstUnreadMessage as? ZMClientMessage, message)
    }
    
    func testThatTheParentMessageIsReturnedIfItHasUnreadChildMessages() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        
        let systemMessage1 = ZMSystemMessage(nonce: UUID(), managedObjectContext: uiMOC)
        systemMessage1.systemMessageType = .missedCall
        systemMessage1.visibleInConversation = conversation
        conversation.lastReadServerTimeStamp = systemMessage1.serverTimestamp
        
        // when
        let systemMessage2 = ZMSystemMessage(nonce: UUID(), managedObjectContext: uiMOC)
        systemMessage2.systemMessageType = .missedCall
        systemMessage2.hiddenInConversation = conversation
        systemMessage2.parentMessage = systemMessage1
        
        // then
        XCTAssertEqual(conversation.firstUnreadMessage as? ZMSystemMessage, systemMessage1)
    }
    
    func testThatTheParentMessageIsNotReturnedIfAllChildMessagesAreRead() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        
        let systemMessage1 = ZMSystemMessage(nonce: UUID(), managedObjectContext: uiMOC)
        systemMessage1.systemMessageType = .missedCall
        systemMessage1.visibleInConversation = conversation
        
        let systemMessage2 = ZMSystemMessage(nonce: UUID(), managedObjectContext: uiMOC)
        systemMessage2.systemMessageType = .missedCall
        systemMessage2.hiddenInConversation = conversation
        systemMessage2.parentMessage = systemMessage1
        
        // when
        conversation.lastReadServerTimeStamp = systemMessage2.serverTimestamp
        
        // then
        XCTAssertNil(conversation.firstUnreadMessage)
    }
    
    
}
