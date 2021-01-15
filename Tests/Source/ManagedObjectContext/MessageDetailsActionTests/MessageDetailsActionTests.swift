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

import XCTest
@testable import WireDataModel
import WireTesting

final class MessageDetailsActionTests: ZMConversationTestsBase {
    private var selfUserInTeam: Bool = false
    var team: Team?
    var teamMember: Member?
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    // MARK: - One To One

    func testThatDetailsAreNotAvailableForOneToOne_Consumer() {
        withOneToOneMessage(belongsToTeam: false) { message in
            XCTAssertFalse(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertFalse(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }

    func testThatDetailsAreNotAvailableForOneToOne_Team() {
        withOneToOneMessage(belongsToTeam: true) { message in
            XCTAssertFalse(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertFalse(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }

    // MARK: - Groups

    func testThatDetailsAreAvailableInGroup_WithoutReceipts() {
        withGroupMessage(belongsToTeam: false, teamGroup: false) { message in
            XCTAssertTrue(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertFalse(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }
    
    /*func testThatDetailsAreAvailableInTeamGroup_Receipts() {
        withGroupMessage(belongsToTeam: false, teamGroup: true) { message in
            XCTAssertTrue(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertTrue(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }*/
    
    // MARK: - Messages Sent by Other User
/*
    func testThatDetailsAreNotAvailableInGroup_OtherUserMesaage() {
        withGroupMessage(belongsToTeam: false, teamGroup: false) { message in
            message.senderUser = MockUserType.createUser(name: "Bob")
            XCTAssertTrue(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertFalse(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }

    func testThatDetailsAreAvailableInTeamGroup_WithoutReceipts_OtherUserMessage() {
        withGroupMessage(belongsToTeam: true, teamGroup: true) { message in
            message.senderUser = MockUserType.createUser(name: "Bob")
            XCTAssertTrue(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertFalse(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }

    // MARK: - Ephemeral Message in Group

    func testThatDetailsAreNotAvailableInGroup_Ephemeral() {
        withGroupMessage(belongsToTeam: false, teamGroup: false) { message in
            message.isEphemeral = true
            XCTAssertFalse(message.canBeLiked(selfUser: self.selfUser))
            XCTAssertFalse(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertFalse(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }

    func testThatDetailsAreAvailableInTeamGroup_Ephemeral() {
        withGroupMessage(belongsToTeam: true, teamGroup: true) { message in
            message.isEphemeral = true
            XCTAssertFalse(message.canBeLiked(selfUser: self.selfUser))
            XCTAssertTrue(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertTrue(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }*/

    // MARK: - Helpers

    private func withGroupMessage(belongsToTeam: Bool, teamGroup: Bool, _ block: @escaping (ZMConversationMessage) -> Void) {
        let context = belongsToTeam ? teamTest : nonTeamTest

        context {
//            let message = MockMessageFactory.textMessage(withText: "Message")!
//            let conversation = ZMConversation.insertNewObject(in: uiMOC)
//                    let message = try! conversation.appendText(content: "This is the first message in the conversation") as! ZMMessage
            
            let message = MockConversationMessage()
            
            message.senderUser = self.selfUser//MockUserType.createSelfUser(name: "Alice")
//            message.conversation = teamGroup ? self.createTeamGroupConversation() : self.createGroupConversation()
            message.conversation = self.createGroupConversation()
            let textMessageData = MockTextMessageData()
            textMessageData.messageText = "blah"
            message.backingTextMessageData = textMessageData
//            message.textMessageData = Data()
            block(message)
        }
    }

    private func withOneToOneMessage(belongsToTeam: Bool, _ block: @escaping (ZMConversationMessage) -> Void) {
        let context = belongsToTeam ? teamTest : nonTeamTest

        context {
            let conversation = ZMConversation.insertNewObject(in: uiMOC)
            let message = try! conversation.appendText(content: "This is the first message in the conversation") as! ZMMessage

            block(message)
        }
    }
    
    func createGroupConversation() -> ZMConversation {
        let otherUser = ZMUser.insertNewObject(in: uiMOC)
        otherUser.remoteIdentifier = UUID()
//        otherUser.name = "Bruno"
//        otherUser.setHandle("bruno")
//        otherUser.accentColorValue = .brightOrange
        
        return createGroupConversation(moc: uiMOC, otherUser: otherUser, selfUser: selfUser)
    }
    
    func createGroupConversation(moc: NSManagedObjectContext,
                                        otherUser: ZMUser,
                                        selfUser: ZMUser) -> ZMConversation {
        let conversation = createGroupConversationOnlyAdmin(moc: moc, selfUser: selfUser)
        conversation.add(participants: otherUser)
        return conversation
    }
    
    func createGroupConversationOnlyAdmin(moc: NSManagedObjectContext, selfUser: ZMUser) -> ZMConversation {
        let conversation = ZMConversation.insertNewObject(in: moc)
        conversation.remoteIdentifier = UUID.create()
        conversation.conversationType = .group
        
        let role = Role(context: moc)
        role.name = ZMConversation.defaultAdminRoleName
        conversation.addParticipantsAndUpdateConversationState(users: [selfUser], role: role)
        
        return conversation
    }

    func nonTeamTest(_ block: () -> Void) {
        let wasInTeam = selfUserInTeam
        selfUserInTeam = false
        updateTeamStatus(wasInTeam: wasInTeam)
        block()
    }
    
    func teamTest(_ block: () -> Void) {
        let wasInTeam = selfUserInTeam
        selfUserInTeam = true
        updateTeamStatus(wasInTeam: wasInTeam)
        block()
    }
    
    private func updateTeamStatus(wasInTeam: Bool) {
        guard wasInTeam != selfUserInTeam else {
            return
        }
        
        if selfUserInTeam {
            setupMember()
        } else {
            teamMember = nil
            team = nil
        }
    }
    
    private func setupMember() {
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        
        team = Team.insertNewObject(in: uiMOC)
        team!.remoteIdentifier = UUID()
        
        
        teamMember = Member.insertNewObject(in: uiMOC)
        teamMember!.user = selfUser
        teamMember!.team = team
        teamMember!.setTeamRole(.member)
    }
}

/*
final class MockMessage: NSObject, ZMConversationMessage {
    /// Unique identifier for the message
    var nonce: UUID?
    
    /// The user who sent the message (internal)
    @available(*, deprecated, message: "Use `senderUser` instead")
    var sender: ZMUser?
    
    /// The user who sent the message
    var senderUser: UserType?
    
    /// The timestamp as received by the server
    var serverTimestamp: Date?
    
    /// The conversation this message belongs to
    var conversation: ZMConversation?
    
    /// The current delivery state of this message. It makes sense only for
    /// messages sent from this device. In any other case, it will be
    /// ZMDeliveryStateDelivered
    var deliveryState: ZMDeliveryState = .delivered

    /// True if the message has been successfully sent to the server
    var isSent: Bool = false
    
    /// List of recipients who have read the message.
    var readReceipts: [ReadReceipt] = []
    
    /// Whether the message expects read confirmations.
    var needsReadConfirmation: Bool = false
    
    /// The textMessageData of the message which also contains potential link previews. If the message has no text, it will be nil
    var textMessageData : ZMTextMessageData?
    
    /// The image data associated with the message. If the message has no image, it will be nil
    var imageMessageData: ZMImageMessageData?
    
    /// The system message data associated with the message. If the message is not a system message data associated, it will be nil
    var systemMessageData: ZMSystemMessageData?
    
    /// The knock message data associated with the message. If the message is not a knock, it will be nil
    var knockMessageData: ZMKnockMessageData?
    
    /// The file transfer data associated with the message. If the message is not the file transfer, it will be nil
    var fileMessageData: ZMFileMessageData?
    
    /// The location message data associated with the message. If the message is not a location message, it will be nil
    var locationMessageData: LocationMessageData?
    
    var usersReaction : Dictionary<String, [ZMUser]> = Dictionary()
    
    /// In case this message failed to deliver, this will resend it
    func resend() {
        
    }
    
    /// tell whether or not the message can be deleted
    var canBeDeleted : Bool = false
    
    /// True if the message has been deleted
    var hasBeenDeleted : Bool = false
    
    var updatedAt : Date?
    
    /// Starts the "self destruction" timer if all conditions are met
    /// It checks internally if the message is ephemeral, if sender is the other user and if there is already an existing timer
    /// Returns YES if a timer was started by the message call
    func startSelfDestructionIfNeeded() -> Bool {
        return false
    }
    
    /// Returns true if the message is ephemeral
    var isEphemeral : Bool = false
    
    /// If the message is ephemeral, it returns a fixed timeout
    /// Otherwise it returns -1
    /// Override this method in subclasses if needed
    var deletionTimeout : TimeInterval = 0
    
    /// Returns true if the message is an ephemeral message that was sent by the selfUser and the obfuscation timer already fired
    /// At this point the genericMessage content is already cleared. You should receive a notification that the content was cleared
    var isObfuscated : Bool = false
    
    /// Returns the date when a ephemeral message will be destructed or `nil` if th message is not ephemeral
    var destructionDate: Date?
    
    /// Returns whether this is a message that caused the security level of the conversation to degrade in this session (since the
    /// app was restarted)
    var causedSecurityLevelDegradation : Bool = false
    
    /// Marks the message as the last unread message in the conversation, moving the unread mark exactly before this
    /// message.
    func markAsUnread() {
        
    }
    
    /// Checks if the message can be marked unread
    var canBeMarkedUnread: Bool = false
    
    /// The replies quoting this message.
    var replies: Set<ZMMessage> = Set()
    
    /// An in-memory identifier for tracking the message during its life cycle.
    var objectIdentifier: String = ""
    
    /// The links attached to the message.
    var linkAttachments: [LinkAttachment]?
    
    /// Used to trigger link attachments update for this message.
    var needsLinkAttachmentsUpdate: Bool = false
    
    var isSilenced: Bool = false

}*/

extension ZMConversation {
    
    func add(participants: Set<ZMUser>) {
        addParticipantsAndUpdateConversationState(users: participants, role: nil)
    }

//    func add(participants: [ZMUser]) {
//        add(participants: Set(participants))
//    }
    
    func add(participants: ZMUser...) {
        add(participants: Set(participants))
    }
}


