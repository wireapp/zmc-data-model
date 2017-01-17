//
//  ConversationObserverTests.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 13/01/17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation
@testable import ZMCDataModel

class ConversationObserverTests : NotificationDispatcherTests {
    
    
    func checkThatItNotifiesTheObserverOfAChange(_ conversation : ZMConversation,
                                                 modifier: (ZMConversation, ConversationObserver) -> Void,
                                                 expectedChangedField : String?,
                                                 expectedChangedKeys: KeySet) {
        
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: modifier,
                                                     expectedChangedFields: expectedChangedField != nil ? KeySet(key: expectedChangedField!) : KeySet(),
                                                     expectedChangedKeys: expectedChangedKeys)
    }
    
    var conversationInfoKeys : [String] {
        return [
            "messagesChanged",
            "participantsChanged",
            "nameChanged",
            "lastModifiedDateChanged",
            "unreadCountChanged",
            "connectionStateChanged",
            "isArchivedChanged",
            "isSilencedChanged",
            "conversationListIndicatorChanged"
        ]
    }
    
    func checkThatItNotifiesTheObserverOfAChange(_ conversation : ZMConversation,
                                                 modifier: (ZMConversation, ConversationObserver) -> Void,
                                                 expectedChangedFields : KeySet,
                                                 expectedChangedKeys: KeySet) {
        
        // given
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: conversation)
        
        // when
        modifier(conversation, observer)
        conversation.managedObjectContext!.saveOrRollback()
        
        // then
        let changeCount = observer.changes.count
        if !expectedChangedFields.isEmpty {
            XCTAssertEqual(changeCount, 1, "Observer expected 1 notification, but received \(changeCount).")
        } else {
            XCTAssertEqual(changeCount, 0, "Observer was notified, but DID NOT expect a notification")
        }
        
        // and when
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.changes.count, changeCount, "Should have changed only once")
        
        if expectedChangedFields.isEmpty {
            return
        }
        
        if let changes = observer.changes.first {
            checkChangeInfoContainsExpectedKeys(changes: changes, expectedChangedFields: expectedChangedFields, expectedChangedKeys: expectedChangedKeys)
        }
        
        ConversationChangeInfo.remove(observer:token, for: conversation)
    }
    
    func checkChangeInfoContainsExpectedKeys(changes: ConversationChangeInfo, expectedChangedFields : KeySet, expectedChangedKeys: KeySet){
        for key in conversationInfoKeys {
            if expectedChangedFields.contains(key) {
                if let value = changes.value(forKey: key) as? NSNumber {
                    XCTAssertTrue(value.boolValue, "\(key) was supposed to be true")
                }
                continue
            }
            if let value = changes.value(forKey: key) as? NSNumber {
                XCTAssertFalse(value.boolValue, "\(key) was supposed to be false")
            }
            else {
                XCTFail("Can't find key or key is not boolean for '\(key)'")
            }
        }
        XCTAssertEqual(KeySet(Array(changes.changedKeysAndOldValues.keys)), expectedChangedKeys)
    }
    
    
    func testThatItNotifiesTheObserverOfANameChange()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        conversation.userDefinedName = "George"
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.userDefinedName = "Phil"},
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
        
    }
    
    func notifyNameChange(_ user: ZMUser, name: String) {
        user.name = name
        self.uiMOC.saveOrRollback()
    }
    
    func testThatItNotifiesTheObserverIfTheVoiceChannelStateChanges()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
        otherUser.name = "Foo"
        conversation.mutableOtherActiveParticipants.add(otherUser)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        conversation.callDeviceIsActive = true
                                                        
                                                        self.uiMOC.globalManagedObjectContextObserver.notifyUpdatedCallState(Set(arrayLiteral:conversation), notifyDirectly:true)
            },
                                                     expectedChangedFields: KeySet(["voiceChannelStateChanged", "conversationListIndicatorChanged"]),
                                                     expectedChangedKeys: KeySet(["voiceChannelState", "conversationListIndicator"])
        )
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseOfActiveParticipants()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
        otherUser.name = "Foo"
        conversation.mutableOtherActiveParticipants.add(otherUser)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        self.notifyNameChange(otherUser, name: "Phil")
            },
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
        
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseAnActiveParticipantWasAdded()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        
                                                        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
                                                        otherUser.name = "Foo"
                                                        conversation.mutableOtherActiveParticipants.add(otherUser)
                                                        self.updateDisplayNameGenerator(withUsers: [otherUser])
            },
                                                     expectedChangedFields: KeySet(["nameChanged", "participantsChanged"]),
                                                     expectedChangedKeys: KeySet(["displayName", "otherActiveParticipants"])
        )
        
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseOfActiveParticipantsMultipleTimes()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let user = ZMUser.insertNewObject(in:self.uiMOC)
        conversation.mutableOtherActiveParticipants.add(user)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: conversation)
        
        // when
        user.name = "Boo"
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(observer.changes.count, 1)
        
        // and when
        user.name = "Bar"
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(observer.changes.count, 2)
        
        // and when
        self.uiMOC.saveOrRollback()
        ConversationChangeInfo.remove(observer:token, for: conversation)
    }
    
    
    func testThatItDoesNotNotifyTheObserverBecauseAUsersAccentColorChanged()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
        otherUser.accentColorValue = .brightOrange
        conversation.mutableOtherActiveParticipants.add(otherUser)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        otherUser.accentColorValue = ZMAccentColor.softPink
            },
                                                     expectedChangedField: nil,
                                                     expectedChangedKeys: KeySet()
        )
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseOfOtherUserNameChange()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .oneOnOne
        
        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
        otherUser.name = "Foo"
        
        let connection = ZMConnection.insertNewObject(in: self.uiMOC)
        connection.to = otherUser
        connection.status = .accepted
        conversation.connection = connection
        
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        self.notifyNameChange(otherUser, name: "Phil")
            },
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
        
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseAUserWasAdded()
    {
        // given
        let user1 = ZMUser.insertNewObject(in:self.uiMOC)
        user1.name = "Foo A"
        
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        conversation.mutableOtherActiveParticipants.add(user1)
        
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        XCTAssertTrue(user1.displayName == "Foo")
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        let user2 = ZMUser.insertNewObject(in:self.uiMOC)
                                                        user2.name = "Foo B"
                                                        self.uiMOC.saveOrRollback()
                                                        XCTAssertEqual(user1.displayName, "Foo A")
            },
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseAUserWasAddedAndLaterItsNameChanged()
    {
        // given
        let user1 = ZMUser.insertNewObject(in:self.uiMOC)
        user1.name = "Foo A"
        
        let user2 = ZMUser.insertNewObject(in:self.uiMOC)
        user2.name = "Bar"
        
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        conversation.mutableOtherActiveParticipants.add(user1)
        
        XCTAssertEqual(user1.displayName, "Foo")
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        user2.name = "Foo B"
                                                        uiMOC.saveOrRollback()
                                                        XCTAssertEqual(user1.displayName, "Foo A")
            },
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
    }
    
    func testThatItDoesNotNotifyTheObserverOfANameChangeBecauseAUserWasRemovedAndLaterItsNameChanged()
    {
        // given
        let user1 = ZMUser.insertNewObject(in:self.uiMOC)
        user1.name = "Foo A"
        
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        conversation.mutableOtherActiveParticipants.add(user1)
        
        self.updateDisplayNameGenerator(withUsers: [user1])
        
        XCTAssertTrue(user1.displayName == "Foo")
        XCTAssertTrue(conversation.otherActiveParticipants.contains(user1))
        
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, observer in
                                                        conversation.mutableOtherActiveParticipants.remove(user1)
                                                        self.uiMOC.saveOrRollback()
                                                        observer.clearNotifications()
                                                        user1.name = "Bar"
                                                        self.updateDisplayNameGenerator(withUsers: [user1])
            },
                                                     expectedChangedField: nil,
                                                     expectedChangedKeys: KeySet()
        )
    }
    
    func testThatItNotifysTheObserverOfANameChangeBecauseAUserWasAddedLaterAndHisNameChanged()
    {
        // given
        let user1 = ZMUser.insertNewObject(in:self.uiMOC)
        user1.name = "Foo A"
        
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        XCTAssertTrue(user1.displayName == "Foo")
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, observer in
                                                        conversation.mutableOtherActiveParticipants.add(user1)
                                                        self.uiMOC.saveOrRollback()
                                                        observer.clearNotifications()
                                                        self.notifyNameChange(user1, name: "Bar")
            },
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
    }
    
    func testThatItNotifiesTheObserverOfAnInsertedMessage()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.lastReadServerTimeStamp = Date()
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        _ = conversation.appendMessage(withText: "foo")
            },
                                                     expectedChangedField: "messagesChanged",
                                                     expectedChangedKeys: KeySet(key: "messages"))
    }
    
    func testThatItNotifiesTheObserverOfAnAddedParticipant()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let user = ZMUser.insertNewObject(in:self.uiMOC)
        user.name = "Foo"
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.mutableOtherActiveParticipants.add(user) },
                                                     expectedChangedFields: KeySet(["participantsChanged", "nameChanged"]),
                                                     expectedChangedKeys: KeySet(["displayName", "otherActiveParticipants"]))
        
    }
    
    func testThatItNotifiesTheObserverOfAnRemovedParticipant()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let user = ZMUser.insertNewObject(in:self.uiMOC)
        user.name = "bar"
        conversation.mutableOtherActiveParticipants.add(user)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: {conversation, _ in conversation.mutableOtherActiveParticipants.remove(user) },
                                                     expectedChangedFields: KeySet(["participantsChanged", "nameChanged"]),
                                                     expectedChangedKeys: KeySet(["displayName", "otherActiveParticipants"]))
    }
    
    func testThatItNotifiesTheObserverIfTheSelfUserIsAdded()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        conversation.isSelfAnActiveMember = false
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: {conversation, _ in conversation.isSelfAnActiveMember = true },
                                                     expectedChangedField: "participantsChanged",
                                                     expectedChangedKeys: KeySet(key: "isSelfAnActiveMember"))
        
    }
    
    func testThatItNotifiesTheObserverWhenTheUserLeavesTheConversation()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        _ = ZMUser.insertNewObject(in:self.uiMOC)
        conversation.isSelfAnActiveMember = true
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: {conversation, _ in conversation.isSelfAnActiveMember = false },
                                                     expectedChangedField: "participantsChanged",
                                                     expectedChangedKeys: KeySet(key: "isSelfAnActiveMember"))
        
    }
    
    func testThatItNotifiesTheObserverOfChangedLastModifiedDate()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.lastModifiedDate = Date() },
                                                     expectedChangedField: "lastModifiedDateChanged",
                                                     expectedChangedKeys: KeySet(key: "lastModifiedDate"))
        
    }
    
    func testThatItNotifiesTheObserverOfChangedUnreadCount()
    {
        // given
        let uiConversation : ZMConversation = ZMConversation.insertNewObject(in:self.uiMOC)
        uiConversation.lastReadServerTimeStamp = Date()
        uiConversation.userDefinedName = "foo"
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        var conversation : ZMConversation!
        var message : ZMMessage!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = self.syncMOC.object(with: uiConversation.objectID) as! ZMConversation
            message = ZMMessage.insertNewObject(in: self.syncMOC)
            message.visibleInConversation = conversation
            message.serverTimestamp = conversation.lastReadServerTimeStamp?.addingTimeInterval(10)
            self.syncMOC.saveOrRollback()
            
            conversation.didUpdateWhileFetchingUnreadMessages()
            self.syncMOC.saveOrRollback()
            XCTAssertEqual(conversation.estimatedUnreadCount, 1)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mergeLastChanges()
        self.dispatcher.fireAllNotifications()

        
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: uiConversation)
        
        // when
        self.syncMOC.performGroupedBlockAndWait {
            conversation.lastReadServerTimeStamp = message.serverTimestamp
            conversation.updateUnread()
            XCTAssertEqual(conversation.estimatedUnreadCount, 0)
            self.syncMOC.saveOrRollback()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mergeLastChanges()
        
        self.dispatcher.fireAllNotifications()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let changeCount = observer.changes.count
        XCTAssertEqual(changeCount, 1, "Observer expected 1 notification, but received \(changeCount).")
        
        guard let changes = observer.changes.first else { return XCTFail() }
        checkChangeInfoContainsExpectedKeys(changes: changes,
                                            expectedChangedFields: KeySet(["unreadCountChanged", "conversationListIndicatorChanged"]),
                                            expectedChangedKeys: KeySet(["estimatedUnreadCount", "conversationListIndicator"]))
        
        ConversationChangeInfo.remove(observer:token, for: conversation)
    }
    
    func testThatItNotifiesTheObserverOfChangedDisplayName()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.userDefinedName = "Cacao" },
                                                     expectedChangedField: "nameChanged" ,
                                                     expectedChangedKeys: KeySet(["displayName"]))
        
    }
    
    func testThatItNotifiesTheObserverOfChangedConnectionStatusWhenInsertingAConnection()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.oneOnOne
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        conversation.connection = ZMConnection.insertNewObject(in: self.uiMOC)
                                                        conversation.connection!.status = ZMConnectionStatus.pending
            },
                                                     expectedChangedField: "connectionStateChanged" ,
                                                     expectedChangedKeys: KeySet(key: "relatedConnectionState"))
    }
    
    func testThatItNotifiesTheObserverOfChangedConnectionStatusWhenUpdatingAConnection()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.oneOnOne
        conversation.connection = ZMConnection.insertNewObject(in: self.uiMOC)
        conversation.connection!.status = ZMConnectionStatus.pending
        conversation.connection!.to = ZMUser.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.connection!.status = ZMConnectionStatus.accepted },
                                                     expectedChangedField: "connectionStateChanged" ,
                                                     expectedChangedKeys: KeySet(key: "relatedConnectionState"))
        
    }
    
    
    func testThatItNotifiesTheObserverOfChangedArchivedStatus()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.isArchived = true },
                                                     expectedChangedField: "isArchivedChanged" ,
                                                     expectedChangedKeys: KeySet(["isArchived"]))
        
    }
    
    func testThatItNotifiesTheObserverOfChangedSilencedStatus()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.isSilenced = true },
                                                     expectedChangedField: "isSilencedChanged" ,
                                                     expectedChangedKeys: KeySet(key: "isSilenced"))
        
    }
    
    func addUnreadMissedCall(_ conversation: ZMConversation) {
        let systemMessage = ZMSystemMessage.insertNewObject(in: conversation.managedObjectContext!)
        systemMessage.systemMessageType = .missedCall;
        systemMessage.serverTimestamp = Date(timeIntervalSince1970:1231234)
        systemMessage.visibleInConversation = conversation
        conversation.updateUnreadMessages(with: systemMessage)
    }
    
    
    func testThatItNotifiesTheObserverOfAChangedListIndicatorBecauseOfAnUnreadMissedCall()
    {
        // given
        let uiConversation : ZMConversation = ZMConversation.insertNewObject(in:self.uiMOC)
        uiConversation.userDefinedName = "foo"
        uiMOC.saveOrRollback()
        
        var conversation : ZMConversation!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = self.syncMOC.object(with: uiConversation.objectID) as! ZMConversation
            self.syncMOC.saveOrRollback()
        }

        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: uiConversation)
        
        // when
        self.syncMOC.performGroupedBlockAndWait {
            self.addUnreadMissedCall(conversation)
            self.syncMOC.saveOrRollback()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mergeLastChanges()
        
        self.dispatcher.fireAllNotifications() // the context does not save here
        
        // then
        let changeCount = observer.changes.count
        XCTAssertEqual(changeCount, 1, "Observer expected 1 notification, but received \(changeCount).")
        
        guard let changes = observer.changes.first else { return XCTFail() }
        checkChangeInfoContainsExpectedKeys(changes: changes,
                                            expectedChangedFields: KeySet(["conversationListIndicatorChanged", "messagesChanged"]),
                                            expectedChangedKeys: KeySet(["messages", "conversationListIndicator"]))
        
        ConversationChangeInfo.remove(observer:token, for: conversation)
        
    }
    
    func testThatItNotifiesTheObserverOfAChangedClearedTimeStamp()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        conversation.clearedTimeStamp = Date()
            },
                                                     expectedChangedField: "clearedChanged" ,
                                                     expectedChangedKeys: KeySet(key: "clearedTimeStamp"))
    }
    
    func testThatItNotifiesTheObserverOfASecurityLevelChange() {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        conversation.securityLevel = .secure
            },
                                                     expectedChangedField: "securityLevelChanged" ,
                                                     expectedChangedKeys: KeySet(key: "securityLevel"))
    }
    
    func testThatItStopsNotifyingAfterUnregisteringTheToken() {
        
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: conversation)
        ConversationChangeInfo.remove(observer:token, for: conversation)
        
        
        // when
        conversation.userDefinedName = "Mario!"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.changes.count, 0)
    }
}

// MARK: Performance

extension ConversationObserverTests {
    
    func testPerformanceOfCalculatingChangeNotificationsWhenUserChangesName()
    {
        // average: 0.056, relative standard deviation: 2.400%, values: [0.056840, 0.054732, 0.059911, 0.056330, 0.055015, 0.055535, 0.055917, 0.056481, 0.056177, 0.056115]
        let count = 50
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            let user = ZMUser.insertNewObject(in: self.uiMOC)
            user.name = "foo"
            let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
            conversation.conversationType = .group
            conversation.mutableOtherActiveParticipants.add(user)
            self.uiMOC.saveOrRollback()
            
            let observer = ConversationObserver()
            let token = ConversationChangeInfo.add(observer: observer, for: conversation)
            
            var lastName = "bar"
            self.startMeasuring()
            for _ in 1...count {
                let temp = lastName
                lastName = user.name
                user.name = temp
                self.uiMOC.saveOrRollback()
            }
            XCTAssertEqual(observer.changes.count, count)
            self.stopMeasuring()
            ConversationChangeInfo.remove(observer:token, for: conversation)
        }
    }


    func testPerformanceOfCalculatingChangeNotificationsWhenANewMessageArrives()
    {
       // average: 0.059, relative standard deviation: 12.459%, values: [0.080559, 0.056606, 0.056042, 0.056317, 0.055988, 0.056869, 0.056097, 0.055891, 0.055671, 0.056545]
        let count = 50
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
            self.uiMOC.saveOrRollback()
            
            let observer = ConversationObserver()
            let token = ConversationChangeInfo.add(observer: observer, for: conversation)
            
            self.startMeasuring()
            for _ in 1...count {
                conversation.appendMessage(withText: "hello")
                self.uiMOC.saveOrRollback()
            }
            XCTAssertEqual(observer.changes.count, count)
            self.stopMeasuring()
            ConversationChangeInfo.remove(observer:token, for: conversation)
        }
    }
    
    func testPerformanceOfCalculatingChangeNotificationsWhenANewMessageArrives_AppendingManyMessages()
    {
        // 50: average: 0.022, relative standard deviation: 30.173%, values: [0.042196, 0.020411, 0.019772, 0.019573, 0.020613, 0.020409, 0.019875, 0.019702, 0.019598, 0.019495],
        // 500: average: 0.243, relative standard deviation: 4.039%, values: [0.264489, 0.235209, 0.245864, 0.244984, 0.231789, 0.244359, 0.251886, 0.229036, 0.247700, 0.239637],
        let count = 50
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
            self.uiMOC.saveOrRollback()
            
            let observer = ConversationObserver()
            let token = ConversationChangeInfo.add(observer: observer, for: conversation)
            
            self.startMeasuring()
            for _ in 1...count {
                conversation.appendMessage(withText: "hello")
            }
            self.uiMOC.saveOrRollback()
            XCTAssertEqual(observer.changes.count, 1)
            self.stopMeasuring()
            ConversationChangeInfo.remove(observer:token, for: conversation)
        }
    }
    
    func testPerformanceOfCalculatingChangeNotificationsWhenANewMessageArrives_RegisteringNewObservers()
    {
       // 50: average: 0.093, relative standard deviation: 9.576%, values: [0.119425, 0.091509, 0.088228, 0.090549, 0.090424, 0.086471, 0.091216, 0.091060, 0.094097, 0.089602],
        // 500: average: 0.917, relative standard deviation: 1.375%, values: [0.940845, 0.908672, 0.905260, 0.931678, 0.930426, 0.916988, 0.913709, 0.902080, 0.904517, 0.911674],
        let count = 50
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            let observer = ConversationObserver()
            
            self.startMeasuring()
            for _ in 1...count {
                let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
                self.uiMOC.saveOrRollback()
                let token = ConversationChangeInfo.add(observer: observer, for: conversation)
                conversation.appendMessage(withText: "hello")
                self.uiMOC.saveOrRollback()
                ConversationChangeInfo.remove(observer:token, for: conversation)

            }
            self.stopMeasuring()
        }
    }
}

