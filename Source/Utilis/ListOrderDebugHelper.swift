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
import ZMCSystem

private let zmLog = ZMSLog(tag: "List Order")

@objc public class ListOrderDebugHelper: NSObject {

    private class var shouldLog: Bool {
        return ZMDeploymentEnvironment().environmentType() != .appStore
    }

    @objc(logCurrentConversationListOrderInContext:authorative:)
    public class func logCurrentConversationListOrder(in context: NSManagedObjectContext, authorative: Bool) {
        guard shouldLog else { return }

        let unarchived = context.conversationListDirectory().unarchivedAndNotCallingConversations.flatMap { $0 as? ZMConversation }
        let sorted = unarchived.sorted { lhs, rhs in
            lhs.lastModifiedDate.compare(rhs.lastModifiedDate) != .orderedAscending
        }

        if unarchived != sorted || authorative {
            let equal = unarchived == sorted ? "equal" : "not equal"
            let unarchivedDescription = unarchived.map(conversationDescription).joined(separator: "\n")
            let sortedDescription = sorted.map(conversationDescription).joined(separator: "\n")
            let callStack = Thread.callStackSymbols.joined(separator: "\n")

            zmLog.info("Conversation list order is --->> \(equal) to a resorted list:\n\nContent of `ZMConversationListDirectory.unarchivedAndNotCallingConversations`:\n\n\(unarchivedDescription)\n\nSorted:\n\n\(sortedDescription)\n\nCallstack:\n\n\(callStack)")
        }
    }

    private class func conversationDescription(_ conversation: ZMConversation) -> String {
        return "\(conversation.displayName.padding(toLength: 30, withPad: " ", startingAt: 0)) – \(conversation.lastModifiedDate)"
    }

    @objc(logConversationListChange:currentList:)
    public class func logConversationListChange(info: ConversationListChangeInfo, current aggregated: [ZMConversation]) {
        guard shouldLog else { return }

        var conversations = [ZMConversation]()
        for (idx, element) in info.conversationList.enumerated() {
            guard idx < 30 else { break }
            if let conversation = element as? ZMConversation {
                conversations.append(conversation)
            }
        }

        zmLog.info("Conversation list did change triggered for --->> \(info.conversationList.identifier)\n\nCurrent:\n\n\(aggregated.map(conversationDescription).joined(separator: "\n"))\n\nNew (first 30):\n\n\(conversations.map(conversationDescription).joined(separator: "\n"))\n\nChange inserted: \(info.insertedIndexes), deleted: \(info.deletedIndexes), updated: \(info.updatedIndexes), needsReload: \(info.needsReload)")
    }

    @objc(logUpdatedLastModifiedDateOfConversation:callStack:)
    public class func logUpdatedLastModifiedDate(of conversation: ZMConversation, with callStack: [String]) {
        guard shouldLog else { return }

        zmLog.info("Conversation \"\(conversation.displayName)\" did update lastModifiedDate to \(conversation.lastModifiedDate), callStack:\n\n\(callStack.joined(separator: "\n"))\n\nLast message:\n\n\(conversation.messages.lastObject)")
    }

    @objc(logResortingConversation:inList:)
    public class func logResorting(conversation: ZMConversation, in list: ZMConversationList) {
        zmLog.info("Resorting \(conversation.displayName) in \(list.identifier)")
    }
    
}
