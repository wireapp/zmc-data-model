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


/// This class is used to mark conversations as modified in an extension 
/// context in order to refetch them in the main application.
@objc public class SharedModifiedConversationsList: NSObject {

    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func add(conversations: [ZMConversation]) {
        let identifiers = storedIdentifiers() + conversations.flatMap { $0.remoteIdentifier }
        let identifiersAsString = identifiers.map { $0.uuidString }
        let unique = Array(Set(identifiersAsString))
        (unique as NSArray).write(to: url, atomically: true)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    public func storedIdentifiers() -> Set<UUID> {
        let stored = NSArray(contentsOf: url) as? [String]
        if let identifiers = stored?.flatMap(UUID.init) {
            return Set(identifiers)
        }
        return []
    }

}
