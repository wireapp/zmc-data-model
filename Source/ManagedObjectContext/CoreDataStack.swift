//
// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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
import CoreData

@objc
public protocol ContextProvider {

    var account: Account { get }

    var viewContext: NSManagedObjectContext { get }
    var syncContext: NSManagedObjectContext { get }
    var searchContext: NSManagedObjectContext { get }

}

@objcMembers
public class CoreDataStack: NSObject, ContextProvider {

    public let account: Account

    public let viewContext: NSManagedObjectContext
    public let syncContext: NSManagedObjectContext
    public let searchContext: NSManagedObjectContext

    public let accountContainer: URL
    public let applicationContainer: URL

    let container: PersistentContainer
    let dispatchGroup: ZMSDispatchGroup?

    public init(account: Account,
                applicationContainer: URL,
                inMemoryStore: Bool = false,
                dispatchGroup: ZMSDispatchGroup? = nil) {

        if #available(iOSApplicationExtension 12.0, *) {
            ExtendedSecureUnarchiveFromData.register()
        }

        self.applicationContainer = applicationContainer
        self.account = account
        self.dispatchGroup = dispatchGroup

        let accountDirectory = Self.accountFolder(accountIdentifier: account.userIdentifier,
                                                  applicationContainer: applicationContainer)

        self.accountContainer = accountDirectory

        let storeURL = accountDirectory.appendingPersistentStoreLocation()
        let container = PersistentContainer(name: "zmessaging")
        let description: NSPersistentStoreDescription

        if inMemoryStore {
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
        } else {
            description = NSPersistentStoreDescription(url: storeURL)

            // https://www.sqlite.org/pragma.html
            description.setValue("WAL" as NSObject,
                                 forPragmaNamed: "journal_mode")
            description.setValue("FULL" as NSObject,
                                 forPragmaNamed: "synchronous")
            description.setValue("TRUE" as NSObject,
                                 forPragmaNamed: "secure_delete")
        }

        container.persistentStoreDescriptions = [description]

        self.container = container
        viewContext = container.viewContext
        syncContext = container.newBackgroundContext()
        searchContext = container.newBackgroundContext()

        super.init()

        #if DEBUG
        MemoryReferenceDebugger.register(viewContext)
        MemoryReferenceDebugger.register(syncContext)
        MemoryReferenceDebugger.register(searchContext)
        #endif
    }

    public func loadStore(completionHandler: @escaping (Error?) -> Void) {
        container.loadPersistentStores { (store, error) in
            guard error == nil else {
                return completionHandler(error)
            }

            self.configureViewContext(self.viewContext)
            self.configureSyncContext(self.syncContext)
            self.configureSearchContext(self.searchContext)

            completionHandler(nil)
        }
    }

    func configureViewContext(_ context: NSManagedObjectContext) {
        context.markAsUIContext()
        context.createDispatchGroups()
        dispatchGroup.apply(context.add)
        context.mergePolicy = NSMergePolicy(merge: .rollbackMergePolicyType)
        ZMUser.selfUser(in: context)
        Label.fetchOrCreateFavoriteLabel(in: context, create: true)
    }

    func configureSyncContext(_ context: NSManagedObjectContext) {
        context.markAsSyncContext()
        context.performAndWait {
            context.createDispatchGroups()
            dispatchGroup.apply(context.add)
            context.setupLocalCachedSessionAndSelfUser()
            context.setupUserKeyStore(accountDirectory: accountContainer,
                                      applicationContainer: applicationContainer)
            context.undoManager = nil
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        }
    }

    func configureSearchContext(_ context: NSManagedObjectContext) {
        context.markAsSearch()
        context.performAndWait {
            context.createDispatchGroups()
            dispatchGroup.apply(context.add)
            context.setupLocalCachedSessionAndSelfUser()
            context.undoManager = nil
            context.mergePolicy = NSMergePolicy(merge: .rollbackMergePolicyType)

        }
    }

    static func accountFolder(accountIdentifier: UUID, applicationContainer: URL) -> URL {
        return applicationContainer
            .appendingPathComponent("AccountData")
            .appendingPathComponent(accountIdentifier.uuidString)
    }

}

class PersistentContainer: NSPersistentContainer { }
