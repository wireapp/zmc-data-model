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

@objcMembers public final class DraftMessage: NSObject {
    public let text: String
    public let mentions: [Mention]
    
    public init(text: String, mentions: [Mention]) {
        self.text = text
        self.mentions = mentions
        super.init()
    }
    
    fileprivate var storable: StorableDraftMessage {
        return .init(text: text, mentions: mentions.compactMap(\.storable))
    }
}

fileprivate extension UserType {
    var userIdentifier: UUID? {
        if let user = self as? ZMUser {
            return user.remoteIdentifier
        }
        return nil
    }
}


fileprivate final class StorableDraftMessage: NSObject, Codable {
    let text: String
    let mentions: [StorableMention]
    
    init(text: String, mentions: [StorableMention]) {
        self.text = text
        self.mentions = mentions
        super.init()
    }
    
    fileprivate func draftMessage(in context: NSManagedObjectContext) -> DraftMessage {
        return .init(text: text, mentions: mentions.compactMap { $0.mention(in: context) })
    }
}


fileprivate struct StorableMention: Codable {
    let range: NSRange
    let userIdentifier: UUID
    
    func mention(in context: NSManagedObjectContext) -> Mention? {
        return ZMUser(remoteID: userIdentifier, createIfNeeded: false, in: context).map(papply(Mention.init, range))
    }
}

fileprivate extension Mention {
    var storable: StorableMention? {
        return user.userIdentifier.map {
            StorableMention(range: range, userIdentifier: $0)
        }
    }
}

@objc extension ZMConversation {
    
    @NSManaged var draftMessageData: Data?

    public var draftMessage: DraftMessage? {
        set {
            if let value = newValue {
                draftMessageData = try? JSONEncoder().encode(value.storable)
            } else {
                draftMessageData = nil
            }
        }
        
        get {
            guard let data = draftMessageData, let context = managedObjectContext else { return nil }
            do {
                let storable = try JSONDecoder().decode(StorableDraftMessage.self, from: data)
                return storable.draftMessage(in: context)
            } catch {
                draftMessageData = nil
                return nil
            }
        }

    }

}
