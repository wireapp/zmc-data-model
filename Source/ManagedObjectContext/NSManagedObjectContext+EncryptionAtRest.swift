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
import WireCryptobox

extension NSManagedObjectContext {
    
    enum EncryptionError: LocalizedError {

        case missingDatabaseKey
        case cryptobox(error: ChaCha20Poly1305.AEADEncryption.EncryptionError)

        var errorDescription: String? {
            switch self {
            case .missingDatabaseKey:
                return "Database key not found. Perhaps the database is locked."
            case .cryptobox(let error):
                return error.errorDescription
            }
        }

    }

}

extension NSManagedObjectContext {

    // TODO: [John] would be good to have some more granularity.

    enum MigrationError: LocalizedError {

        case missingDatabaseKey
        case failedToEncryptDatabase
        case failedToDecryptDatabase

        var errorDescription: String? {
            switch self {
            case .missingDatabaseKey:
                return "The database key is missing, encryption / decryption is not possible."
            case .failedToEncryptDatabase:
                return "The database couldn't be encrypted."
            case .failedToDecryptDatabase:
                return "The database couldn't be decrypted."
            }
        }

    }

    // Question: do we discard the dirty state if we fail? Or that is the responsibility of the caller?
    // I think it makes sense to give responsibility to the caller to save the context.

    /// Enables encryption at rest after sucessfuly encrypting the existing database.
    ///
    /// Depending on the size of the database, the migration may take a long time and will block the
    /// thread. If the migration fails for any reason, the feature is not enabled, but the context may
    /// be in a dirty, partially migrated state.
    ///
    /// - Throws: `MigrationError` if the migration failed.

    public func enableEncryptionAtRest() throws {
        guard let databaseKey = encryptionKeys?.databaseKey else { throw MigrationError.missingDatabaseKey }

        do {
            try ZMGenericMessageData.migrateTowardEncryptionAtRest(withKey: databaseKey, in: self)
        } catch {
            throw MigrationError.failedToEncryptDatabase
        }

        encryptMessagesAtRest = true
    }

    /// Disables encryption at rest after sucessfuly decrypting the existing database.
    ///
    /// Depending on the size of the database, the migration may take a long time and will block the
    /// thread. If the migration fails for any reason, the feature is not disabled, but the context may
    /// be in a dirty, partially migrated state.
    ///
    /// - Throws: `MigrationError` if the migration failed.

    public func disableEncryptionAtRest() throws {
        guard let databaseKey = encryptionKeys?.databaseKey else { throw MigrationError.missingDatabaseKey }

        do {
            try ZMGenericMessageData.migrateAwayFromEncryptionAtRest(withKey: databaseKey, in: self)
        } catch {
            throw MigrationError.failedToDecryptDatabase
        }

        encryptMessagesAtRest = false
    }
    
    private(set) public var encryptMessagesAtRest: Bool {
        set {
            setPersistentStoreMetadata(NSNumber(booleanLiteral: newValue),
                                       key: PersistentMetadataKey.encryptMessagesAtRest.rawValue)
        }
        get {
            (persistentStoreMetadata(forKey: PersistentMetadataKey.encryptMessagesAtRest.rawValue) as? NSNumber)?.boolValue ?? false
        }
    }
    
    // MARK: - Encryption / Decryption
    
    func encryptData(data: Data) throws -> (data: Data, nonce: Data) {
        guard let key = encryptionKeys?.databaseKey else { throw EncryptionError.missingDatabaseKey }
        let context = contextData()

        do {
            let (ciphertext, nonce) = try ChaCha20Poly1305.AEADEncryption.encrypt(message: data, context: context, key: key._storage)
            return (ciphertext, nonce)
        } catch let error as ChaCha20Poly1305.AEADEncryption.EncryptionError {
            throw EncryptionError.cryptobox(error: error)
        }

    }
    
    func decryptData(data: Data, nonce: Data) throws -> Data {
        guard let key = encryptionKeys?.databaseKey else { throw EncryptionError.missingDatabaseKey }
        let context = contextData()

        do {
            return try ChaCha20Poly1305.AEADEncryption.decrypt(ciphertext: data, nonce: nonce, context: context, key: key._storage)
        } catch let error as ChaCha20Poly1305.AEADEncryption.EncryptionError {
            throw EncryptionError.cryptobox(error: error)
        }
    }

    private func contextData() -> Data {
        let selfUser = ZMUser.selfUser(in: self)

        guard
            let selfClient = selfUser.selfClient(),
            let selfUserId = selfUser.remoteIdentifier?.transportString(),
            let selfClientId = selfClient.remoteIdentifier,
            let context = (selfUserId + selfClientId).data(using: .utf8)
        else {
            fatalError("Could not obtain self user id and self client id")
        }

        return context
    }

    // MARK: - Database Key

    private static let encryptionKeysUserInfoKey = "encryptionKeys"

    public var encryptionKeys: EncryptionKeys? {
        set { userInfo[Self.encryptionKeysUserInfoKey] = newValue }
        get { userInfo[Self.encryptionKeysUserInfoKey] as? EncryptionKeys }
    }

}
