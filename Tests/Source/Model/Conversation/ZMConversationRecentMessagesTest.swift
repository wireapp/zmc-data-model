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

final class ManagedObjectContextChangesMerger: NSObject {
    let managedObjectContexts: Set<NSManagedObjectContext>
    
    init(managedObjectContexts: Set<NSManagedObjectContext>) {
        self.managedObjectContexts = managedObjectContexts
        super.init()
        managedObjectContexts.forEach { moc in
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(ManagedObjectContextChangesMerger.contextDidSave(_:)),
                                                   name: NSNotification.Name.NSManagedObjectContextDidSave,
                                                   object: moc)
        }
    }
    
    @objc func contextDidSave(_ notification: Notification) {
        let mocThatSaved = notification.object as! NSManagedObjectContext
        managedObjectContexts.subtracting(Set(arrayLiteral: mocThatSaved)).forEach { moc in
            moc.performGroupedBlockAndWait {
                moc.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
}

public class ZMConversationRecentMessagesTest: ZMBaseManagedObjectTest {
    func createConversation(on moc: NSManagedObjectContext? = nil) -> ZMConversation {
        let conversation = ZMConversation.insertNewObject(in: moc ?? uiMOC)
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        return conversation
    }
    
    var changesObserver: ManagedObjectContextChangesMerger!
    
    override public func setUp() {
        super.setUp()
        changesObserver = ManagedObjectContextChangesMerger(managedObjectContexts: Set([self.uiMOC, self.syncMOC]))
    }
    
    override public func tearDown() {
        changesObserver = nil
        super.tearDown()
    }
    
    func testThatItFetchesRecentMessages() throws {
        // GIVEN
        let conversation = createConversation()
        
        // WHEN
        (0...40).forEach { i in
            conversation.appendMessage(withText: "\(i)")
        }
        
        // THEN
        XCTAssertEqual(conversation.recentMessages.count, 41)
        XCTAssertNotNil(conversation.recentMessages[0].textMessageData)
        XCTAssertEqual(conversation.recentMessages[0].textMessageData!.messageText, "0")
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
        XCTAssertEqual(conversation.recentMessages[0].textMessageData!.messageText, "1")
        
        XCTAssertEqual(otherConversation.recentMessages[0].textMessageData!.messageText, "Other 1")

    }
    
    func testThatMessagesMergedFromUIContextAppearOnSyncContext() {
        // GIVEN
        let conversation = self.createConversation(on: uiMOC)
        uiMOC.saveOrRollback()
        let conversationID = conversation.objectID
        var syncConversation: ZMConversation!
        syncMOC.performGroupedBlockAndWait {
            syncConversation = self.syncMOC.object(with: conversationID) as! ZMConversation
        }
        // WHEN & THEN
        verifyUpdatedMessages(from: conversation, to: syncConversation)
    }
    
    func testThatMessagesMergedFromSyncContextAppearOnUIContext() {
        // GIVEN
        var conversationID: NSManagedObjectID!
        var syncConversation: ZMConversation!
        syncMOC.performGroupedBlockAndWait {
            syncConversation = self.createConversation(on: self.syncMOC)
            self.syncMOC.saveOrRollback()
            conversationID = syncConversation.objectID
        }
        
        let conversation = uiMOC.object(with: conversationID) as! ZMConversation
        // WHEN & THEN
        syncMOC.performGroupedBlock {
            self.verifyUpdatedMessages(from: syncConversation, to: conversation)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }
    
    func verifyUpdatedMessages(from conversation: ZMConversation,
                               to otherContextConversation: ZMConversation) {

        // AND WHEN
        otherContextConversation.managedObjectContext!.performGroupedBlockAndWait {
            XCTAssertEqual(otherContextConversation.recentMessages.count, 0)
        }
        // WHEN
        let _ = conversation.appendMessage(withText: "Hello")
        conversation.managedObjectContext!.saveOrRollback()
    
        // THEN
        otherContextConversation.managedObjectContext!.performGroupedBlock {
            XCTAssertEqual(otherContextConversation.allMessages.count, 1)
            XCTAssertEqual(otherContextConversation.recentMessages.count, 1)
        }

    }
    
}
