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

@objcMembers public class ZMClientMessage: ZMOTRMessage {

    @objc public static let linkPreviewStateKey = "linkPreviewState"
    
    /// Link Preview state
    @NSManaged public var updatedTimestamp: Date?
    
    /// In memory cache
    var cachedGenericMessage: ZMGenericMessage? = nil
    var cachedUnderlyingMessage: GenericMessage? = nil
    
    public override static func entityName() -> String {
        return "ClientMessage"
    }

    open override var ignoredKeys: Set<AnyHashable>? {
        return (super.ignoredKeys ?? Set())
            .union([#keyPath(updatedTimestamp)])
    }
    
    public override var updatedAt : Date? {
        return updatedTimestamp
    }

    public override var hashOfContent: Data? {
        guard let serverTimestamp = serverTimestamp else { return nil }

        return genericMessage?.hashOfContent(with: serverTimestamp)
    }

    public override func awakeFromFetch() {
        super.awakeFromFetch()
        self.cachedGenericMessage = nil
        self.cachedUnderlyingMessage = nil
    }
    
    public override func awake(fromSnapshotEvents flags: NSSnapshotEventType) {
        super.awake(fromSnapshotEvents: flags)
        self.cachedGenericMessage = nil
        self.cachedUnderlyingMessage = nil
    }
    
    public override func didTurnIntoFault() {
        super.didTurnIntoFault()
        self.cachedGenericMessage = nil
        self.cachedUnderlyingMessage = nil
    }
    
    public static func keyPathsForValuesAffectingGenericMessage() -> Set<String> {
        return Set([#keyPath(ZMClientMessage.dataSet),
                    #keyPath(ZMClientMessage.dataSet) + ".data"])
    }

    public override func expire() {
        if let genericMessage = self.genericMessage, genericMessage.hasEdited() {
            // Replace the nonce with the original
            // This way if we get a delete from a different device while we are waiting for the response it will delete this message
            let originalID = self.genericMessage.flatMap { UUID(uuidString: $0.edited.replacingMessageId) }
            self.nonce = originalID
        }
        super.expire()
    }

    public override func resend() {
        if let genericMessage = self.genericMessage, genericMessage.hasEdited() {
            // Re-apply the edit since we've restored the orignal nonce when the message expired
            editText(self.textMessageData?.messageText ?? "", mentions: self.textMessageData?.mentions ?? [], fetchLinkPreview: true)
        }
        super.resend()
    }
    
    public override func update(withPostPayload payload: [AnyHashable : Any], updatedKeys: Set<AnyHashable>?) {
        // we don't want to update the conversation if the message is a confirmation message
        guard let genericMessage = self.genericMessage else { return }
        if genericMessage.hasConfirmation() || genericMessage.hasReaction() {
            return
        }

        if genericMessage.hasDeleted() {
            let originalID = UUID(uuidString: genericMessage.deleted.messageId)
            guard let managedObjectContext = managedObjectContext,
                let conversation = conversation else { return }

            let original = ZMMessage.fetch(withNonce: originalID, for: conversation, in: managedObjectContext)
            original?.sender = nil
            original?.senderClientID = nil
        } else if genericMessage.hasEdited() {
            if let nonce = self.nonce(fromPostPayload: payload),
                self.nonce != nonce {
                ZMSLog(tag: "send message response nonce does not match")
                return
            }

            if let serverTimestamp = (payload as NSDictionary).optionalDate(forKey: "time") {
                self.updatedTimestamp = serverTimestamp
            }
        } else {
            super.update(withPostPayload: payload, updatedKeys: nil)
        }
    }

    override static public func predicateForObjectsThatNeedToBeInsertedUpstream() -> NSPredicate? {
        let encryptedNotSynced = NSPredicate(format: "%K == FALSE", DeliveredKey)
        let notExpired = NSPredicate(format: "%K == 0", ZMMessageIsExpiredKey)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [encryptedNotSynced, notExpired])
    }
    
    public override func markAsSent() {
        super.markAsSent()
        if linkPreviewState == ZMLinkPreviewState.uploaded {
            linkPreviewState = ZMLinkPreviewState.done
        }
        setObfuscationTimerIfNeeded()
    }

    private func setObfuscationTimerIfNeeded() {
        guard self.isEphemeral else {
            return
        }
        if let genericMessage = self.genericMessage,
            let _ = genericMessage.textData,
            !genericMessage.linkPreviews.isEmpty,
            linkPreviewState != ZMLinkPreviewState.done {
            // If we have link previews and they are not sent yet, we wait until they are sent
            return
        }
        startDestructionIfNeeded()
    }

    func hasDownloadedImage() -> Bool {
        if let textMessageData = self.textMessageData,
            let _ = textMessageData.linkPreview,
            let managedObjectContext = self.managedObjectContext {
            return managedObjectContext.zm_fileAssetCache.hasDataOnDisk(self, format: ZMImageFormat.medium, encrypted: false)
                // processed or downloaded
                || managedObjectContext.zm_fileAssetCache.hasDataOnDisk(self, format: ZMImageFormat.original, encrypted: false)
            // original
        }
        return false
    }
}
