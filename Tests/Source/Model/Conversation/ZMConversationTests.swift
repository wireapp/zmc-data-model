//
//  ZMConversationTests.swift
//  WireDataModelTests
//
//  Created by Bill, Yiu Por Chan on 21.06.21.
//  Copyright © 2021 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMConversationTests {
    func testThatClearingMessageHistorySetsLastReadServerTimeStampToLastServerTimeStamp() {
        // given
        let clearedTimeStamp = Date()

        let otherUser = createUser()
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.lastServerTimeStamp = clearedTimeStamp

        let message1 = ZMClientMessage(nonce: NSUUID.create(), managedObjectContext: uiMOC)
        message1.serverTimestamp = clearedTimeStamp
        message1.sender = otherUser
        message1.visibleInConversation = conversation

        XCTAssertNil(conversation.lastReadServerTimeStamp)

        // when
        conversation.clearMessageHistory()
        uiMOC.saveOrRollback()
        _ = waitForAllGroupsToBeEmpty(withTimeout: 0.5)

        // then
        XCTAssertEqual(conversation.lastReadServerTimeStamp, clearedTimeStamp)
    }
}
