//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

/**
 * Describes the status of legal hold for the user.
 */

public enum UserLegalHoldStatus: Equatable {
    /// Legal hold is enabled for the user.
    case enabled

    /// A legal hold request is pending the user's approval.
    case pending(LegalHoldRequest)

    /// Legal hold is disabled for the user.
    case disabled
}

/**
 * Describes a request to enable legal hold, created from the update event.
 */

public struct LegalHoldRequest: Codable, Hashable {

    /// The ID of the admin who sent the request.
    public let requesterIdentifier: UUID

    /// The ID of the user that should receive legal hold.
    public let targetUserIdentifier: UUID

    /// The ID of the legal hold client.
    public let clientIdentifier: UUID

    /// The last prekey for the legal hold client.
    public let lastPrekey: Data

    // MARK: Initialization

    public init(requesterIdentifier: UUID, targetUserIdentifier: UUID, clientIdentifier: UUID, lastPrekey: Data) {
        self.requesterIdentifier = requesterIdentifier
        self.targetUserIdentifier = targetUserIdentifier
        self.clientIdentifier = clientIdentifier
        self.lastPrekey = lastPrekey
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case requesterIdentifier = "requester"
        case targetUserIdentifier = "target_user"
        case clientIdentifier = "client_id"
        case lastPrekey = "last_prekey"
    }

    public static func decode(from data: Data) -> LegalHoldRequest? {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .base64
        return try? decoder.decode(LegalHoldRequest.self, from: data)
    }

    public func encode() -> Data? {
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .base64
        return try? encoder.encode(self)
    }

}

extension ZMUserKeys {
    /// The key path to access the current legal hold request.
    static let legalHoldRequest = "legalHoldRequest"
}

extension ZMUser {

    // MARK: - Legal Hold Status

    /// The keys that affect the legal hold status for the user.
    static func keysAffectingLegalHoldStatus() -> Set<String> {
        return [#keyPath(ZMUser.clients), ZMUserKeys.legalHoldRequest]
    }

    /// The current legal hold status for the user.
    public var legalHoldStatus: UserLegalHoldStatus {
        if let legalHoldRequest = self.legalHoldRequest {
            return .pending(legalHoldRequest)
        } else if clients.any(\.isLegalHoldDevice) {
            return .enabled
        } else {
            return .disabled
        }
    }

    // MARK: - Legal Hold Request

    @NSManaged private var primitiveLegalHoldRequest: Data?

    private var legalHoldRequest: LegalHoldRequest? {
        get {
            willAccessValue(forKey: ZMUserKeys.legalHoldRequest)
            let value = primitiveLegalHoldRequest.flatMap(LegalHoldRequest.decode)
            didAccessValue(forKey: ZMUserKeys.legalHoldRequest)
            return value
        }
        set {
            willChangeValue(forKey: ZMUserKeys.legalHoldRequest)
            primitiveLegalHoldRequest = newValue.flatMap { $0.encode() }
            didChangeValue(forKey: ZMUserKeys.legalHoldRequest)
        }
    }

    /**
     * Call this method when the user accepted the legal hold request.
     * - parameter request: The request that the user received.
     */

    public func userDidAcceptLegalHoldRequest(_ request: LegalHoldRequest) {
        guard request == self.legalHoldRequest else {
            // The request must match the current request to avoid nil-ing it out by mistake
            return
        }

        addLegalHoldClient(from: request)
        legalHoldRequest = nil
    }

    private func addLegalHoldClient(from request: LegalHoldRequest) {
        #warning("TODO: Create new UserClient from the request.")
    }

    /**
     * Call this method when the user received a legal hold request from their admin.
     * - parameter request: The request that the user received.
     */

    public func userDidReceiveLegalHoldRequest(_ request: LegalHoldRequest) {
        guard request.targetUserIdentifier == self.remoteIdentifier else {
            // Do not handle requests if the user ID doesn't match the self user ID
            return
        }

        legalHoldRequest = request
    }

}
