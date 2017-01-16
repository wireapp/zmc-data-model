//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import ZMCDataModel

class MessageObserverTests : NotificationDispatcherTests {
    
    class TestMessageObserver : NSObject, ZMMessageObserver {
        var receivedChangeInfo : [MessageChangeInfo] = []
        
        func messageDidChange(_ changes: MessageChangeInfo) {
            receivedChangeInfo.append(changes)
        }
    }
    
    var messageObserver : TestMessageObserver!
    
    override func setUp() {
        super.setUp()
        messageObserver = TestMessageObserver()
    }

    override func tearDown() {
        messageObserver = nil
        super.tearDown()
    }
    
    func checkThatItNotifiesTheObserverOfAChange(_ message : ZMMessage, modifier: (ZMMessage) -> Void, expectedChangedField : String?, customAffectedKeys: AffectedKeys? = nil) {
        
        // given
        let token = MessageChangeInfo.add(observer: messageObserver, for: message)
        
        self.uiMOC.saveOrRollback()
        
        // when
        modifier(message)
        self.uiMOC.saveOrRollback()
        self.spinMainQueue(withTimeout: 0.5)
        
        // then
        if expectedChangedField != nil {
            XCTAssertEqual(messageObserver.receivedChangeInfo.count, 1)
        } else {
            XCTAssertEqual(messageObserver.receivedChangeInfo.count, 0)
        }
        
        // and when
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertTrue(messageObserver.receivedChangeInfo.count <= 1, "Should have changed only once")
        
        let messageInfoKeys = [
            "imageChanged",
            "deliveryStateChanged",
            "senderChanged",
            "linkPreviewChanged",
            "isObfuscatedChanged"
        ]
        
        if let changedField = expectedChangedField {
            if let changes = messageObserver.receivedChangeInfo.first {
                for key in messageInfoKeys {
                    if let value = changes.value(forKey: key) as? NSNumber {
                        if key == changedField {
                            XCTAssertTrue(value.boolValue, "\(key) was supposed to be true")
                        } else {
                            XCTAssertFalse(value.boolValue, "\(key) was supposed to be false")
                        }
                    }
                    else {
                        XCTFail("Can't find key or key is not boolean for '\(key)'")
                    }
                }
            }
        }
        MessageChangeInfo.remove(observer: token, for: message)
    }
    
    func testThatItNotifiesObserverWhenTheSenderNameChanges() {
        // given
        let sender = ZMUser.insertNewObject(in:self.uiMOC)
        sender.name = "Hans"

        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.mutableOtherActiveParticipants.add(sender)
        
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        message.sender = sender
        uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
                                                     modifier: { $0.sender!.name = "Horst"},
                                                     expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheFileTransferStateChanges() {
        // given
        let message = ZMAssetClientMessage.insertNewObject(in: self.uiMOC)
        message.transferState = .uploading
        uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
                                                     modifier: {
                                                        if let msg = $0 as? ZMAssetClientMessage {
                                                            msg.transferState = .uploaded
                                                        }
            },
                                                     expectedChangedField: ZMAssetClientMessageTransferStateKey
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderNameChangesBecauseOfAnotherUserWithTheSameName() {
        // given
        let sender = ZMUser.insertNewObject(in:self.uiMOC)
        sender.name = "Hans A"
        
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.mutableOtherActiveParticipants.add(sender)
        
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        message.sender = sender
        
        self.uiMOC.saveOrRollback()
        updateDisplayNameGenerator(withUsers: [sender])
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
                                                     modifier: { _ in
                                                        let newUser = ZMUser.insertNewObject(in:self.uiMOC)
                                                        newUser.name = "Hans K"
            },
                                                     expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderAccentColorChanges() {
        // given
        let sender = ZMUser.insertNewObject(in:self.uiMOC)
        sender.accentColorValue = ZMAccentColor.brightOrange
        
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.mutableOtherActiveParticipants.add(sender)
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        message.sender = sender
        uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
                                                     modifier: { $0.sender!.accentColorValue = ZMAccentColor.softPink },
                                                     expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderSmallProfileImageChanges() {
        // given
        let sender = ZMUser.insertNewObject(in:self.uiMOC)
        sender.remoteIdentifier = UUID.create()
        sender.mediumRemoteIdentifier = UUID.create()
        
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.mutableOtherActiveParticipants.add(sender)
        
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        message.sender = sender
        uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
                                                     modifier: { $0.sender!.imageMediumData = self.verySmallJPEGData()},
                                                     expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderMediumProfileImageChanges() {
        // given
        let sender = ZMUser.insertNewObject(in:self.uiMOC)
        sender.remoteIdentifier = UUID.create()

        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.mutableOtherActiveParticipants.add(sender)
        
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        message.sender = sender
        sender.smallProfileRemoteIdentifier = UUID.create()
        uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
                                                     modifier: { $0.sender!.imageSmallProfileData = self.verySmallJPEGData()},
                                                     expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheMediumImageDataChanges() {
        // given
        let message = ZMAssetClientMessage.insertNewObject(in: self.uiMOC)
        uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
                                                     modifier: { message in
                                                        let imageData = verySmallJPEGData()
                                                        let imageSize = ZMImagePreprocessor.sizeOfPrerotatedImage(with: imageData)
                                                        let properties = ZMIImageProperties(size:imageSize, length:UInt(imageData.count), mimeType:"image/jpeg")
                                                        let keys = ZMImageAssetEncryptionKeys(otrKey: Data.randomEncryptionKey(),
                                                                                              macKey: Data.zmRandomSHA256Key(),
                                                                                              mac: Data.zmRandomSHA256Key())
                                                        
                                                        let imageMessage = ZMGenericMessage.genericMessage(mediumImageProperties: properties,
                                                                                                           processedImageProperties: properties,
                                                                                                           encryptionKeys: keys,
                                                                                                           nonce: UUID.create().transportString(),
                                                                                                           format: .preview)
                                                        (message as? ZMAssetClientMessage)?.add(imageMessage)
            },
                                                     expectedChangedField: "imageChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheLinkPreviewStateChanges() {
        // when
        checkThatItNotifiesTheObserverOfAChange(
            ZMClientMessage.insertNewObject(in: uiMOC),
            modifier: { ($0 as? ZMClientMessage)?.linkPreviewState = .downloaded },
            expectedChangedField: "linkPreviewChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheLinkPreviewStateChanges_NewGenericMessageData() {
        // given
        let clientMessage = ZMClientMessage.insertNewObject(in: uiMOC)
        let nonce = UUID.create()
        clientMessage.add(ZMGenericMessage.message(text: name!, nonce: nonce.transportString()).data())
        let preview = ZMLinkPreview.linkPreview(
            withOriginalURL: "www.example.com",
            permanentURL: "www.example.com/permanent",
            offset: 42,
            title: "title",
            summary: "summary",
            imageAsset: nil
        )
        let updateGenericMessage = ZMGenericMessage.message(text: name!, linkPreview: preview, nonce: nonce.transportString())
        uiMOC.saveOrRollback()
        
        // when
        checkThatItNotifiesTheObserverOfAChange(
            clientMessage,
            modifier: { ($0 as? ZMClientMessage)?.add(updateGenericMessage.data()) },
            expectedChangedField: "linkPreviewChanged"
        )
    }
    
    func testThatItDoesNotNotifiyObserversWhenTheSmallImageDataChanges() {
        // given
        let message = ZMImageMessage.insertNewObject(in: self.uiMOC)
        uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
                                                     modifier: { message in
                                                        if let imageMessage = message as? ZMImageMessage {
                                                            imageMessage.previewData = self.verySmallJPEGData()}
            },
                                                     expectedChangedField: nil
        )
    }
    
    func testThatItNotifiesWhenAReactionIsAddedOnMessage() {
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage
        uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(
            message,
            modifier: { $0.addReaction("LOVE IT, HUH", forUser: ZMUser.selfUser(in: self.uiMOC))},
            expectedChangedField: "reactionsChanged"
        )
    }
    
    func testThatItNotifiesWhenAReactionIsAddedOnMessageFromADifferentUser() {
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage

        let otherUser = ZMUser.insertNewObject(in:uiMOC)
        otherUser.name = "Hans"
        otherUser.remoteIdentifier = .create()
        uiMOC.saveOrRollback()

        // when
        checkThatItNotifiesTheObserverOfAChange(
            message,
            modifier: { $0.addReaction("👻", forUser: otherUser) },
            expectedChangedField: "reactionsChanged"
        )
    }
    
    func testThatItNotifiesWhenAReactionIsUpdateForAUserOnMessage() {
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage

        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        message.addReaction("LOVE IT, HUH", forUser: selfUser)
        uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(
            message,
            modifier: {$0.addReaction(nil, forUser: selfUser)},
            expectedChangedField: "reactionsChanged"
        )
    }
    
    func testThatItNotifiesWhenAReactionFromADifferentUserIsAddedOnTopOfSelfReaction() {
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let message = conversation.appendMessage(withText: "foo") as! ZMClientMessage

        let otherUser = ZMUser.insertNewObject(in:uiMOC)
        otherUser.name = "Hans"
        otherUser.remoteIdentifier = .create()
        
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        message.addReaction("👻", forUser: selfUser)
        uiMOC.saveOrRollback()

        // when
        checkThatItNotifiesTheObserverOfAChange(
            message,
            modifier: { $0.addReaction("👻", forUser: otherUser) },
            expectedChangedField: "reactionsChanged"
        )
    }
    
    
    
    func testThatItStopsNotifyingAfterUnregisteringTheToken() {
        
        // given
        let message = ZMClientMessage.insertNewObject(in: self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        let token = MessageChangeInfo.add(observer: messageObserver, for: message)
        MessageChangeInfo.remove(observer: token, for: message)
        
        // when
        message.serverTimestamp = Date()
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(messageObserver.receivedChangeInfo.count, 0)
    }
}
