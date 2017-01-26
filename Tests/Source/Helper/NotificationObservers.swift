//
//  NotificationObservers.swift
//  ZMCDataModel
//
//  Created by Sabine Geithner on 25/01/17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation

protocol ObserverType : NSObjectProtocol {
    associatedtype ChangeInfo : ObjectChangeInfo
    var notifications : [ChangeInfo] {get set}
}

extension ObserverType {
    func clearNotifications() {
        notifications = []
    }
}

class TestUserClientObserver : NSObject, UserClientObserver {
    
    var receivedChangeInfo : [UserClientChangeInfo] = []
    
    func userClientDidChange(_ changes: UserClientChangeInfo) {
        receivedChangeInfo.append(changes)
    }
}

class UserObserver : NSObject, ZMUserObserver {
    
    var notifications = [UserChangeInfo]()
    
    func clearNotifications(){
        notifications = []
    }
    
    func userDidChange(_ changeInfo: UserChangeInfo) {
        notifications.append(changeInfo)
    }
}

class TestVoiceChannelObserver : NSObject, ZMVoiceChannelStateObserver {
    
    var receivedChangeInfo : [VoiceChannelStateChangeInfo] = []
    
    func voiceChannelStateDidChange(_ changeInfo: VoiceChannelStateChangeInfo) {
        receivedChangeInfo.append(changeInfo)
        if(OperationQueue.current != OperationQueue.main) {
            XCTFail("Wrong thread")
        }
    }
    func clearNotifications() {
        receivedChangeInfo = []
    }
}

class TestVoiceChannelParticipantStateObserver : NSObject, ZMVoiceChannelParticipantsObserver {
    
    var receivedChangeInfo : [VoiceChannelParticipantsChangeInfo] = []
    
    func voiceChannelParticipantsDidChange(_ changeInfo: VoiceChannelParticipantsChangeInfo) {
        receivedChangeInfo.append(changeInfo)
    }
    func clearNotifications() {
        receivedChangeInfo = []
    }
}


class MessageObserver : NSObject, ZMMessageObserver {
    
    var token : NSObjectProtocol?
    
    override init() {}
    
    init(message : ZMMessage) {
        super.init()
        token = MessageChangeInfo.add(observer: self, for: message)
    }
    
    deinit {
        tearDown()
    }
    
    func tearDown() {
        if let token = token {
            MessageChangeInfo.remove(observer: token, for: nil)
        }
    }
    
    var notifications : [MessageChangeInfo] = []
    
    func messageDidChange(_ changeInfo: MessageChangeInfo) {
        notifications.append(changeInfo)
    }
}


class ConversationObserver: NSObject, ZMConversationObserver {
    
    var token : NSObjectProtocol?
    
    func clearNotifications(){
        notifications = []
    }
    
    override init() {}
    
    init(conversation : ZMConversation) {
        super.init()
        token = ConversationChangeInfo.add(observer: self, for: conversation)
    }
    
    deinit {
        tearDown()
    }
    
    func tearDown() {
        if let token = token {
            ConversationChangeInfo.remove(observer: token, for: nil)
        }
    }
    
    var notifications = [ConversationChangeInfo]()
    
    func conversationDidChange(_ changeInfo: ConversationChangeInfo) {
        notifications.append(changeInfo)
    }
}
