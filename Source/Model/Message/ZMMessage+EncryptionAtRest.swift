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

extension ZMMessage {

    static func migrateTowardEncryptionAtRest(in moc: NSManagedObjectContext) throws {
        do {
            for instance in try fetchRequest(batchSize: 100).execute() {
                instance.migrateTowardEncryptionAtRest()
            }
        } catch {
            throw NSManagedObjectContext.MigrationError.failedToMigrateZMMessage(reason: error.localizedDescription)
        }
    }

    static func migrateAwayFromEncryptionAtRest(in moc: NSManagedObjectContext) throws {
        do {
            for instance in try fetchRequest(batchSize: 100).execute() {
                instance.migrateAwayFromEncryptionAtRest()
            }
        } catch {
            throw NSManagedObjectContext.MigrationError.failedToMigrateZMMessage(reason: error.localizedDescription)
        }
    }

    private static func fetchRequest(batchSize: Int) -> NSFetchRequest<ZMMessage> {
        let fetchRequest = NSFetchRequest<ZMMessage>(entityName: entityName())
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.fetchBatchSize = batchSize
        return fetchRequest
    }

    private func migrateTowardEncryptionAtRest() {
        normalizedText = ""
    }

    private func migrateAwayFromEncryptionAtRest() {
        updateNormalizedText()
    }


}
