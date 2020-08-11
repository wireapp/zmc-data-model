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
import WireCryptobox

@objc(ZMGenericMessageData)
@objcMembers public class ZMGenericMessageData: ZMManagedObject {

    private static let log = ZMSLog(tag: "EAR")

    // MARK: - Static

    override open class func entityName() -> String {
        return "GenericMessageData"
    }

    public static let dataKey = "data"
    public static let nonceKey = "nonce"
    public static let messageKey = "message"
    public static let assetKey = "asset"

    // MARK: - Managed Properties

    /// The underlying storage of `data`.

    @NSManaged private var primitiveData: Data

    /// The serialized Protobuf data.

    private var data: Data? {
        get {
            willAccessValue(forKey: Self.dataKey)
            let d = primitiveData
            didAccessValue(forKey: Self.dataKey)

            do {
                return try decryptDataIfNeeded(data: d)
            } catch {
                Self.log.warn("Could not decrypt message data: \(error.localizedDescription)")
            }

            return nil
        }

        set {
            guard
                let newData = newValue,
                let moc = managedObjectContext
            else {
                return
            }

            do {
                let (data, nonce) = try encryptDataIfNeeded(data: newData, in: moc)
                willChangeValue(forKey: Self.dataKey)
                primitiveData = data
                didChangeValue(forKey: Self.dataKey)
                self.nonce = nonce
            } catch {
                Self.log.warn("Could not encrypt message data: \(error.localizedDescription)")
            }
        }
    }

    /// The nonce used to encrypt `data`, if applicable.

    @NSManaged public private(set) var nonce: Data?

    /// The client message containing this generic message data.

    @NSManaged public var message: ZMClientMessage?

    /// The asset client message containing this generic message data.

    @NSManaged public var asset: ZMAssetClientMessage?

    // MARK: - Properties

    /// The deserialized Protobuf object.

    public var underlyingMessage: GenericMessage? {
        guard let data = data else { return nil }
        return try? GenericMessage(serializedData: data)
    }

    /// Whether the Protobuf data is encrypted in the database.

    public var isEncrypted: Bool {
        return nonce != nil
    }

    public override var modifiedKeys: Set<AnyHashable>? {
        get { return Set() }
        set { /* do nothing */ }
    }

    // MARK: - Methods

    /// Set the protobuf data.
    ///
    /// - Parameter data: Serialized data representing a protobuf object.

    public func setProtobuf(_ data: Data) {
        self.data = data
    }

    private func decryptDataIfNeeded(data: Data) throws -> Data {
        guard let nonce = nonce else { return data }
        guard let key = managedObjectContext?.databaseKey else { throw EncryptionError.missingDatabaseKey }
        return try AES256GCMEncryption.decrypt(ciphertext: data, nonce: nonce, context: Data(), key: key)
    }

    private func encryptDataIfNeeded(data: Data, in moc: NSManagedObjectContext) throws -> (data: Data, nonce: Data?) {
        guard moc.encryptMessagesAtRest else { return (data, nonce: nil) }
        guard let key = moc.databaseKey else { throw EncryptionError.missingDatabaseKey }
        let (ciphertext, nonce) = try AES256GCMEncryption.encrypt(message: data, context: Data(), key: key)
        return (ciphertext, nonce)
    }

}

// MARK: - Encryption Error

private extension ZMGenericMessageData {

    enum EncryptionError: LocalizedError {

        case missingDatabaseKey

        var errorDescription: String? {
            switch self {
            case .missingDatabaseKey:
                return "Database key not found. Perhaps the database is locked."
            }
        }

    }

}
