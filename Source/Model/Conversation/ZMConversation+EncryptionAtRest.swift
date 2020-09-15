//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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

extension ZMConversation {

    static func migrateTowardEncryptionAtRest(in moc: NSManagedObjectContext) throws {
        do {
            for instance in try fetchRequest(batchSize: 100).execute() {
                try instance.migrateTowardEncryptionAtRest(in: moc)
            }
        } catch {
            throw NSManagedObjectContext.MigrationError.failedToEncryptDatabase(reason: error.localizedDescription)
        }
    }

    static func migrateAwayFromEncryptionAtRest(in moc: NSManagedObjectContext) throws {
        do {
            for instance in try fetchRequest(batchSize: 100).execute() {
                try instance.migrateAwayFromEncryptionAtRest(in: moc)
            }
        } catch {
            throw NSManagedObjectContext.MigrationError.failedToDecryptDatabase(reason: error.localizedDescription)
        }
    }

    private static func fetchRequest(batchSize: Int) -> NSFetchRequest<ZMConversation> {
        let fetchRequest = NSFetchRequest<ZMConversation>(entityName: entityName())
        fetchRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(ZMConversation.hasDraftMessage))
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.fetchBatchSize = batchSize
        return fetchRequest
    }

    private func migrateTowardEncryptionAtRest(in moc: NSManagedObjectContext) throws {
        guard let data = draftMessageData else { return }
        let (ciphertext, nonce) = try moc.encryptData(data: data)
        draftMessageData = ciphertext
        draftMessageNonce = nonce
    }

    private func migrateAwayFromEncryptionAtRest(in moc: NSManagedObjectContext) throws {
        guard
            let data = draftMessageData,
            let nonce = draftMessageNonce
        else {
            return
        }

        let plaintext = try moc.decryptData(data: data, nonce: nonce)
        draftMessageData = plaintext
        draftMessageNonce = nil
    }

}
