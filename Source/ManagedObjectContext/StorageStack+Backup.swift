////
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
import WireUtilities

extension StorageStack {

    // Each backup for any account will be created in a unique subdirectory inside.
    // Clearing this should remove all
    public static var backupsDirectory: URL {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return tempURL.appendingPathComponent("backups")
    }

    public enum BackupError: Error {
        case error
    }

    /// Will make a copy of account storage and place in a unique directory
    ///
    /// - Parameters:
    ///   - accountIdentifier: identifier of account being backed up
    ///   - applicationContainer: shared application container
    ///   - dispatchGroup: group for testing
    ///   - completion: called on main thread when done. Result will contain the folder where all data was written to.
    public static func backupLocalStorage(accountIdentifier: UUID, applicationContainer: URL, dispatchGroup: ZMSDispatchGroup? = nil, completion: @escaping ((Result<URL>) -> Void)) {

        let accountDirectory = StorageStack.accountFolder(accountIdentifier: accountIdentifier, applicationContainer: applicationContainer)
        let storeFile = accountDirectory.appendingPersistentStoreLocation()
        let queue = DispatchQueue(label: "Database export", qos: .userInitiated)

        let target = backupsDirectory.appendingPathComponent(UUID().uuidString)

        dispatchGroup?.enter()
        queue.async() {
            let model = NSManagedObjectModel.loadModel()
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            do {
                var readOptions = NSPersistentStoreCoordinator.persistentStoreOptions(supportsMigration: false)
                // We don't want to change anything in there
                readOptions[NSReadOnlyPersistentStoreOption] = true

                // Create persistent store from what we have on disk
                let persistentStore = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeFile, options: readOptions)

                // Create target directory
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true, attributes: nil)
                let storeLocation = target.appendingStoreFile()

                let writeOptions = NSPersistentStoreCoordinator.persistentStoreOptions(supportsMigration: false)
                // Recreate the persistent store inside a new location
                try coordinator.migratePersistentStore(persistentStore, to: storeLocation, options: writeOptions, withType: NSSQLiteStoreType)
                DispatchQueue.main.async {
                    completion(.success(target))
                }
                dispatchGroup?.leave()
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(BackupError.error))
                }
                dispatchGroup?.leave()
            }
        }
    }
}
