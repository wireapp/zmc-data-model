//
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

@objc
public enum MutedMessageOptionValue: Int32 {
    case none = 0
    case regular = 1
    case mentionsAndReplies = 2
    case all = 3
}

/// Defines what kind of messages are muted.
/// +--------------------+----------------+----------------------------------------+--------+
/// | mutedStatus        | Normal Message | Message that contains mention or reply |  Call  |
/// +--------------------+----------------+----------------------------------------+--------+
/// | none               | Notify         | Notify                                 | Notify |
/// | regular            | X              | Notify                                 | X      |
/// | mentionsAndReplies | Notify         | X                                      | Notify |
/// | all                | X              | X                                      | X      |
/// +--------------------+----------------+----------------------------------------+--------+
public struct MutedMessageTypes: OptionSet {
    public let rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    /// None of the messages are muted.
    public static let none = MutedMessageTypes(rawValue: MutedMessageOptionValue.none.rawValue)

    /// All messages, including mentions, are muted.
    public static let all: MutedMessageTypes = [.regular, .mentionsAndReplies]
    
    /// Only regular messages (no mentions nor replies) are muted.
    public static let regular = MutedMessageTypes(rawValue: MutedMessageOptionValue.regular.rawValue)
    
    /// Only mentions and replis are muted. Only used to check the bits in the bitmask.
    /// Please do not set this as the value on the conversation.
    public static let mentionsAndReplies = MutedMessageTypes(rawValue: MutedMessageOptionValue.mentionsAndReplies.rawValue)
}

public extension ZMConversation {
    @NSManaged @objc public var mutedStatus: Int32
    
    public var mutedMessageTypes: MutedMessageTypes {
        get {
            guard let managedObjectContext = self.managedObjectContext else {
                return .none
            }
            
            let selfUser = ZMUser.selfUser(in: managedObjectContext)
            
            if selfUser.hasTeam {
                return MutedMessageTypes(rawValue: mutedStatus)
            }
            else {
                return mutedStatus == MutedMessageOptionValue.none.rawValue ? MutedMessageTypes.none : MutedMessageTypes.all
            }
        }
        set {
            guard let managedObjectContext = self.managedObjectContext else {
                return
            }
            
            let selfUser = ZMUser.selfUser(in: managedObjectContext)
            
            if selfUser.hasTeam {
                mutedStatus = newValue.rawValue
            }
            else {
                mutedStatus = (newValue == .none) ? MutedMessageOptionValue.none.rawValue : (MutedMessageOptionValue.all.rawValue)
            }
            
            if managedObjectContext.zm_isUserInterfaceContext,
                let lastServerTimestamp = self.lastServerTimeStamp {
                updateMuted(lastServerTimestamp, synchronize: true)
            }
        }
    }
}

extension ZMConversationMessage {
    public var isSilenced: Bool {
        guard let conversation = self.conversation else {
            return false
        }
        
        guard let sender = self.sender, !sender.isSelfUser else {
            return true
        }
        
        if conversation.mutedMessageTypes == .none {
            return false
        }
        
        guard let textMessageData = self.textMessageData else {
            return true
        }
        
        if conversation.mutedMessageTypes == .regular && (textMessageData.isMentioningSelf || textMessageData.isQuotingSelf) {
            return false
        }
        else {
            return true
        }
    }
}
