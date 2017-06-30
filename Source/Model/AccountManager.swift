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


private let log = ZMSLog(tag: "Accounts")


public protocol LoginProvider {
    func login(_ account: Account, completion: (Bool) -> Void)
}


/// Class used to safely access and change stored accounts and the current selected account.
public final class AccountManager: NSObject {

    static let selectedAccountKey = "AccountManagerSelectedAccountKey"

    private let defaults = UserDefaults.shared()
    private(set) public var accounts = [Account]()
    private(set) public var selectedAccount: Account? // The currently selected account or `nil` in case there is none

    private(set) public var selectedAccountIdentifier: UUID? {
        get { return defaults?.string(forKey: AccountManager.selectedAccountKey).flatMap(UUID.init) }
        set { defaults?.set(newValue?.uuidString, forKey: AccountManager.selectedAccountKey) }
    }

    private var store: AccountStore
    private let loginProvider: LoginProvider

    /// Creates a new `AccountManager`.
    /// - parameter sharedDirectory: The directory of the shared container.
    /// - parameter loginProvider: The login provider object to login accounts.
    public init(sharedDirectory: URL, loginProvider: LoginProvider) {
        store = AccountStore(root: sharedDirectory)
        self.loginProvider = loginProvider
        super.init()
        selectedAccountIdentifier = UserDefaults.shared().string(forKey: AccountManager.selectedAccountKey).flatMap(UUID.init)
        updateAccounts()
    }

    /// Adds an account to the manager and persists it.
    /// - parameter account: The account to add.
    public func add(_ account: Account) {
        store.add(account)
        updateAccounts()
    }

    /// Removes an account from the manager and the persistsence layer.
    /// - parameter account: The account to remove.
    public func remove(_ account: Account) {
        store.remove(account)
        if selectedAccount == account {
            selectedAccountIdentifier = nil
        }
        updateAccounts()
    }

    /// Selects a new account. The `LoginProvider` is asked to perform the login operation.
    /// In case the operation completes successfully the passed in account will be selected.
    /// - parameter account: The account to select.
    public func select(_ account: Account) {
        guard account != selectedAccount else { return }
        loginProvider.login(account) { [weak self] success in
            guard let `self` = self else { return }
            if success {
                self.selectedAccountIdentifier = account.userIdentifier
                self.updateAccounts()
            } else {
                log.error("Unable to select account: \(account)")
            }
        }
    }

    // MARK: - Private Helper

    /// Updates the local accounts array and the selected account.
    /// This method should be called each time accounts are added or
    /// removed, or when the selectedAccountIdentifier has been changed.
    private func updateAccounts() {
        accounts = computeSortedAccounts()
        selectedAccount = computeSelectedAccount()
    }

    /// Loads and computes the locally selected account if any
    /// - returns: The currently selected account or `nil` if there is none.
    private func computeSelectedAccount() -> Account? {
        return selectedAccountIdentifier.flatMap(store.load)
    }

    /// Loads and sorts the stored accounts.
    /// - returns: An Array consisting of the sorted accounts. Accounts without team will
    /// be first, sorted by their user name. Accounts with team will be last,
    /// sorted by their team name.
    private func computeSortedAccounts() -> [Account] {
        return store.load().sorted { lhs, rhs in
            switch (lhs.teamName, rhs.teamName) {
            case (.some, .none): return false
            case (.none, .some): return true
            case (.some(let leftName), .some(let rightName)): return leftName < rightName
            default: return lhs.userName < rhs.userName
            }
        }
    }
    
}
