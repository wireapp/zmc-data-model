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
    var otherUser: ZMUser!
    
    override func setUp() {
        super.setUp()

        otherUser = ZMUser.insertNewObject(in: uiMOC)
        otherUser.remoteIdentifier = UUID()
    }
    
    override func tearDown() {
        otherUser = nil
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
    
    func testThatDetailsAreAvailableInTeamGroup_Receipts() {
        withGroupMessage(belongsToTeam: false, teamGroup: true) { message in
            XCTAssertTrue(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertTrue(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }
    
    // MARK: - Messages Sent by Other User

    func testThatDetailsAreNotAvailableInGroup_OtherUserMesaage() {
        withGroupMessage(belongsToTeam: false, teamGroup: false) { message in
            message.senderUser = self.otherUser
            XCTAssertTrue(message.areMessageDetailsAvailable(selfUser: self.selfUser))
            XCTAssertFalse(message.areReadReceiptsDetailsAvailable(selfUser: self.selfUser))
        }
    }

    func testThatDetailsAreAvailableInTeamGroup_WithoutReceipts_OtherUserMessage() {
        withGroupMessage(belongsToTeam: true, teamGroup: true) { message in
            message.senderUser = self.otherUser
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
    }

    // MARK: - Helpers

    private func withGroupMessage(belongsToTeam: Bool,
                                  teamGroup: Bool,
                                  _ block: @escaping (MockConversationMessage) -> Void) {
        let context = belongsToTeam ? teamTest : nonTeamTest

        context {
            let message = MockConversationMessage()
            
            message.senderUser = self.selfUser
            message.conversation = teamGroup ? self.createTeamGroupConversation() : self.createGroupConversation()
            let textMessageData = MockTextMessageData()
            textMessageData.messageText = "blah"
            message.backingTextMessageData = textMessageData
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
    
    func createTeamGroupConversation() -> ZMConversation {
        return createTeamGroupConversation(moc: uiMOC, otherUser: otherUser, selfUser: selfUser)
    }

    func createTeamGroupConversation(moc: NSManagedObjectContext,
                                            otherUser: ZMUser,
                                            selfUser: ZMUser) -> ZMConversation {
        let conversation = createGroupConversation(moc: moc, otherUser: otherUser, selfUser: selfUser)
        conversation.teamRemoteIdentifier = UUID.create()
        conversation.userDefinedName = "Group conversation"
        return conversation
    }

    func createGroupConversation() -> ZMConversation {
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

extension ZMConversation {
    
    func add(participants: Set<ZMUser>) {
        addParticipantsAndUpdateConversationState(users: participants, role: nil)
    }
    
    func add(participants: ZMUser...) {
        add(participants: Set(participants))
    }
}


