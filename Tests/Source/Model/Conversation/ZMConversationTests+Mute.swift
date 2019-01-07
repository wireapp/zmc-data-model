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
@testable import WireDataModel

extension ZMConversation {
    @objc var isFullyMuted: Bool {
        return mutedMessageTypes == .all
    }
    
    @objc var isOnlyMentionsAndReplies: Bool {
        return mutedMessageTypes == .regular
    }
}

class ZMConversationTests_Mute : ZMConversationTestsBase {

    func testThatItDoesNotCountsSilencedConversationsUnreadContentAsUnread() {
        syncMOC.performGroupedAndWait { _ in
            // given
            XCTAssertEqual(ZMConversation.unreadConversationCount(in: self.syncMOC), 0)
            
            let conversation = self.insertConversation(withUnread: true)
            conversation?.mutedMessageTypes = .all
            
            // when
            XCTAssertTrue(self.syncMOC.saveOrRollback())
            
            // then
            XCTAssertEqual(ZMConversation.unreadConversationCountExcludingSilenced(in: self.syncMOC, excluding: nil), 0)

        }
    }
    
    func testThatTheConversationIsNotSilencedByDefault() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        // then
        XCTAssertEqual(conversation.mutedMessageTypes, .none)
    }

    func testThatItReturnsMutedAllViaGetterForNonTeam() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.mutedMessageTypes = [.regular]
        
        // then
        XCTAssertEqual(conversation.mutedMessageTypes, .all)
    }
}

extension ZMConversationTests_Mute {
    func testMessageShouldNotCreateNotification_SelfMessage() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = conversation.append(text: "Hello")!
        // THEN
        XCTAssertTrue(message.isSilenced)
    }
    
    func testMessageShouldNotCreateNotification_FullySilenced() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.mutedMessageTypes = .all
        let message = conversation.append(text: "Hello")!
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        (message as! ZMClientMessage).sender = user
        // THEN
        XCTAssertTrue(message.isSilenced)
    }
    
    func testMessageShouldNotCreateNotification_RegularSilenced_NotATextMessage() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.mutedMessageTypes = .regular
        let message = conversation.appendKnock()!
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        (message as! ZMClientMessage).sender = user
        // THEN
        XCTAssertTrue(message.isSilenced)
    }
    
    func testMessageShouldNotCreateNotification_RegularSilenced_HasNoMention() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.mutedMessageTypes = .regular
        let message = conversation.append(text: "Hello")!
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        (message as! ZMClientMessage).sender = user
        // THEN
        XCTAssertTrue(message.isSilenced)
    }
    
    func testMessageShouldCreateNotification_NotSilenced() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = conversation.append(text: "Hello")!
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        (message as! ZMClientMessage).sender = user
        // THEN
        XCTAssertFalse(message.isSilenced)
    }
    
    func testMessageShouldCreateNotification_RegularSilenced_HasMention() {
        // GIVEN
        selfUser.teamIdentifier = UUID()
        
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.mutedMessageTypes = .regular
        selfUser.teamIdentifier = UUID()
        let message = conversation.append(text: "@you", mentions: [Mention(range: NSRange(location: 0, length: 4), user: selfUser)], fetchLinkPreview: false, nonce: UUID())!
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        (message as! ZMClientMessage).sender = user
        // THEN
        XCTAssertFalse(message.isSilenced)
    }
    
    func testMessageShouldCreateNotification_RegularSilenced_HasReply() {
        // GIVEN
        selfUser.teamIdentifier = UUID()
        
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.mutedMessageTypes = .regular
        
        let quotedMessage = conversation.append(text: "Hi!", mentions: [], replyingTo: nil, fetchLinkPreview: false, nonce: UUID())!
        (quotedMessage as! ZMClientMessage).sender = selfUser
        
        let message = conversation.append(text: "Hello!", mentions: [], replyingTo: quotedMessage, fetchLinkPreview: false, nonce: UUID())!
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        (message as! ZMClientMessage).sender = user
        
        // THEN
        XCTAssertFalse(message.isSilenced)
    }
}
