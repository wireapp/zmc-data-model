//
//  NotificationDispatcherTests.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 10/01/17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation

class ConversationObserver: NSObject, ZMConversationObserver {
    
    var changes = [ConversationChangeInfo]()
    
    func conversationDidChange(_ note: ConversationChangeInfo!) {
        changes.append(note)
    }
}

class NotificationDispatcherTests : ZMBaseManagedObjectTest {

    var sut : NotificationDispatcher!
    var conversationObserver : ConversationObserver!
    
    override func setUp() {
        super.setUp()
        conversationObserver = ConversationObserver()
        sut = NotificationDispatcher(managedObjectContext: uiMOC)
    }
    
    override func tearDown() {
        sut.tearDown()
        sut = nil
        super.tearDown()
    }
    
    func testThatItNotifiesAboutChanges(){
        
        // given
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        uiMOC.saveOrRollback()
        
        let token = ConversationChangeInfo.add(observer: conversationObserver, for: conversation)

        // when
        conversation.userDefinedName = "foo"
        uiMOC.processPendingChanges()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversationObserver.changes.count, 1)
        guard let changeInfo = conversationObserver.changes.first else {
            return XCTFail()
        }
        XCTAssertTrue(changeInfo.nameChanged)
        ConversationChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItNotifiesAboutChangesInOtherObjects(){
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.name = "Bernd"
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.conversationType = .group
        conversation.mutableOtherActiveParticipants.add(user)
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        let token = ConversationChangeInfo.add(observer: conversationObserver, for: conversation)
        
        // when
        user.name = "Brett"
        uiMOC.processPendingChanges()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversationObserver.changes.count, 1)
        guard let changeInfo = conversationObserver.changes.first else {
            return XCTFail()
        }
        XCTAssertTrue(changeInfo.nameChanged)
        ConversationChangeInfo.remove(observer: token, for: conversation)
    }
}
