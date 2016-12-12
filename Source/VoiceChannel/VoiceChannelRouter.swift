//
//  VoiceChannelRouter.swift
//  ZMCDataModel
//
//  Created by Jacob on 23/11/16.
//  Copyright © 2016 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMVoiceChannel : VoiceChannel { }

public class VoiceChannelRouter : NSObject, VoiceChannel {
    
    public static var isCallingV3Enabled : Bool = false
    
    public let v3 : VoiceChannelV3
    public let v2 : ZMVoiceChannel
    
    public init(conversation: ZMConversation) {
        v3 = VoiceChannelV3(conversation: conversation)
        v2 = ZMVoiceChannel(conversation: conversation)
        
        super.init()
    }
    
    public var currentVoiceChannel : VoiceChannel {
        if v2.state != .noActiveUsers || v2.conversation?.conversationType != .oneOnOne || !VoiceChannelRouter.isCallingV3Enabled {
            return v2
        } else {
            return v3
        }
    }
    
    public var conversation: ZMConversation? {
        return currentVoiceChannel.conversation
    }
    
    public var state: ZMVoiceChannelState {
        return currentVoiceChannel.state
    }
        
    public var callStartDate: Date? {
        return currentVoiceChannel.callStartDate
    }
    
    public var participants: NSOrderedSet {
        return currentVoiceChannel.participants
    }
    
    public var selfUserConnectionState: ZMVoiceChannelConnectionState {
        return currentVoiceChannel.selfUserConnectionState
    }
    
    public func state(forParticipant participant: ZMUser) -> ZMVoiceChannelParticipantState {
        return currentVoiceChannel.state(forParticipant: participant)
    }
}
