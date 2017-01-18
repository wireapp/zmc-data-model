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

///////////////////
///
/// State
///
///////////////////

@objc public final class VoiceChannelStateChangeInfo : ObjectChangeInfo {
    
    public required init(object: NSObject) {
        super.init(object: object)
    }
    
    public var previousState : ZMVoiceChannelState {
        guard let rawValue = (changedKeysAndOldValues["voiceChannelState"] as? NSInteger),
              let previousState = ZMVoiceChannelState(rawValue: UInt8(rawValue))
        else { return .invalid }
        
        return previousState
    }
    
    public var currentState : ZMVoiceChannelState {
        if let conversation = object as? ZMConversation,
            let state = conversation.voiceChannel?.state {
            return state
        }
        return .invalid
    }
    public var voiceChannel : ZMVoiceChannel? { return (object as? ZMConversation)?.voiceChannel }
    
    public override var description: String {
        return "Call state changed from \(previousState) to \(currentState)"
    }
    
}

extension ZMVoiceChannelState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid: return "Invalid"
        case .noActiveUsers: return "NoActiveUsers"
        case .outgoingCall: return "OutgoingCall"
        case .outgoingCallInactive: return "OutgoingCallInactive"
        case .incomingCall: return "IncomingCall"
        case .incomingCallInactive: return "IncomingCallInactive"
        case .selfIsJoiningActiveChannel: return "SelfIsJoiningActiveChannel"
        case .selfConnectedToActiveChannel: return "SelfConnectedToActiveChannel"
        case .deviceTransferReady: return "DeviceTransferReady"
        }
    }
}


/////////////////////
///
/// CallParticipantState
///
/////////////////////



@objc public final class VoiceChannelParticipantsChangeInfo: SetChangeInfo {
    
    init(setChangeInfo: SetChangeInfo) {
        conversation = setChangeInfo.observedObject as! ZMConversation
        super.init(observedObject: conversation, changeSet: setChangeInfo.changeSet)
    }
    
    let conversation : ZMConversation
    public var voiceChannel : ZMVoiceChannel { return conversation.voiceChannel }
    public var otherActiveVideoCallParticipantsChanged : Bool = false
}

