/*
 * Wire
 * Copyright (C) 2016 Wire Swiss GmbH
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
import avs

public enum CallClosedReason : Int32 {
    case normal
    case internalError
    case timeout
    case lostMedia
    case unknown
}

public enum CallState : Equatable {
    /// There's no call
    case none
    /// Outgoing call is pending
    case outgoing
    /// Incoming call is pending
    case incoming(video: Bool)
    /// Established call
    case established
    /// Call in process of being terminated
    case terminating(reason: CallClosedReason)
    /// Unknown call state
    case unknown
    
    public static func ==(lhs: CallState, rhs: CallState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            fallthrough
        case (.outgoing, .outgoing):
            fallthrough
        case (.incoming, .incoming):
            fallthrough
        case (.established, .established):
            fallthrough
        case (.terminating, .terminating):
            fallthrough
        case (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

@objc(AVSVideoReceiveState)
public enum VideoReceiveState : UInt32 {
    /// Sender is not sending video
    case stopped
    /// Sender is sending video
    case started
    /// Sender is sending video but currently has a bad connection
    case badConnection
}

public typealias WireCallCenterObserverToken = NSObjectProtocol

/// MARK - Video State Observer

@objc
public protocol WireCallCenterVideoObserver : class {
    
    func receivingVideoDidChange(state: VideoReceiveState)
    
}

struct WireCallCenterVideoNotification {
    
    static let notificationName = Notification.Name("WireCallCenterVideoNotification")
    static let userInfoKey = notificationName.rawValue
    
    let videoReceiveState : VideoReceiveState
    
    init(videoReceiveState: VideoReceiveState) {
        self.videoReceiveState = videoReceiveState
    }
    
    func post() {
        NotificationCenter.default.post(name: WireCallCenterVideoNotification.notificationName,
                                        object: nil,
                                        userInfo: [WireCallCenterVideoNotification.userInfoKey : self])
    }
}

/// MARK - Call state observer

public protocol WireCallCenterCallStateObserver : class {
    
    func callCenterDidChange(callState: CallState, conversationId: UUID, userId: UUID)
    
}

struct WireCallCenterCallStateNotification {
    
    static let notificationName = Notification.Name("WireCallCenterNotification")
    static let userInfoKey = notificationName.rawValue
    
    let callState : CallState
    let conversationId : UUID
    let userId : UUID
    
    func post() {
        NotificationCenter.default.post(name: WireCallCenterCallStateNotification.notificationName,
                                        object: nil,
                                        userInfo: [WireCallCenterCallStateNotification.userInfoKey : self])
    }
}

/// MARK - Missed call observer

public protocol WireCallCenterMissedCallObserver : class {
    
    func callCenterMissedCall(conversationId: UUID, userId: UUID, timestamp: Date, video: Bool)
    
}

struct WireCallCenterMissedCallNotification {
    
    static let notificationName = Notification.Name("WireCallCenterNotification")
    static let userInfoKey = notificationName.rawValue
    
    let conversationId : UUID
    let userId : UUID
    let timestamp: Date
    let video: Bool
    
    func post() {
        NotificationCenter.default.post(name: WireCallCenterMissedCallNotification.notificationName,
                                        object: nil,
                                        userInfo: [WireCallCenterMissedCallNotification.userInfoKey : self])
    }
}

/// MARK - Call center transport

@objc
public protocol WireCallCenterTransport: class {
    
    func send(data: Data, conversationId: UUID, userId: UUID, completionHandler: @escaping ((_ status: Int) -> Void))
    
}

private typealias WireCallMessageToken = UnsafeMutableRawPointer

/** 
 * WireCallCenter is used for making wire calls and observing their state. There can only be one instance of the WireCallCenter. You should instantiate WireCallCenter once a keep a strong reference to it, other consumers can access this instance via the `activeInstance` property.
 * Thread safety: WireCallCenter instance methods should only be called from the main thread, class method can be called from any thread.
 */
@objc public class WireCallCenter : NSObject {
    
    private let zmLog = ZMSLog(tag: "Calling")
    
    private let userId : UUID
    
    /// activeInstance - Currenly active instance of the WireCallCenter.
    public private(set) static weak var activeInstance : WireCallCenter?
    
    /// establishedDate - Date of when the call was established (Participants can talk to each other). This property is only valid when the call state is .established.
    public private(set) var establishedDate : Date?
    
    public var transport : WireCallCenterTransport? = nil
    
    deinit {
        wcall_close()
    }
    
    public required init(userId: UUID, clientId: String, dontRegisterObservers : Bool = false) {
        self.userId = userId
        
        super.init()
        
        if WireCallCenter.activeInstance != nil {
            fatal("Only one WireCallCenter can be instantiated")
        }
        
        if (dontRegisterObservers) {
            
            let observer = Unmanaged.passUnretained(self).toOpaque()
            
            let resultValue = wcall_init(
                userId.transportString(),
                clientId,
                { (version, context) in
                    if let context = context {
                        _ = Unmanaged<WireCallCenter>.fromOpaque(context).takeUnretainedValue()
                        
                        
                    }
                },
                { (token, conversationId, userId, clientId, data, dataLength, context) in
                    guard let token = token, let context = context, let conversationId = conversationId, let userId = userId, let clientId = clientId, let data = data else {
                        print("BAD callback")
                        return EINVAL // invalid argument
                    }
                    
                    let selfReference = Unmanaged<WireCallCenter>.fromOpaque(context).takeUnretainedValue()
                    
                    return selfReference.send(token: token,
                                              conversationId: String.init(cString: conversationId),
                                              userId: String.init(cString: userId),
                                              clientId: String.init(cString: clientId),
                                              data: data,
                                              dataLength: dataLength)
                },
                { (conversationId, userId, isVideoCall, context) -> Void in
                    guard let context = context, let conversationId = conversationId, let userId = userId else {
                        print("BAD callback")
                        return
                    }
                    
                    let selfReference = Unmanaged<WireCallCenter>.fromOpaque(context).takeUnretainedValue()
                    
                    print("entering incoming")
                    
                    selfReference.incoming(conversationId: String.init(cString: conversationId),
                                           userId: String.init(cString: userId),
                                           isVideoCall: isVideoCall != 0)
                    
                    print("exiting incoming")
                },
                { (conversationId, messageTime, userId, isVideoCall, context) in
                    guard let context = context, let conversationId = conversationId, let userId = userId else {
                        print("BAD callback")
                        return
                    }
                    
                    let selfReference = Unmanaged<WireCallCenter>.fromOpaque(context).takeUnretainedValue()
                    let timestamp = Date(timeIntervalSince1970: TimeInterval(messageTime))
                    
                    print("entering missed")
                    
                    selfReference.missed(conversationId: String.init(cString: conversationId),
                                         userId: String.init(cString: userId),
                                         timestamp: timestamp,
                                         isVideoCall: isVideoCall != 0)
                    
                    print("exiting missed")
                },
                { (conversationId, userId, context) in
                    guard let context = context, let conversationId = conversationId, let userId = userId else {
                        print("BAD callback")
                        return
                    }
                    
                    let selfReference = Unmanaged<WireCallCenter>.fromOpaque(context).takeUnretainedValue()
                    
                    print("entering established")
                    
                    selfReference.established(conversationId: String.init(cString: conversationId),
                                              userId: String.init(cString: userId))
                    
                    
                    print("exiting established")
                },
                { (reason, conversationId, userId, metrics, context) in
                    guard let context = context, let conversationId = conversationId, let userId = userId else {
                        print("BAD callback")
                        return
                    }
                    
                    let selfReference = Unmanaged<WireCallCenter>.fromOpaque(context).takeUnretainedValue()
                    
                    print("entering closed")
                    
                    selfReference.closed(conversationId: String.init(cString: conversationId),
                                         userId: String.init(cString: userId),
                                         reason: CallClosedReason(rawValue: reason) ?? .internalError)
                    
                    print("exiting closed")
                },
                observer)
            
            if resultValue != 0 {
                fatal("Failed to initialise WireCallCenter")
            }
            
            wcall_set_video_state_handler({ (state, _) in
                guard let state = VideoReceiveState(rawValue: state.rawValue) else { return }
                
                DispatchQueue.main.async {
                    WireCallCenterVideoNotification(videoReceiveState: state).post()
                }
            })
        }
        
        WireCallCenter.activeInstance = self
    }
    
    private func send(token: WireCallMessageToken, conversationId: String, userId: String, clientId: String, data: UnsafePointer<UInt8>, dataLength: Int) -> Int32 {
        
        let bytes = UnsafeBufferPointer<UInt8>(start: data, count: dataLength)
        let transformedData = Data(buffer: bytes)
        
        transport?.send(data: transformedData, conversationId: UUID(uuidString: conversationId)!, userId: UUID(uuidString: userId)!, completionHandler: { status in
            wcall_resp(Int32(status), "", token)
        })
        
        return 0
    }
    
    private func incoming(conversationId: String, userId: String, isVideoCall: Bool) {
        zmLog.debug("incoming call")
        
        print("posting Incoming call")
        
        DispatchQueue.main.async {
            WireCallCenterCallStateNotification(callState: .incoming(video: isVideoCall), conversationId: UUID(uuidString: conversationId)!, userId: UUID(uuidString: userId)!).post()
        }
        
        print("done posting Incoming call")
    }
    
    private func missed(conversationId: String, userId: String, timestamp: Date, isVideoCall: Bool) {
        zmLog.debug("missed call")
        
        print("post missed call")
        
        DispatchQueue.main.async {
            WireCallCenterMissedCallNotification(conversationId: UUID(uuidString: conversationId)!, userId: UUID(uuidString: userId)!, timestamp: timestamp, video: isVideoCall).post()
        }
        
        print("done posting missed call")
    }
    
    private func established(conversationId: String, userId: String) {
        zmLog.debug("established call")
        
        print("posting established call")
        
        if wcall_is_video_call(conversationId) == 1 {
            wcall_set_video_send_active(conversationId, 1)
        }
        
        DispatchQueue.main.async {
            self.establishedDate = Date()
            
            WireCallCenterCallStateNotification(callState: .established, conversationId: UUID(uuidString: conversationId)!, userId: UUID(uuidString: userId)!).post()
        }
        
        print("done posting established call")
    }
    
    private func closed(conversationId: String, userId: String, reason: CallClosedReason) {
        zmLog.debug("closed call")
        
        print("posting closed call")
        
        DispatchQueue.main.async {
            WireCallCenterCallStateNotification(callState: .terminating(reason: reason), conversationId: UUID(uuidString: conversationId)!, userId: UUID(uuidString: userId)!).post()
        }
        
        print("done posting closed call")
    }
    
    // TODO find a better place for this method
    public func received(data: Data, currentTimestamp: Date, serverTimestamp: Date, conversationId: UUID, userId: UUID, clientId: String) {
        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            let currentTime = UInt32(currentTimestamp.timeIntervalSince1970)
            let serverTime = UInt32(serverTimestamp.timeIntervalSince1970)
            
            wcall_recv_msg(bytes, data.count, currentTime, serverTime, conversationId.transportString(), userId.transportString(), clientId)
        }
    }
    
    // MARK - Observer
    
    /// Register observer of the call center call state. This will inform you when there's an incoming call etc.
    public class func addCallStateObserver(observer: WireCallCenterCallStateObserver) -> WireCallCenterObserverToken  {
        return NotificationCenter.default.addObserver(forName: WireCallCenterCallStateNotification.notificationName, object: nil, queue: .main) { (note) in
            if let note = note.userInfo?[WireCallCenterCallStateNotification.userInfoKey] as? WireCallCenterCallStateNotification {
                observer.callCenterDidChange(callState: note.callState, conversationId: note.conversationId, userId: note.userId)
            }
        }
    }
    
    /// Register observer of missed calls.
    public class func addMissedCallObserver(observer: WireCallCenterMissedCallObserver) -> WireCallCenterObserverToken  {
        return NotificationCenter.default.addObserver(forName: WireCallCenterMissedCallNotification.notificationName, object: nil, queue: .main) { (note) in
            if let note = note.userInfo?[WireCallCenterMissedCallNotification.userInfoKey] as? WireCallCenterMissedCallNotification {
                observer.callCenterMissedCall(conversationId: note.conversationId, userId: note.userId, timestamp: note.timestamp, video: note.video)
            }
        }
    }
    
    /// Register observer of the video state. This will inform you when the remote caller starts, stops sending video.
    public class func addVideoObserver(observer: WireCallCenterVideoObserver) -> WireCallCenterObserverToken {
        return NotificationCenter.default.addObserver(forName: WireCallCenterVideoNotification.notificationName, object: nil, queue: .main) { (note) in
            if let note = note.userInfo?[WireCallCenterVideoNotification.userInfoKey] as? WireCallCenterVideoNotification {
                observer.receivingVideoDidChange(state: note.videoReceiveState)
            }
        }
    }
    
    public class func removeObserver(token: WireCallCenterObserverToken) {
        NotificationCenter.default.removeObserver(token)
    }
    
    // MARK - Call state methods
    
    @objc(answerCallForConversationID:)
    public func answerCall(conversationId: UUID) -> Bool {
        return wcall_answer(conversationId.transportString()) == 0
    }
    
    @objc(startCallForConversationID:video:)
    public func startCall(conversationId: UUID, video: Bool) -> Bool {
        let started = wcall_start(conversationId.transportString(), video ? 1 : 0) == 0
        
        if started {
            WireCallCenterCallStateNotification(callState: .outgoing, conversationId: conversationId, userId: userId).post()
        }
        
        return started
    }
    
    @objc(closeCallForConversationID:)
    public func closeCall(conversationId: UUID) {
        wcall_end(conversationId.transportString())
        WireCallCenterCallStateNotification(callState: .terminating(reason: .normal), conversationId: conversationId, userId: userId).post()
    }
    
    @objc(ignoreCallForConversationID:)
    public func ignoreCall(conversationId: UUID) {
        wcall_end(conversationId.transportString())
        WireCallCenterCallStateNotification(callState: .terminating(reason: .normal), conversationId: conversationId, userId: userId).post()
    }
    
    @objc(toogleVideoForConversationID:isActive:)
    public func toogleVideo(conversationID: UUID, active: Bool) {
        wcall_set_video_send_active(conversationID.transportString(), active ? 1 : 0)
    }
    
    @objc(isVideoCallForConversationID:)
    public class func isVideoCall(conversationId: UUID) -> Bool {
        return wcall_is_video_call(conversationId.transportString()) == 1 ? true : false
    }
 
    public func callState(conversationId: UUID) -> CallState {
        switch wcall_get_state(conversationId.transportString()) {
        case WCALL_STATE_NONE:
            return .none
        case WCALL_STATE_INCOMING:
            return .incoming(video: false)
        case WCALL_STATE_OUTGOING:
            return .outgoing
        case WCALL_STATE_ESTABLISHED:
            return .established
        case WCALL_STATE_TERMINATING:
            return .terminating(reason: .unknown)
        default:
            return .unknown
        }
    }
}
