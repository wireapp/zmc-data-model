//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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

protocol WithUniqueIdentifier: NSFetchRequestResult {
    var uniqueIdentifier: String? { get set }
    var remoteIdentifier: UUID? { get }
    static func entityName() -> String
    static func remoteIdentifierDataKey() -> String?
}

extension WithUniqueIdentifier {

    /// CoreData uniquing works only with String properties, but out remoteIdentifier is a UUID.
    /// We need to manually set the uniqueIdentifier to be the same as remoteIdentifier for all existing entries.
    /// Before this is run we need to ensure there are no duplicates in the local storage.
    static func addUniqueIdentifiers(in moc: NSManagedObjectContext) {
        guard let remoteIdentifierDataKey = self.remoteIdentifierDataKey() else { return }
        let request = NSFetchRequest<Self>(entityName: self.entityName())
        request.propertiesToFetch = [remoteIdentifierDataKey]
        request.predicate = NSPredicate(format: "\(remoteIdentifierDataKey) != nil")
        do {
            let results = try moc.fetch(request)
            results.forEach {
                $0.uniqueIdentifier = $0.remoteIdentifier?.uuidString
            }
        } catch {}
    }
}

extension ZMUser: WithUniqueIdentifier {}
extension ZMConversation: WithUniqueIdentifier {}
