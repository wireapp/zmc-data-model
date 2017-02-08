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
import ZMUtilities


extension ZMMessage {

    func updateNormalizedText() {
        // no-op
    }

}

extension ZMClientMessage {

    override func updateNormalizedText() {
        // TODO: Check transforms
        if let normalized = textMessageData?.messageText?.normalized() as? String {
            normalizedText = normalized
        } else {
            normalizedText = ""
        }
    }

}

extension ZMMessage {

    static func predicateForMessagesMatching(_ query: String) -> NSPredicate {
        let components = query.components(separatedBy: .whitespaces)
        let predicates = components.map { NSPredicate(format: "%K MATCHES[n] %@", #keyPath(ZMMessage.normalizedText), $0) }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    static func predicateForMessages(in conversationID: NSManagedObjectID) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(ZMMessage.visibleInConversation), conversationID)
    }

    static func predicateForNotIndexedMessages() -> NSPredicate {
        return NSPredicate(format: "%K == NULL", #keyPath(ZMMessage.normalizedText))
    }

}

func &&(lhs: NSPredicate, rhs: NSPredicate) -> NSPredicate {
    return NSCompoundPredicate(andPredicateWithSubpredicates: [lhs, rhs])
}

func ||(lhs: NSPredicate, rhs: NSPredicate) -> NSPredicate {
    return NSCompoundPredicate(orPredicateWithSubpredicates: [lhs, rhs])
}


public protocol TextSearchQueryDelegate: class {
    func textSearchQueryDidFetch(messages: [ZMMessage], hasMore: Bool)
}


public class TextSearchQuery: NSObject {

    private let uiMOC: NSManagedObjectContext
    private let syncMOC: NSManagedObjectContext

    private let conversation: ZMConversation
    private let query: String

    private let notIndexedBatchSize = 200
    private let indexedBatchSize = 200
    private var lastIndexedServerTimestamp: Date? = nil

    private weak var delegate: TextSearchQueryDelegate?

    private var cancelled = false

    init?(conversation: ZMConversation, query: String, delegate: TextSearchQueryDelegate) {
        guard query.characters.count > 0 else { return nil }
        guard let uiMOC = conversation.managedObjectContext, let syncMOC = uiMOC.zm_sync else {
            fatal("NSManagedObjectContexts not accessible")
        }

        self.uiMOC = uiMOC
        self.syncMOC = syncMOC
        self.conversation = conversation
        self.query = query
        self.delegate = delegate
        super.init()
    }

    public func execute() {
        executeQueryForIndexedMessages()
        executeQueryForNonIndexedMessages()
    }

    func cancel() {
        cancelled = true
    }

    private func executeQueryForIndexedMessages() {
        var predicate = predicateForQueryMatch
        if let lastTimestamp = lastIndexedServerTimestamp {
            predicate = predicate && NSPredicate(format: "%K < %@", #keyPath(ZMMessage.serverTimestamp), lastTimestamp as NSDate)
        }

        syncMOC.performGroupedBlock { [unowned self] in
            let request = ZMMessage.sortedFetchRequest(with: predicate)
            request?.fetchBatchSize = self.indexedBatchSize

            guard let matches = self.syncMOC.executeFetchRequestOrAssert(request) as? [ZMMessage] else { return } // TODO
            let hasMore = matches.count > 0

            // TODO: Update a storage of all found matches that the UI can query?

            // Notify the delegate
            self.notifyDelegate(with: matches, hasMore: hasMore)


            if hasMore && !self.cancelled {
                self.lastIndexedServerTimestamp = matches.last?.serverTimestamp
                self.executeQueryForIndexedMessages()
            }
        }
    }

    private func executeQueryForNonIndexedMessages() {
        let nonIndexPredicate = predicateForNotIndexedMessages
        let queryPredicate = predicateForQueryMatch

        syncMOC.performGroupedBlock { [weak self] in
            guard let `self` = self else { return }
            let request = ZMMessage.sortedFetchRequest(with: nonIndexPredicate)
            request?.fetchBatchSize = self.notIndexedBatchSize

            guard let messagesToIndex = self.syncMOC.executeFetchRequestOrAssert(request) as? [ZMMessage] else { return } // TODO
            messagesToIndex.forEach {
                $0.updateNormalizedText()
            }

            let matches = (messagesToIndex as NSArray).filtered(using: queryPredicate)
            let hasMore = matches.count > 0

            // TODO: Update a storage of all found matches that the UI can query?

            // Notify the delegate
            self.notifyDelegate(with: matches as! [ZMMessage], hasMore: hasMore)


            if hasMore && !self.cancelled {
                self.executeQueryForNonIndexedMessages()
            }
        }

    }

    /// Fetches the objects on the UI context and notifies the delegate
    private func notifyDelegate(with messages: [ZMMessage], hasMore: Bool) {
        let objectIDs = messages.map { $0.objectID }
        uiMOC.performGroupedBlock { [weak self] in
            guard let `self` = self else { return }
            let uiMessages = objectIDs.flatMap {
                (try? self.uiMOC.existingObject(with: $0)) as? ZMMessage
            }

            self.delegate?.textSearchQueryDidFetch(messages: uiMessages, hasMore: hasMore)
        }
    }

    private lazy var predicateForQueryMatch: NSPredicate = {
        return ZMMessage.predicateForMessagesMatching(self.query)
            && ZMMessage.predicateForMessages(in: self.conversation.objectID)
    }()

    private lazy var predicateForNotIndexedMessages: NSPredicate = {
        return ZMMessage.predicateForNotIndexedMessages()
            && ZMMessage.predicateForMessages(in: self.conversation.objectID)

    }()

}

