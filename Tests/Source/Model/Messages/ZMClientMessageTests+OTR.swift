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


import XCTest
@testable import WireDataModel

class ClientMessageTests_OTR: BaseZMClientMessageTests {
}

// MARK: - Payload creation
extension ClientMessageTests_OTR {

    func testThatItCategorizesUsersCorrectly() {
        self.syncMOC.performGroupedBlockAndWait {
            let regularUser1 = ZMUser.insertNewObject(in: self.syncMOC)
            regularUser1.remoteIdentifier = UUID.create()

            let regularUser2 = ZMUser.insertNewObject(in: self.syncMOC)
            regularUser2.remoteIdentifier = UUID.create()

            let serviceUser1 = ZMUser.insertNewObject(in: self.syncMOC)
            serviceUser1.serviceIdentifier = UUID.create().transportString()
            serviceUser1.providerIdentifier = UUID.create().transportString()

            let serviceUser2 = ZMUser.insertNewObject(in: self.syncMOC)
            serviceUser2.serviceIdentifier = UUID.create().transportString()
            serviceUser2.providerIdentifier = UUID.create().transportString()

            let nonce = UUID.create()
            let builder = ZMGenericMessage.builder()!
            let textBuilder = ZMText.builder()!
            textBuilder.setContent(self.textMessageRequiringExternalMessage(2))
            builder.setText(textBuilder.build()!)
            builder.setMessageId(nonce.transportString())
            let textMessage = builder.build()!

            let users: Set<ZMUser> = [regularUser1, regularUser2, serviceUser1, serviceUser2]
            let (services, regularUsers) = textMessage.categorizeUsers(users)

            XCTAssertEqual(regularUsers.count, 2)
            XCTAssertEqual(services.count, 2)

            XCTAssertEqual(Set(regularUsers), [regularUser1, regularUser2])
            XCTAssertEqual(Set(services), [serviceUser1, serviceUser2])
        }
    }

    func testThatItCreatesCorrectMentionForUser() {
        self.syncMOC.performGroupedBlockAndWait {
            let regularUser = ZMUser.insertNewObject(in: self.syncMOC)
            regularUser.remoteIdentifier = UUID.create()
            regularUser.name = "Jane Doe"
            let regularMentionBuilder = ZMMention.builder()!
            regularMentionBuilder.setUser(regularUser)
            let regularMention = regularMentionBuilder.build()!
            XCTAssertEqual(regularMention.userId, regularUser.remoteIdentifier?.transportString())
            XCTAssertEqual(regularMention.userName, "Jane Doe")

            let serviceUser = ZMUser.insertNewObject(in: self.syncMOC)
            serviceUser.serviceIdentifier = UUID.create().transportString()
            serviceUser.providerIdentifier = UUID.create().transportString()
            serviceUser.name = "Wire News"
            let serviceMentionBuilder = ZMMention.builder()!
            serviceMentionBuilder.setUser(serviceUser)
            let serviceMention = serviceMentionBuilder.build()!
            let expectedServiceID = "/\(serviceUser.providerIdentifier!)/\(serviceUser.serviceIdentifier!)"
            XCTAssertEqual(serviceMention.userId, expectedServiceID)
            XCTAssertEqual(serviceMention.userName, "Wire News")
        }
    }

    func testThatItExcludesServicesWhenNotMentioned() {
        self.syncMOC.performGroupedBlockAndWait {
            let regularUser1 = ZMUser.insertNewObject(in: self.syncMOC)
            regularUser1.remoteIdentifier = UUID.create()

            let regularUser2 = ZMUser.insertNewObject(in: self.syncMOC)
            regularUser2.remoteIdentifier = UUID.create()

            let serviceUser1 = ZMUser.insertNewObject(in: self.syncMOC)
            serviceUser1.serviceIdentifier = UUID.create().transportString()
            serviceUser1.providerIdentifier = UUID.create().transportString()

            let serviceUser2 = ZMUser.insertNewObject(in: self.syncMOC)
            serviceUser2.name = "Wire News"
            serviceUser2.serviceIdentifier = UUID.create().transportString()
            serviceUser2.providerIdentifier = UUID.create().transportString()

            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            let remoteUsers = [regularUser1, regularUser2, serviceUser1, serviceUser2]

            let nonce = UUID.create()
            let builder = ZMGenericMessage.builder()!
            let mentionBuilder = ZMMention.builder()!
            mentionBuilder.setUser(serviceUser2)
            let textBuilder = ZMText.builder()!
            textBuilder.setContent(self.textMessageRequiringExternalMessage(2))
            textBuilder.addMention(mentionBuilder.build()!)
            builder.setText(textBuilder.build()!)
            builder.setMessageId(nonce.transportString())
            let textMessage = builder.build()!

            let conversation = ZMConversation.insertNewObject(in:self.syncMOC)
            conversation.conversationType = .group
            conversation.remoteIdentifier = UUID.create()
            conversation.addParticipants(Set(remoteUsers))
            XCTAssertTrue(self.syncMOC.saveOrRollback())

            // when
            let mentionedServices = textMessage.mentionedServices(within: remoteUsers)

            guard let (_, strategy) = textMessage.encryptedMessagePayloadData(conversation, externalData: nil)
                else { return XCTFail() }

            // then

            XCTAssertEqual(mentionedServices.count, 1)
            XCTAssertFalse(mentionedServices.contains(serviceUser1))
            XCTAssertTrue(mentionedServices.contains(serviceUser2))

            switch strategy {
            case .ignoreAllMissingClientsNotFromUsers(let users):
                XCTAssertEqual(users, Set([regularUser1, regularUser2, serviceUser2, selfUser]))
            default:
                XCTFail()
            }


        }
    }

    func testThatItExcludesUnmentionedServicesForTextMessage() {
        self.syncMOC.performGroupedBlockAndWait {
            let otherUser = ZMUser.insertNewObject(in:self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            let firstClient = self.createClient(for: otherUser, createSessionWithSelfUser: true, onMOC: self.syncMOC)
            let secondClient = self.createClient(for: otherUser, createSessionWithSelfUser: true, onMOC: self.syncMOC)
            let selfClients = ZMUser.selfUser(in: self.syncMOC).clients!
            let selfClient = ZMUser.selfUser(in: self.syncMOC).selfClient()
            let notSelfClients = selfClients.filter { $0 != selfClient }

            let nonce = UUID.create()
            let builder = ZMGenericMessage.builder()!
            let textBuilder = ZMText.builder()!
            textBuilder.setContent(self.textMessageRequiringExternalMessage(2))
            builder.setText(textBuilder.build()!)
            builder.setMessageId(nonce.transportString())
            let textMessage = builder.build()!

            let conversation = ZMConversation.insertNewObject(in:self.syncMOC)
            conversation.conversationType = .group
            conversation.remoteIdentifier = UUID.create()
            conversation.addParticipant(otherUser)
            XCTAssertTrue(self.syncMOC.saveOrRollback())

            // when
            guard let dataAndStrategy = textMessage.encryptedMessagePayloadData(conversation, externalData: nil)
                else { return XCTFail() }

            // then
            guard let createdMessage = ZMNewOtrMessage.builder()!.merge(from: dataAndStrategy.data).build()! as? ZMNewOtrMessage
                else { return XCTFail() }

            XCTAssertEqual(createdMessage.hasBlob(), true)
            let clientIds = createdMessage.recipients.flatMap { userEntry -> [ZMClientId] in
                return (userEntry.clients).map { clientEntry -> ZMClientId in
                    return clientEntry.client
                }
            }
            let clientSet = Set(clientIds)
            XCTAssertEqual(clientSet.count, 2 + notSelfClients.count)
            XCTAssertTrue(clientSet.contains(firstClient.clientId))
            XCTAssertTrue(clientSet.contains(secondClient.clientId))
            notSelfClients.forEach{
                XCTAssertTrue(clientSet.contains($0.clientId))
            }
        }
    }


    func testThatCreatesEncryptedDataAndAddsItToGenericMessageAsBlob() {
        self.syncMOC.performGroupedBlockAndWait { 
            let otherUser = ZMUser.insertNewObject(in:self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            let firstClient = self.createClient(for: otherUser, createSessionWithSelfUser: true, onMOC: self.syncMOC)
            let secondClient = self.createClient(for: otherUser, createSessionWithSelfUser: true, onMOC: self.syncMOC)
            let selfClients = ZMUser.selfUser(in: self.syncMOC).clients!
            let selfClient = ZMUser.selfUser(in: self.syncMOC).selfClient()
            let notSelfClients = selfClients.filter { $0 != selfClient }
            
            let nonce = UUID.create()
            let builder = ZMGenericMessage.builder()!
            let textBuilder = ZMText.builder()!
            textBuilder.setContent(self.textMessageRequiringExternalMessage(2))
            builder.setText(textBuilder.build()!)
            builder.setMessageId(nonce.transportString())
            let textMessage = builder.build()!
            
            let conversation = ZMConversation.insertNewObject(in:self.syncMOC)
            conversation.conversationType = .group
            conversation.remoteIdentifier = UUID.create()
            conversation.addParticipant(otherUser)
            XCTAssertTrue(self.syncMOC.saveOrRollback())
            
            // when
            guard let dataAndStrategy = textMessage.encryptedMessagePayloadData(conversation, externalData: nil)
            else { return XCTFail() }
            
            // then
            guard let createdMessage = ZMNewOtrMessage.builder()!.merge(from: dataAndStrategy.data).build()! as? ZMNewOtrMessage
            else { return XCTFail() }
            
            XCTAssertEqual(createdMessage.hasBlob(), true)
            let clientIds = createdMessage.recipients.flatMap { userEntry -> [ZMClientId] in
                return (userEntry.clients).map { clientEntry -> ZMClientId in
                    return clientEntry.client
                }
            }
            let clientSet = Set(clientIds)
            XCTAssertEqual(clientSet.count, 2 + notSelfClients.count)
            XCTAssertTrue(clientSet.contains(firstClient.clientId))
            XCTAssertTrue(clientSet.contains(secondClient.clientId))
            notSelfClients.forEach{
                XCTAssertTrue(clientSet.contains($0.clientId))
            }
        }
    }
    
    func testThatItCreatesPayloadDataForTextMessage() {
        self.syncMOC.performGroupedBlockAndWait {
            
            //given
            let message = self.syncConversation.appendOTRMessage(withText: self.name!, nonce: UUID.create(), fetchLinkPreview: true)
            
            //when
            guard let payloadAndStrategy = message?.encryptedMessagePayloadData() else {
                XCTFail()
                return
            }
            
            //then
            self.assertMessageMetadata(payloadAndStrategy.data)
            switch payloadAndStrategy.strategy {
            case .doNotIgnoreAnyMissingClient:
                break
            default:
                XCTFail()
            }
        }
    }
    
    func testThatItCreatesPayloadDataForEphemeralTextMessage_Group() {
        self.syncMOC.performGroupedBlockAndWait {
            
            //given
            self.syncConversation.messageDestructionTimeout = 10
            guard let message = self.syncConversation.appendOTRMessage(withText: self.name!, nonce: UUID.create(), fetchLinkPreview: true) else { XCTFail(); return }
            XCTAssertTrue(message.isEphemeral)
            
            //when
            guard let payloadAndStrategy = message.encryptedMessagePayloadData() else { return XCTFail() }
            
            //then
            switch payloadAndStrategy.strategy {
            case .ignoreAllMissingClientsNotFromUsers(users: let users):
                XCTAssertEqual(users, self.syncConversation.otherActiveParticipants.set as! Set<ZMUser>)
            default:
                XCTFail()
            }
        }
    }
    
    func testThatItCreatesPayloadDataForDeletionOfEphemeralTextMessage_Group() {
        
        var syncMessage: ZMClientMessage!
        self.syncMOC.performGroupedBlockAndWait {
            //given
            self.syncConversation.messageDestructionTimeout = 10
            syncMessage = self.syncConversation.appendOTRMessage(withText: self.name!, nonce: UUID.create(), fetchLinkPreview: true)
            syncMessage.sender = self.syncUser1
            XCTAssertTrue(syncMessage.isEphemeral)
            self.syncMOC.saveOrRollback()
        }
        
        let uiMessage = self.uiMOC.object(with: syncMessage.objectID) as! ZMMessage
        uiMessage.startDestructionIfNeeded()
        XCTAssertNotNil(uiMessage.destructionDate)
        self.uiMOC.zm_teardownMessageDeletionTimer()
        self.uiMOC.saveOrRollback()

        self.syncMOC.performGroupedBlockAndWait {
            self.syncMOC.refresh(syncMessage, mergeChanges: true)
            XCTAssertNotNil(syncMessage.destructionDate)

            let sut = syncMessage.deleteForEveryone()

            // when
            guard let payloadAndStrategy = sut?.encryptedMessagePayloadData() else { return XCTFail() }
            
            //then
            switch payloadAndStrategy.strategy {
            case .ignoreAllMissingClientsNotFromUsers(users: let users):
                XCTAssertEqual(users, Set(arrayLiteral: self.syncSelfUser, self.syncUser1))
            default:
                XCTFail()
            }
        }
    }
    
    func testThatItCreatesPayloadForDeletionOfEphemeralTextMessage_Group_SenderWasDeleted() {
        // This can happen due to a race condition where we receive a delete for an ephemeral after deleting the same message locally, but before creating the payload
        var syncMessage: ZMClientMessage!
        self.syncMOC.performGroupedBlockAndWait {
            //given
            self.syncConversation.messageDestructionTimeout = 10
            syncMessage = self.syncConversation.appendOTRMessage(withText: self.name!, nonce: UUID.create(), fetchLinkPreview: true)
            syncMessage.sender = self.syncUser1
            XCTAssertTrue(syncMessage.isEphemeral)
            self.syncMOC.saveOrRollback()
        }
        
        let uiMessage = self.uiMOC.object(with: syncMessage.objectID) as! ZMMessage
        uiMessage.startDestructionIfNeeded()
        XCTAssertNotNil(uiMessage.destructionDate)
        self.uiMOC.zm_teardownMessageDeletionTimer()
        self.uiMOC.saveOrRollback()
        
        self.syncMOC.performGroupedBlockAndWait {
            self.syncMOC.refresh(syncMessage, mergeChanges: true)
            XCTAssertNotNil(syncMessage.destructionDate)
            
            let sut = syncMessage.deleteForEveryone()
            
            // when
            syncMessage.sender = nil
            var payload : (data: Data, strategy: MissingClientsStrategy)?
            self.performIgnoringZMLogError {
                 payload = sut?.encryptedMessagePayloadData()
            }
            
            //then
            guard let payloadAndStrategy = payload else { return XCTFail() }
            switch payloadAndStrategy.strategy {
            case .ignoreAllMissingClientsNotFromUsers(users: let users):
                XCTAssertEqual(users, Set(arrayLiteral: self.syncSelfUser))
            default:
                XCTFail()
            }
        }
    }
    
    
    func testThatItCreatesPayloadForZMLastReadMessages() {
        self.syncMOC.performGroupedBlockAndWait {
            // given
            self.syncConversation.lastReadServerTimeStamp = Date()
            self.syncConversation.remoteIdentifier = UUID()
            guard let message = ZMConversation.appendSelfConversation(withLastReadOf: self.syncConversation) else { return XCTFail() }
            
            self.expectedRecipients = [self.syncSelfUser.remoteIdentifier!.transportString(): [self.syncSelfClient2.remoteIdentifier!]]
            
            // when
            guard let payloadAndStrategy = message.encryptedMessagePayloadData() else { return XCTFail() }
            
            // then
            self.assertMessageMetadata(payloadAndStrategy.data)
            switch payloadAndStrategy.strategy {
            case .doNotIgnoreAnyMissingClient:
                break
            default:
                XCTFail()
            }
        }
    }

    func testThatItCreatesPayloadForZMClearedMessages() {
        self.syncMOC.performGroupedBlockAndWait {
            // given
            self.syncConversation.clearedTimeStamp = Date()
            self.syncConversation.remoteIdentifier = UUID()
            guard let message = ZMConversation.appendSelfConversation(withClearedOf: self.syncConversation) else { return XCTFail() }
            
            self.expectedRecipients = [self.syncSelfUser.remoteIdentifier!.transportString(): [self.syncSelfClient2.remoteIdentifier!]]
            
            // when
            guard let payloadAndStrategy = message.encryptedMessagePayloadData() else { return XCTFail() }
            
            // then
            self.assertMessageMetadata(payloadAndStrategy.data)
            switch payloadAndStrategy.strategy {
            case .doNotIgnoreAnyMissingClient:
                break
            default:
                XCTFail()
            }
        }
    }
    
    func testThatItCreatesPayloadForExternalMessage() {
        
        syncMOC.performGroupedBlockAndWait {
            // given
            let message = self.syncConversation.appendOTRMessage(withText: self.name!, nonce: UUID.create(), fetchLinkPreview: true)
            
            //when
            // when
            guard let payloadAndStrategy = message?.encryptedMessagePayloadData() else {
                XCTFail()
                return
            }
            
            // then
            self.assertMessageMetadata(payloadAndStrategy.data)
            switch payloadAndStrategy.strategy {
            case .doNotIgnoreAnyMissingClient:
                break
            default:
                XCTFail()
            }
        }
    }
}

// MARK: - Delivery
extension ClientMessageTests_OTR {
    
    func testThatItCreatesPayloadDataForConfirmationMessage() {
        self.syncMOC.performGroupedBlockAndWait {
            
            //given
            let senderID = self.syncUser1.clients.first!.remoteIdentifier
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .oneOnOne
            conversation.remoteIdentifier = UUID.create()
            
            let connection = ZMConnection.insertNewObject(in: self.syncMOC)
            connection.to = self.syncUser1
            connection.status = .accepted
            conversation.connection = connection
            conversation.mutableOtherActiveParticipants.add(self.syncUser1)
            
            self.syncMOC.saveOrRollback()
                        
            let textMessage = conversation.appendOTRMessage(withText: self.stringLargeEnoughToRequireExternal, nonce: UUID.create(), fetchLinkPreview: true)
            
            textMessage?.sender = self.syncUser1
            textMessage?.senderClientID = senderID
            let confirmationMessage = textMessage?.confirmReception()
            
            //when
            guard let payloadAndStrategy = confirmationMessage?.encryptedMessagePayloadData()
            else { return XCTFail()}
            
            //then
            switch payloadAndStrategy.strategy {
            case .ignoreAllMissingClientsNotFromUsers(let users):
                XCTAssertEqual(users, Set(arrayLiteral: self.syncUser1))
            default:
                XCTFail()
            }
            guard let messageMetadata = ZMNewOtrMessageBuilder().merge(from: payloadAndStrategy.data).build()! as? ZMNewOtrMessage else {
                XCTFail()
                return
            }
            
            if let recipients = messageMetadata.recipients {
                let payloadClients = recipients.flatMap { user -> [String] in
                    return user.clients?.map({ String(format: "%llx", $0.client.client) }) ?? []
                }.flatMap { $0 }
                XCTAssertEqual(payloadClients.sorted(), self.syncUser1.clients.map { $0.remoteIdentifier! }.sorted())
            } else {
                XCTFail("Metadata does not contain recipients")
            }
        }
    }
    
    func testThatItCreatesPayloadForConfimationMessageWhenOriginalHasSender() {
        syncMOC.performGroupedBlockAndWait {
            //given
            let senderID = self.syncUser1.clients.first!.remoteIdentifier
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .oneOnOne
            conversation.remoteIdentifier = UUID.create()
            
            let connection = ZMConnection.insertNewObject(in: self.syncMOC)
            connection.to = self.syncUser1
            connection.status = .accepted
            conversation.connection = connection
            conversation.mutableOtherActiveParticipants.add(self.syncUser1)
            
            self.syncMOC.saveOrRollback()
            
            let textMessage = conversation.appendOTRMessage(withText: self.stringLargeEnoughToRequireExternal, nonce: UUID.create(), fetchLinkPreview: true)
            
            textMessage?.sender = self.syncUser1
            textMessage?.senderClientID = senderID
            let confirmationMessage = textMessage?.confirmReception()
            
            //when
            guard let _ = confirmationMessage?.encryptedMessagePayloadData()
                else { return XCTFail()}
        }
    }

    func testThatItCreatesPayloadForConfimationMessageWhenOriginalHasNoSenderButInferSenderWithConnection() {
        syncMOC.performGroupedBlockAndWait {
            //given
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .oneOnOne
            conversation.remoteIdentifier = UUID.create()
            
            let connection = ZMConnection.insertNewObject(in: self.syncMOC)
            connection.to = self.syncUser1
            connection.status = .accepted
            conversation.connection = connection
            
            let genericMessage = ZMGenericMessage.message(text: "yo", nonce: UUID().transportString())
            let clientmessage = ZMClientMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            clientmessage.add(genericMessage.data())
            clientmessage.visibleInConversation = conversation
            
            self.syncMOC.saveOrRollback()
            
            let confirmationMessage = clientmessage.confirmReception()

            //when
            guard let _ = confirmationMessage?.encryptedMessagePayloadData()
                else { return XCTFail()}
        }
    }

    func testThatItCreatesPayloadForConfimationMessageWhenOriginalHasNoSenderAndConnectionButInferSenderOtherActiveParticipants() {
        syncMOC.performGroupedBlockAndWait {
            //given
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .oneOnOne
            conversation.remoteIdentifier = UUID.create()
            conversation.mutableOtherActiveParticipants.add(self.syncUser1)
            
            let genericMessage = ZMGenericMessage.message(text: "yo", nonce: UUID().transportString())
            let clientmessage = ZMClientMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            clientmessage.add(genericMessage.data())
            clientmessage.visibleInConversation = conversation
            
            self.syncMOC.saveOrRollback()
            
            let confirmationMessage = clientmessage.confirmReception()

            //when
            guard let _ = confirmationMessage?.encryptedMessagePayloadData()
                else { return XCTFail()}
        }
    }

}

// MARK: - Session identifier
extension ClientMessageTests_OTR {
    
    func testThatItUsesTheProperSessionIdentifier() {
        
        // GIVEN
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        user.remoteIdentifier = UUID.create()
        let client = UserClient.insertNewObject(in: self.uiMOC)
        client.user = user
        client.remoteIdentifier = UUID.create().transportString()
        
        // WHEN
        let identifier = client.sessionIdentifier
        
        // THEN
        XCTAssertEqual(identifier, EncryptionSessionIdentifier(rawValue: "\(user.remoteIdentifier!)_\(client.remoteIdentifier!)"))
    }
}

// MARK: - Helper
extension ClientMessageTests_OTR {
    
    /// Returns a string large enough to have to be encoded in an external message
    fileprivate var stringLargeEnoughToRequireExternal: String {
        var text = "Hello"
        while (text.data(using: String.Encoding.utf8)!.count < Int(ZMClientMessageByteSizeExternalThreshold)) {
            text.append(text)
        }
        return text
    }
    
    /// Asserts that the message metadata is as expected
    fileprivate func assertMessageMetadata(_ payload: Data!, file: StaticString = #file, line: UInt = #line) {
        guard let messageMetadata = ZMNewOtrMessageBuilder().merge(from: payload).build()! as? ZMNewOtrMessage else {
            XCTFail(file: file, line: line)
            return
        }
        if let sender = messageMetadata.sender {
            XCTAssertEqual(sender.client, self.selfClient1.clientId.client, file: file, line: line)
        } else {
            XCTFail("Metadata does not contain sender", file: file, line: line)
        }
        if let recipients = messageMetadata.recipients  {
            self.assertRecipients(recipients, file: file, line: line)
        } else {
            XCTFail("Metadata does not contain recipients", file: file, line: line)
        }
    }
    
    /// Returns a string that is big enough to require external message payload
    fileprivate func textMessageRequiringExternalMessage(_ numberOfClients: UInt) -> String {
        var string = "Exponential growth!"
        while string.data(using: String.Encoding.utf8)!.count < Int(ZMClientMessageByteSizeExternalThreshold / numberOfClients) {
            string = string + string
        }
        return string
    }
}
