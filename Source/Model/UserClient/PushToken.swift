////
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

public enum PushTokenType: Int, Codable {
    case standard, voip

    public var transportType: String {
        switch self {
            case .standard: return "APNS"
            case .voip: return "APNS_VOIP"
        }
    }
}

public struct PushTokenMetadata {
    let isSandbox: Bool
    
    /*!
     @brief There are 4 different application identifiers which map to each of the bundle id's used
     @discussion
     com.wearezeta.zclient.ios-development (dev) - <b>com.wire.dev.ent</b>
     
     com.wearezeta.zclient.ios-internal (internal) - <b>com.wire.int.ent</b>
     
     com.wearezeta.zclient-alpha - <b>com.wire.ent</b>
     
     com.wearezeta.zclient.ios (app store) - <b>com.wire</b>
     
     @sa https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications
     */
    let appIdentifier: String

    /*!
     @brief There are 4 transport types which depend on the token type and the environment
     @discussion <b>APNS</b> -> ZMAPNSTypeNormal (deprecated)
     
     <b>APNS_VOIP</b> -> ZMAPNSTypeVoIP
     
     <b>APNS_SANDBOX</b> -> ZMAPNSTypeNormal + Sandbox environment (deprecated)
     
     <b>APNS_VOIP_SANDBOX</b> -> ZMAPNSTypeVoIP + Sandbox environment
     
     The non-VoIP types are deprecated at the moment.
     
     @sa https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications
     */
    
    var tokenType: PushTokenType
    var transportType: String {
        return isSandbox ? (tokenType.transportType + "_SANDBOX") : tokenType.transportType
    }
    
    public static func current(for tokenType: PushTokenType) -> PushTokenMetadata {
        let appId = Bundle.main.bundleIdentifier ?? ""
        let buildType = BuildType.init(bundleID: appId)
        
        let isSandbox = ZMMobileProvisionParser().apsEnvironment == .sandbox
        let appIdentifier = buildType.certificateName
        
        let metadata = PushTokenMetadata(isSandbox: isSandbox, appIdentifier: appIdentifier, tokenType: tokenType)
        return metadata
    }
}

public struct PushToken: Equatable, Codable {
    public let deviceToken: Data
    public let appIdentifier: String
    public let transportType: String
    public let type: PushTokenType
    public var isRegistered: Bool
    public var isMarkedForDeletion: Bool = false
    public var isMarkedForDownload: Bool = false
}

extension PushToken {

    public init(deviceToken: Data, tokenType: PushTokenType, isRegistered: Bool = false) {
        let metadata = PushTokenMetadata.current(for: tokenType)
        self.init(deviceToken: deviceToken,
                  appIdentifier: metadata.appIdentifier,
                  transportType: metadata.transportType,
                  type: tokenType,
                  isRegistered: isRegistered,
                  isMarkedForDeletion: false,
                  isMarkedForDownload: false)
    }

    public var deviceTokenString: String {
        return deviceToken.zmHexEncodedString()
    }

    public func resetFlags() -> PushToken {
        var token = self
        token.isMarkedForDownload = false
        token.isMarkedForDeletion = false
        return token
    }

    public func markToDownload() -> PushToken {
        var token = self
        token.isMarkedForDownload = true
        return token
    }

    public func markToDelete() -> PushToken {
        var token = self
        token.isMarkedForDeletion = true
        return token
    }
    
    public static func createVOIPToken(from deviceToken: Data) -> PushToken {
        return PushToken(deviceToken: deviceToken, tokenType: .voip)
    }
    
    public static func createAPNSToken(from deviceToken: Data) -> PushToken  {
         return PushToken(deviceToken: deviceToken, tokenType: .standard)
    }

}
