//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import ZMCDataModel

private extension ZMConversation {
    var mutableCallParticipants : NSMutableOrderedSet {
        return mutableOrderedSetValue(forKey: ZMConversationCallParticipantsKey)
    }
}

class VoiceChannelObserverTests : NotificationDispatcherTests {
    
    var stateObserver : TestVoiceChannelObserver!
    var participantObserver : TestVoiceChannelParticipantStateObserver!
    
    override func setUp() {
        super.setUp()
        stateObserver =  TestVoiceChannelObserver()
        participantObserver = TestVoiceChannelParticipantStateObserver()
    }
    
    override func tearDown() {
        stateObserver = nil
        participantObserver = nil

        super.tearDown()
    }
    
    
    fileprivate func addConversationParticipant(_ conversation: ZMConversation) -> ZMUser {
        let user = ZMUser.insertNewObject(in:self.uiMOC)
        conversation.mutableOtherActiveParticipants.add(user)
        return user
    }
    
    
    func testThatItNotifiesTheObserverOfStateChange()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .oneOnOne
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        
        // when
        conversation.callDeviceIsActive = true
        
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 1)
        if let note = stateObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.previousState, ZMVoiceChannelState.noActiveUsers)
            XCTAssertEqual(note.currentState, ZMVoiceChannelState.outgoingCall)
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
        }
        
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItSendsAChannelStateChangeNotificationsWhenSomeoneIsCalling()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .oneOnOne
        
        let otherParticipant = self.addConversationParticipant(conversation)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        
        // when
        conversation.mutableCallParticipants.add(otherParticipant)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 1)
        if let note = stateObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.previousState, ZMVoiceChannelState.noActiveUsers)
            XCTAssertEqual(note.currentState, ZMVoiceChannelState.incomingCall)
        }
        
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItSendsAChannelStateChangeNotificationsWhenSomeoneLeavesTheConversation()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .oneOnOne
        
        let otherParticipant = self.addConversationParticipant(conversation)
        conversation.mutableCallParticipants.add(otherParticipant)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        
        // when
        conversation.mutableCallParticipants.remove(otherParticipant)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 1)
        if let note = stateObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.previousState, ZMVoiceChannelState.incomingCall)
            XCTAssertEqual(note.currentState, ZMVoiceChannelState.noActiveUsers)
        }
        
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
        
    }
    
    func testThatItSendsAChannelStateChangeNotificationsWhenTheUserGetsConnectedToTheChannel()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant = self.addConversationParticipant(conversation)
        conversation.conversationType = .oneOnOne
        
        conversation.mutableCallParticipants.add(otherParticipant)
        conversation.mutableCallParticipants.add(selfParticipant)
        
        conversation.isFlowActive = false
        conversation.callDeviceIsActive = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        
        // when
        conversation.isFlowActive = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 1)
        if let note = stateObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.previousState, ZMVoiceChannelState.selfIsJoiningActiveChannel)
            XCTAssertEqual(note.currentState, ZMVoiceChannelState.selfConnectedToActiveChannel)
        }
        
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
        
    }
    
    func testThatItSendsAChannelStateChangeNotificationsWhenTheUserGetsDisconnectedToTheChannel()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant = self.addConversationParticipant(conversation)
        conversation.conversationType = .oneOnOne
        
        conversation.mutableCallParticipants.add(otherParticipant)
        conversation.mutableCallParticipants.add(selfParticipant)
        
        conversation.callDeviceIsActive = true
        conversation.isFlowActive = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        
        // when
        conversation.isFlowActive = false
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 1)
        if let note = stateObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.previousState, ZMVoiceChannelState.selfConnectedToActiveChannel)
            XCTAssertEqual(note.currentState, ZMVoiceChannelState.selfIsJoiningActiveChannel)
        }
        
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
        
    }
    
    func testThatItSendsAChannelStateChangeNotificationsWhenTransferBecomesReady()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant = self.addConversationParticipant(conversation)
        conversation.conversationType = .oneOnOne
        
        conversation.mutableCallParticipants.add(otherParticipant)
        conversation.mutableCallParticipants.add(selfParticipant)
        
        conversation.activeFlowParticipants = NSOrderedSet(objects: otherParticipant, selfParticipant)
        conversation.isFlowActive = true
        conversation.callDeviceIsActive = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        
        // when
        conversation.isFlowActive = false
        conversation.callDeviceIsActive = false
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation),notifyDirectly: true)
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 1)
        if let note = stateObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.previousState, ZMVoiceChannelState.selfConnectedToActiveChannel)
            XCTAssertEqual(note.currentState, ZMVoiceChannelState.deviceTransferReady)
        }
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItSendsAChannelStateChangeNotificationsWhenCallIsBeingTransfered()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant = self.addConversationParticipant(conversation)
        conversation.conversationType = .oneOnOne
        
        conversation.mutableCallParticipants.add(otherParticipant)
        conversation.mutableCallParticipants.add(selfParticipant)
        
        conversation.activeFlowParticipants = NSOrderedSet(objects: otherParticipant, selfParticipant)
        
        conversation.isFlowActive = false
        conversation.callDeviceIsActive = false
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        
        // when
        conversation.isFlowActive = true
        conversation.callDeviceIsActive = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral:conversation),notifyDirectly: true)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 1)
        if let note = stateObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.previousState, ZMVoiceChannelState.deviceTransferReady)
            XCTAssertEqual(note.currentState, ZMVoiceChannelState.selfConnectedToActiveChannel)
        }
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItSendsACallStateChangeNotificationWhenIgnoringACall()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let otherParticipant = self.addConversationParticipant(conversation)
        conversation.conversationType = .oneOnOne
        
        conversation.mutableCallParticipants.add(otherParticipant)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        
        // when
        conversation.isIgnoringCall = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral:conversation),notifyDirectly: true)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 1)
        if let note = stateObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.previousState, ZMVoiceChannelState.incomingCall)
            XCTAssertEqual(note.currentState, ZMVoiceChannelState.noActiveUsers)
        }
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItStopsNotifyingAfterUnregisteringTheToken() {
        
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .oneOnOne
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelStateChangeInfo.add(observer:stateObserver, for:conversation)
        VoiceChannelStateChangeInfo.remove(observer: token, for: conversation)
        
        // when
        conversation.callDeviceIsActive = true
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(stateObserver.receivedChangeInfo.count, 0)
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }
}




extension VoiceChannelObserverTests {
    
    func testThatItSendsAParticipantsChangeNotificationWhenTheParticipantJoinsTheOneToOneCall()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant = self.addConversationParticipant(conversation)
        conversation.conversationType = .oneOnOne
        conversation.isFlowActive = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)

        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        /// when
        conversation.mutableCallParticipants.add(otherParticipant)
        conversation.mutableCallParticipants.add(selfParticipant)
        conversation.activeFlowParticipants = NSOrderedSet(objects: otherParticipant, selfParticipant)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation),notifyDirectly: true)
        
        
        // then
        // We want to get voiceChannelState change notification when flow in established and later on
        //we want to get notifications on changing activeFlowParticipants array (when someone joins or leaves)
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.insertedIndexes, IndexSet(integersIn: 0..<conversation.voiceChannel.participants().count))
            XCTAssertEqual(note.deletedIndexes, IndexSet())
            XCTAssertEqual(note.updatedIndexes, IndexSet())
        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
        
    }
    
    func testThatItSendsAParticipantsChangeNotificationWhenTheParticipantJoinsTheGroupCall()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant1 = self.addConversationParticipant(conversation)
        let otherParticipant2 = self.addConversationParticipant(conversation)
        conversation.conversationType = .group
        conversation.isFlowActive = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)

        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.mutableCallParticipants.add(otherParticipant1)
        conversation.mutableCallParticipants.add(otherParticipant2)
        conversation.mutableCallParticipants.add(selfParticipant)
        conversation.activeFlowParticipants = NSOrderedSet(objects: otherParticipant1, otherParticipant2, selfParticipant)
        
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation),notifyDirectly: true)
        
        // then
        // We want to get voiceChannelState change notification when flow in established and later on
        //we want to get notifications on changing activeFlowParticipants array (when someone joins or leaves)
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.insertedIndexes, IndexSet(integersIn: 0..<conversation.voiceChannel.participants().count))
            XCTAssertEqual(note.deletedIndexes, IndexSet())
            XCTAssertEqual(note.updatedIndexes, IndexSet())
        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
        
    }
    
    func testThatItSendsAParticipantsUpdateNotificationWhenTheParticipantBecameActive()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant1 = self.addConversationParticipant(conversation)
        let otherParticipant2 = self.addConversationParticipant(conversation)
        conversation.conversationType = .group
        conversation.isFlowActive = true
        
        conversation.mutableCallParticipants.add(otherParticipant1)
        conversation.mutableCallParticipants.add(selfParticipant)
        conversation.mutableCallParticipants.add(otherParticipant2)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)

        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.activeFlowParticipants = NSOrderedSet(objects: selfParticipant, otherParticipant1)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation),notifyDirectly: true)
        
        // then
        // We want to get voiceChannelState change notification when flow in established and later on
        //we want to get notifications on changing activeFlowParticipants array (when someone joins or leaves)
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.insertedIndexes, IndexSet())
            XCTAssertEqual(note.deletedIndexes, IndexSet())
            XCTAssertEqual(note.updatedIndexes, IndexSet(integersIn: 0..<conversation.voiceChannel.participants().count - 1))
        }
        else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
        
    }
    
    func testThatItSendsAParticipantsChangeNotificationWhenTheParticipantLeavesTheGroupCall()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant1 = self.addConversationParticipant(conversation)
        let otherParticipant2 = self.addConversationParticipant(conversation)
        conversation.conversationType = .group
        conversation.isFlowActive = true
        self.uiMOC.saveOrRollback()
        
        conversation.mutableCallParticipants.addObjects(from: [otherParticipant1, selfParticipant, otherParticipant2])
        conversation.activeFlowParticipants = NSOrderedSet(array: [otherParticipant1, selfParticipant, otherParticipant2])
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.mutableCallParticipants.remove(otherParticipant2)
        conversation.mutableCallParticipants.moveObjects(at: IndexSet(integer: 1), to: 0) // this is done by the comparator
        conversation.activeFlowParticipants = NSOrderedSet(array: [selfParticipant, otherParticipant1])
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        // We want to get voiceChannelState change notification when flow in established and later on
        //we want to get notifications on changing activeFlowParticipants array (when someone joins or leaves)
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.deletedIndexes, IndexSet(integer: 1))
            XCTAssertEqual(note.insertedIndexes, IndexSet())
            XCTAssertEqual(note.updatedIndexes, IndexSet())
            XCTAssertEqual(note.movedIndexPairs, [])
            
        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
        
    }
    
    func testThatItSendsTheUpdateForParticipantsWhoLeaveTheVoiceChannel()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let selfParticipant = ZMUser.selfUser(in: self.uiMOC)
        let otherParticipant1 = self.addConversationParticipant(conversation)
        let otherParticipant2 = self.addConversationParticipant(conversation)
        conversation.conversationType = .group
        conversation.isFlowActive = true
        
        conversation.mutableCallParticipants.addObjects(from: [otherParticipant1, selfParticipant, otherParticipant2])
        conversation.activeFlowParticipants = NSOrderedSet(array: [otherParticipant1, selfParticipant, otherParticipant2])
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.activeFlowParticipants = NSOrderedSet(array: [otherParticipant1, selfParticipant])
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.deletedIndexes, IndexSet())
            XCTAssertEqual(note.insertedIndexes, IndexSet())
            XCTAssertEqual(note.updatedIndexes, IndexSet(integer: 1)) // TODO Sabine: which index should it be? IndexSet(integer: 0)
            XCTAssertEqual(note.movedIndexPairs, [])

        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
        
    }
    
    func testThatItSendsTheUpdateForParticipantsWhoJoinTheVoiceChannel()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        
        let otherParticipant1 = self.addConversationParticipant(conversation)
        let otherParticipant2 = self.addConversationParticipant(conversation)
        conversation.conversationType = .group
        conversation.isFlowActive = true
        self.uiMOC.saveOrRollback()
        
        conversation.mutableCallParticipants.add(otherParticipant1)
        conversation.mutableCallParticipants.add(otherParticipant2)
        conversation.activeFlowParticipants = NSOrderedSet(objects: otherParticipant1)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.activeFlowParticipants = NSOrderedSet(array: [otherParticipant2, otherParticipant1])
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertEqual(note.voiceChannel, conversation.voiceChannel)
            XCTAssertEqual(note.deletedIndexes, IndexSet())
            XCTAssertEqual(note.insertedIndexes, IndexSet())
            XCTAssertEqual(note.updatedIndexes, IndexSet(integer: conversation.callParticipants.index(of: otherParticipant2)))
            XCTAssertEqual(note.movedIndexPairs, [])
            
        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
        
    }
}



// MARK: Video Calling

extension VoiceChannelObserverTests {
    
    func testThatItSendsTheUpdateForParticipantsWhoActivatesVideoStream()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .group
        conversation.isFlowActive = true
        
        let otherParticipant1 = self.addConversationParticipant(conversation)
        conversation.mutableCallParticipants.add(otherParticipant1)

        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.addActiveVideoCallParticipant(otherParticipant1)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertTrue(note.otherActiveVideoCallParticipantsChanged)
            
        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItDoesNotSendTheUpdateForParticipantsWhoActivatesVideoStreamWhenFLowIsNotActive()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        
        let otherParticipant1 = self.addConversationParticipant(conversation)
        conversation.conversationType = .group
        conversation.isFlowActive = false
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.addActiveVideoCallParticipant(otherParticipant1)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 0)
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItSendsTheUpdateForSecondParticipantsWhoActivatesVideoStream()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .group
        conversation.isFlowActive = true

        let otherParticipant1 = self.addConversationParticipant(conversation)
        let otherParticipant2 = self.addConversationParticipant(conversation)
        conversation.mutableCallParticipants.add(otherParticipant1)
        conversation.mutableCallParticipants.add(otherParticipant2)

        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        conversation.addActiveVideoCallParticipant(otherParticipant1)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.addActiveVideoCallParticipant(otherParticipant2)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertTrue(note.otherActiveVideoCallParticipantsChanged)
            
        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
    }
    
    func testThatItSendsTheUpdateForParticipantWhenFlowIsEstablished()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let otherParticipant1 = self.addConversationParticipant(conversation)
        conversation.conversationType = .group
        conversation.isFlowActive = false
        self.uiMOC.saveOrRollback()
        
        conversation.mutableCallParticipants.add(otherParticipant1)
        conversation.addActiveVideoCallParticipant(otherParticipant1)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        self.uiMOC.saveOrRollback()
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.isFlowActive = true
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        
        // then
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertTrue(note.otherActiveVideoCallParticipantsChanged)
            
        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
    }
    
    
    func testThatItSendsTheUpdateForParticipantsWhoDeactivatesVideoStream()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        
        let otherParticipant1 = self.addConversationParticipant(conversation)
        conversation.conversationType = .group
        conversation.isFlowActive = true
        self.uiMOC.saveOrRollback()
        
        conversation.mutableCallParticipants.add(otherParticipant1)
        conversation.addActiveVideoCallParticipant(otherParticipant1)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        XCTAssertEqual(conversation.otherActiveVideoCallParticipants.count, 1)
        
        let token = VoiceChannelParticipantsChangeInfo.add(observer: participantObserver, for: conversation)
        
        // when
        conversation.removeActiveVideoCallParticipant(otherParticipant1)
        self.dispatcher.notifyUpdatedCallState(Set(arrayLiteral: conversation), notifyDirectly: true)
        XCTAssertEqual(conversation.otherActiveVideoCallParticipants.count, 0)
        
        // then
        XCTAssertEqual(participantObserver.receivedChangeInfo.count, 1)
        if let note = participantObserver.receivedChangeInfo.first {
            XCTAssertTrue(note.otherActiveVideoCallParticipantsChanged)
        } else {
            XCTFail("did not send notification")
        }
        VoiceChannelParticipantsChangeInfo.remove(observer: token, for: conversation)
    }
    
}
