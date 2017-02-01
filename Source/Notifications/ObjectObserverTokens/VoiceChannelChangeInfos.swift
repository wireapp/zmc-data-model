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

    // TODO Sabine: Remove this entirely?
//    public var previousState : ZMVoiceChannelState {
//        guard let rawValue = (changeInfos["voiceChannelState"] as? NSInteger),
//              let previousState = ZMVoiceChannelState(rawValue: UInt8(rawValue))
//        else { return .invalid }
//        
//        return previousState
//    }
    
    public var currentState : ZMVoiceChannelState {
        if let conversation = object as? ZMConversation,
            let state = conversation.voiceChannel?.state {
            return state
        }
        return .invalid
    }
    public var voiceChannel : ZMVoiceChannel? { return (object as? ZMConversation)?.voiceChannel }
    
    public override var description: String {
        return "" // TODO Sabine: "Call state changed from \(previousState) to \(currentState)"
    }
}


//@objc public protocol ZMVoiceChannelStateObserverOpaqueToken : NSObjectProtocol {}
@objc public protocol ZMVoiceChannelStateObserver :NSObjectProtocol {
    
    func voiceChannelStateDidChange(_ changeInfo: VoiceChannelStateChangeInfo)
    @objc optional func voiceChannelJoinFailed(error: NSError)
}

extension VoiceChannelStateChangeInfo {

    /// Adds a ZMVoiceChannelStateObserver for the specified conversation or to all conversations if none is specified
    /// You must hold on to the token and use it to unregister
    @objc(addObserver:forConversation:)
    public static func add(observer: ZMVoiceChannelStateObserver, for conversation: ZMConversation?) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .VoiceChannelStateChange,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? VoiceChannelStateChangeInfo
                else { return }
            
            observer.voiceChannelStateDidChange(changeInfo)
        }
    }
    
    @objc(removeObserver:forConversation:)
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation?) {
        NotificationCenter.default.removeObserver(observer, name: .VoiceChannelStateChange, object: conversation)
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

@objc public protocol ZMVoiceChannelParticipantsObserver : NSObjectProtocol {
    func voiceChannelParticipantsDidChange(_ changeInfo: VoiceChannelParticipantsChangeInfo)
}


@objc public final class VoiceChannelParticipantsChangeInfo: SetChangeInfo {
    
    init(setChangeInfo: SetChangeInfo) {
        conversation = setChangeInfo.observedObject as! ZMConversation
        super.init(observedObject: conversation, changeSet: setChangeInfo.changeSet)
    }
    
    let conversation : ZMConversation
    public var voiceChannel : ZMVoiceChannel { return conversation.voiceChannel }
    public var otherActiveVideoCallParticipantsChanged : Bool = false
    
}


//@objc public protocol ZMVoiceChannelParticipantsObserverOpaqueToken : NSObjectProtocol {}

extension VoiceChannelParticipantsChangeInfo {
    
    /// Adds an observer for the specified conversation
    /// You must hold on to the token and use it to unregister
    @objc(addObserver:forConversation:)
    public static func add(observer: ZMVoiceChannelParticipantsObserver,for conversation: ZMConversation) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .VoiceChannelParticipantStateChange,
                                                      object: conversation,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer,
                let changeInfo = note.userInfo?["changeInfo"] as? VoiceChannelParticipantsChangeInfo
                else { return }
            observer.voiceChannelParticipantsDidChange(changeInfo)
        } 
    }
    
    @objc(removeObserver:forConversation:)
    public static func remove(observer: NSObjectProtocol, for conversation: ZMConversation?) {
        NotificationCenter.default.removeObserver(observer, name: .VoiceChannelParticipantStateChange, object: conversation)
    }
}

