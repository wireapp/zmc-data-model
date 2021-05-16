//
// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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

@objc public enum ZMParticipantsRemovedReason : Int16, CaseIterable {
    case none = 0
    case legalHoldPolicyConflict /// Users don't want / support LH
}

extension ZMParticipantsRemovedReason {

    public var stringValue: String? {
        switch self {
        case .none:
            return nil
        case .legalHoldPolicyConflict:
            return "legalhold-policy-conflict"
        }
    }

    init(string: String) {
        let result = ZMParticipantsRemovedReason.allCases.lazy
            .compactMap { eventType -> (ZMParticipantsRemovedReason, String)? in
                guard let stringValue = eventType.stringValue else { return nil }
                return (eventType, stringValue)
            }
            .first(where: { (_, stringValue) -> Bool in
                return stringValue == string
            })?.0

        self = result ?? .none
    }
    
}

extension ZMSystemMessage {

    @objc public static let participantsRemovedReasonKey = "participantsRemovedReason"

    @objc public var participantsRemovedReason: ZMParticipantsRemovedReason {
        set {
            let key = #keyPath(ZMSystemMessage.participantsRemovedReasonKey)
            self.willChangeValue(forKey: key)
            self.setPrimitiveValue(newValue.rawValue, forKey: key)
            self.didChangeValue(forKey: key)
        }
        get {
            let key = #keyPath(ZMSystemMessage.participantsRemovedReasonKey)
            self.willAccessValue(forKey: key)
            let raw = (self.primitiveValue(forKey: key) as? NSNumber) ?? 0
            self.didAccessValue(forKey: key)
            return ZMParticipantsRemovedReason(rawValue: raw.int16Value)!
        }
    }

}
