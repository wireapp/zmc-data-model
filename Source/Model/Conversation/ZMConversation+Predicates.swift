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


extension NSPredicate {
    
    func negated() -> NSCompoundPredicate {
        return NSCompoundPredicate(notPredicateWithSubpredicate: self)
    }
    
}

extension ZMConversation {
    
    override open class func predicateForFilteringResults() -> NSPredicate {
        let selfType = ZMConversationType.init(rawValue: 1)!
        return NSPredicate(format: "\(ZMConversationConversationTypeKey) != \(ZMConversationType.invalid.rawValue) && \(ZMConversationConversationTypeKey) != \(selfType.rawValue)")
    }
    
    class func predicateForPendingConversations() -> NSPredicate {
        let basePredicate = predicateForFilteringResults()
        let pendingConversationPredicate = NSPredicate(format: "\(ZMConversationConversationTypeKey) == \(ZMConversationType.connection.rawValue) AND \(ZMConversationConnectionKey).status == \(ZMConnectionStatus.pending.rawValue)")
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, pendingConversationPredicate])
    }
    
    class func predicateForClearedConversations() -> NSPredicate {
        let cleared = NSPredicate(format: "\(ZMConversationClearedTimeStampKey) != NULL AND \(ZMConversationIsArchivedKey) == YES")
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [cleared, predicateForValidConversations()])
    }
    
    class func predicateForConversationsIncludingArchived() -> NSPredicate {
        let notClearedTimestamp = NSPredicate(format: "\(ZMConversationClearedTimeStampKey) == NULL OR \(ZMConversationLastServerTimeStampKey) > \(ZMConversationClearedTimeStampKey) OR (\(ZMConversationLastServerTimeStampKey) == \(ZMConversationClearedTimeStampKey) AND \(ZMConversationIsArchivedKey) == NO)")
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [notClearedTimestamp, predicateForValidConversations()])
    }
    
    class func predicateForArchivedConversations() -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [predicateForConversationsIncludingArchived(), NSPredicate(format: "\(ZMConversationIsArchivedKey) == YES")])
    }
    
    class func predicateForConversationsExcludingArchivedAndInCall() -> NSPredicate {
        let notArchivedPredicate = NSPredicate(format: "\(ZMConversationIsArchivedKey) == NO")
        let callingPredicateV2 = predicate(forConversationWithVoiceChannelState: .selfConnectedToActiveChannel).negated()
        let callingPredicateV3 = predicate(forConversationWithCallState: .established).negated()
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [predicateForConversationsIncludingArchived(), notArchivedPredicate, callingPredicateV2, callingPredicateV3])
    }
    
    class func predicateForConversationsWithNonIdleVoiceChannel() -> NSPredicate {
        let basePredicate = predicateForFilteringResults()
        let notConnectionPredicate = NSPredicate(format: "\(ZMConversationConversationTypeKey) != \(ZMConversationType.connection.rawValue)")
        let callingPredicateV2 = predicate(forConversationWithVoiceChannelState: .noActiveUsers).negated()
        let callingPredicateV3 = predicate(forConversationWithCallState: .established)
        let callingPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [callingPredicateV2, callingPredicateV3])
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, notConnectionPredicate, callingPredicate])
    }
    
    class func predicateForConversationWithActiveCalls() -> NSPredicate {
        let basePredicate = predicateForFilteringResults()
        let callingPredicateV2 = predicate(forConversationWithVoiceChannelState: .selfConnectedToActiveChannel)
        let callingPredicateV3 = predicate(forConversationWithCallState: .established)
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, NSCompoundPredicate(orPredicateWithSubpredicates: [callingPredicateV2, callingPredicateV3])])
    }
    
    class func predicateForSharableConversations() -> NSPredicate {
        let basePredicate = predicateForConversationsIncludingArchived()
        let hasOtherActiveParticipants = NSPredicate(format: "\(ZMConversationOtherActiveParticipantsKey).@count > 0")
        let oneOnOneOrGroupConversation = NSPredicate(format: "\(ZMConversationConversationTypeKey) == \(ZMConversationType.oneOnOne.rawValue) OR \(ZMConversationConversationTypeKey) == \(ZMConversationType.group.rawValue)")
        let selfIsActiveMember = NSPredicate(format: "isSelfAnActiveMember == YES")
        let synced = NSPredicate(format: "\(remoteIdentifierDataKey()!) != NULL")
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, oneOnOneOrGroupConversation, hasOtherActiveParticipants, selfIsActiveMember, synced])
    }
    
    private class func predicateForValidConversations() -> NSPredicate {
        let basePredicate = predicateForFilteringResults()
        let notAConnection = NSPredicate(format: "\(ZMConversationConversationTypeKey) != \(ZMConversationType.connection.rawValue)")
        let activeConnection = NSPredicate(format: "NOT \(ZMConversationConnectionKey).status IN %@", [NSNumber(value: ZMConnectionStatus.pending.rawValue),
                                                                                                       NSNumber(value: ZMConnectionStatus.ignored.rawValue),
                                                                                                       NSNumber(value: ZMConnectionStatus.cancelled.rawValue)]) //pending connections should be in other list, ignored and cancelled are not displayed
        let predicate1 = NSCompoundPredicate(orPredicateWithSubpredicates: [notAConnection, activeConnection]) // one-to-one conversations and not pending and not ignored connections
        let noConnection = NSPredicate(format: "\(ZMConversationConnectionKey) == nil") // group conversations
        let notBlocked = NSPredicate(format: "\(ZMConversationConnectionKey).status != \(ZMConnectionStatus.blocked.rawValue)")
        let predicate2 = NSCompoundPredicate(orPredicateWithSubpredicates: [noConnection, notBlocked]) //group conversations and not blocked connections
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, predicate1, predicate2])
    }
    
    private class func predicate(forConversationWithVoiceChannelState voiceChannelState: ZMVoiceChannelState) -> NSPredicate {
        return NSPredicate(format: "voiceChannelState == %d", voiceChannelState.rawValue)
    }
    
    private class func predicate(forConversationWithCallState callState: CallState) -> NSPredicate {
        return NSPredicate { (object, _) -> Bool in
            guard
                let conversation = object as? ZMConversation,
                let remoteIdentifier = conversation.remoteIdentifier else {
                    return false
            }
            
            return WireCallCenter.activeInstance?.callState(conversationId: remoteIdentifier) == callState
        }
    }
    
}
