//
//  GenericMessage+External.swift
//  WireDataModel
//
//  Created by David Henner on 16.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

private let zmLog = ZMSLog(tag: "GenericMessage")

extension GenericMessage {
    static func encryptedDataWithKeys(from message: GenericMessage) -> ZMExternalEncryptedDataWithKeys? {
        guard
            let aesKey = NSData.randomEncryptionKey(),
            let messageData = try? message.serializedData()
            else {
                return nil
        }
        let encryptedData = messageData.zmEncryptPrefixingPlainTextIV(key: aesKey)
        let keys = ZMEncryptionKeyWithChecksum.key(withAES: aesKey, digest: encryptedData.zmSHA256Digest())
        return ZMExternalEncryptedDataWithKeys(data: encryptedData, keys: keys)
    }
    
    init?(from updateEvent: ZMUpdateEvent, withExternal external: External) {
        guard let externalDataString = updateEvent.payload.optionalString(forKey: "external") else { return nil }
        let externalData = Data(base64Encoded: externalDataString)
        let externalSha256 = externalData?.zmSHA256Digest()
        
        guard externalSha256 == external.sha256 else {
            zmLog.error("Invalid hash for external data: \(externalSha256 ?? Data()) != \(external.sha256), updateEvent: \(updateEvent)")
            return nil
        }
        
        let decryptedData = externalData?.zmDecryptPrefixedPlainTextIV(key: external.otrKey)
        guard let message = GenericMessage(withBase64String: decryptedData?.base64String()) else {
            return nil
        }
        self = message
    }
}
