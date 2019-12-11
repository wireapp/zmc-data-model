//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
@testable import WireDataModel

final class ConversationParticipantsTests : ZMConversationTestsBase {
    
    func testThatActiveParticipantsExcludesUsersMarkedForDeletion() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()
        let user2 = createUser()
        
        sut.internalAddParticipants([user1, user2])
        
        XCTAssertEqual(sut.participantRoles.count, 2)
        XCTAssertEqual(sut.activeParticipants.count, 2)

        // WHEN
        sut.minus(userSet: Set([user2]), isFromLocal: true)
        
        // THEN
        XCTAssertEqual(Set(sut.participantRoles.map { $0.user }), Set([user1, user2]))
        XCTAssertEqual(sut.activeParticipants, Set([user1]))

        XCTAssert(user2.participantRoles.first!.markedForDeletion)
        XCTAssertFalse(user2.participantRoles.first!.markedForInsertion)
    }
    
    func testThatActiveParticipantsIncludesUsersMarkedForInsertion() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()
        let user2 = createUser()
        
        sut.internalAddParticipants([user1])

        // WHEN
        sut.add(user: user2, isFromLocal: true)

        // THEN
        XCTAssertEqual(Set(sut.participantRoles.map { $0.user }), Set([user1, user2]))
        XCTAssertEqual(sut.activeParticipants, Set([user1, user2]))

        XCTAssertFalse(user2.participantRoles.first!.markedForDeletion)
        XCTAssert(user2.participantRoles.first!.markedForInsertion)
    }
    
    func testThatLocalParticipantsExcludesUsersMarkedForDeletion() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()
        let user2 = createUser()
        sut.internalAddParticipants([user1, user2])
        
        // WHEN
        sut.minus(userSet: Set([user2]), isFromLocal: true)
        
        // THEN
        XCTAssertEqual(sut.localParticipants, Set([user1]))
    }
    
    func testThatLocalRolesExcludesUsersMarkedForDeletion() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()
        let user2 = createUser()
        sut.internalAddParticipants([user1, user2])
        
        // WHEN
        sut.minus(userSet: Set([user2]), isFromLocal: true)
        
        // THEN
        XCTAssertEqual(sut.localParticipantRoles.map { $0.user }, [user1])
    }
    
    func testThatRemoveThenAddParticipants() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()
        let user2 = createUser()
        
        sut.internalAddParticipants([user1, user2])
        
        XCTAssertEqual(sut.participantRoles.count, 2)
        XCTAssertEqual(sut.activeParticipants.count, 2)
        
        // WHEN
        sut.minus(userSet: Set([user2]), isFromLocal: true)
        sut.add(user: user2, isFromLocal: true)
        
        // THEN
        XCTAssertEqual(Set(sut.participantRoles.map { $0.user }), Set([user1, user2]))
        XCTAssertEqual(sut.activeParticipants, Set([user1, user2]))
        
        XCTAssertFalse(user2.participantRoles.first!.markedForDeletion)
        XCTAssertFalse(user2.participantRoles.first!.markedForInsertion)
    }

    func testThatAddThenRemoveParticipants() {
        // GIVEN
        let sut = createConversation(in: uiMOC)
        let user1 = createUser()
        let user2 = createUser()
        
        sut.internalAddParticipants([user1])
        
        // WHEN
        sut.add(user: user2, isFromLocal: true)
        sut.minus(userSet: Set([user2]), isFromLocal: true)
        uiMOC.processPendingChanges()

        // THEN
        XCTAssertEqual(Set(sut.participantRoles.map { $0.user }), Set([user1]))
        XCTAssertEqual(sut.activeParticipants, Set([user1]))

        XCTAssert(user2.participantRoles.isEmpty, "\(user2.participantRoles)")
    }
    
    func testThatItAddsMissingParticipantInGroup() {
        // given
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        
        // when
        conversation.addParticipantIfMissing(user, date: Date())
        
        // then
        XCTAssertTrue(conversation.activeParticipants.contains(user))
        let systemMessage = conversation.lastMessage as? ZMSystemMessage
        XCTAssertEqual(systemMessage?.systemMessageType, ZMSystemMessageType.participantsAdded)
    }
    
    func testThatItDoesntAddParticipantsAddedSystemMessageIfUserIsNotMissing() {
        // given
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        conversation.internalAddParticipants([user])
        
        // when
        conversation.addParticipantIfMissing(user, date: Date())
        
        // then
        XCTAssertTrue(conversation.activeParticipants.contains(user))
        XCTAssertEqual(conversation.allMessages.count, 0)
    }
    
    func testThatItAddsMissingParticipantInOneToOne() {
        // given
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .oneOnOne
        conversation.connection = ZMConnection.insertNewObject(in: self.uiMOC)
        
        // when
        conversation.addParticipantIfMissing(user, date: Date())

        // then
        XCTAssertTrue(conversation.activeParticipants.contains(user))
    }
    
    func testThatItReturnsAllParticipantsAsActiveParticipantsInOneOnOneConversations() {
        // given
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .oneOnOne
        
        let connection = ZMConnection.insertNewObject(in: self.uiMOC)
        connection.status = .accepted
        connection.to = user
        connection.conversation = conversation
        
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(conversation.activeParticipants.count, 2)
    }
    
    
    func testThatItReturnsAllParticipantsAsActiveParticipantsInConnectionConversations() {
        // given
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .connection
        
        let connection = ZMConnection.insertNewObject(in: self.uiMOC)
        connection.status = .pending
        connection.to = user
        connection.conversation = conversation
        
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(conversation.activeParticipants.count, 2)
    }
    
    func testThatItReturnsSelfUserAsActiveParticipantsInSelfConversations() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .self
        
        // then
        XCTAssertEqual(conversation.activeParticipants.count, 1)
    }
    
    func testThatItAddsParticipants() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        let user1 = self.createUser()
        let user2 = self.createUser()
        
        // when
        conversation.internalAddParticipants([user1])
        conversation.internalAddParticipants([user2])
        
        // then
        let expectedActiveParticipants = Set([user1, user2])
        XCTAssertEqual(expectedActiveParticipants, conversation.localParticipants)
    }
    
    func testThatItDoesNotUnarchiveTheConversationWhenTheSelfUserIsAddedIfMuted() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        conversation.isArchived = true
        conversation.mutedStatus = MutedMessageOptionValue.all.rawValue
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        selfUser.remoteIdentifier =  UUID.create()
        
        // when
        conversation.internalAddParticipants([selfUser])
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(conversation.isArchived)
    }
    
    func testThatItUnarchivesTheConversationWhenTheSelfUserIsAdded() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        conversation.isArchived = true
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        selfUser.remoteIdentifier =  UUID.create()
        
        // when
        conversation.internalAddParticipants([selfUser])
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(conversation.isArchived)
    }
    
    func testThatItCanRemoveTheSelfUser() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        let user1 = self.createUser()
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        selfUser.remoteIdentifier =  UUID.create()
        
        conversation.internalAddParticipants([selfUser, user1])
        
        XCTAssertTrue(conversation.isSelfAnActiveMember)
        
        // when
        conversation.internalRemoveParticipants([selfUser], sender: user1)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(conversation.isSelfAnActiveMember)
    }
    
    func testThatItDoesNothingForUnknownParticipants() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        let user1 = self.createUser()
        let user2 = self.createUser()
        let user3 = self.createUser()
        let unknownUser = self.createUser()
        conversation.internalAddParticipants([user1, user2, user3])
        
        // when
        conversation.internalRemoveParticipants([unknownUser], sender:user1)
        
        // then
        let expectedActiveParticipants = Set([user1, user2, user3])
        XCTAssertEqual(expectedActiveParticipants, conversation.localParticipants)
    }
    
    func testThatActiveParticipantsContainsSelf() {
        // TODO: review
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        
        // when
        conversation.add(user: ZMUser.selfUser(in: self.uiMOC), isFromLocal: true)
        
        // then
        XCTAssertTrue(conversation.activeParticipants.contains(selfUser))
        
        // when
        conversation.minus(user: ZMUser.selfUser(in: self.uiMOC), isFromLocal: true)
        
        // then
        XCTAssertFalse(conversation.activeParticipants.contains(selfUser))
    }
    
    func testThatLocalParticipantsExcludingSelfDoesNotContainSelf() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        
        // when
        conversation.add(user: selfUser, isFromLocal: true)
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertFalse(conversation.localParticipantsExcludingSelf.contains(selfUser))
    }

    //MARK: - Sorting

    func testThatItSortsParticipantsByFullName() {
        
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        let uuid = UUID.create()
        conversation.remoteIdentifier = uuid
        
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        let user1 = self.createUser()
        let user2 = self.createUser()
        let user3 = self.createUser()
        let user4 = self.createUser()

        selfUser.name = "Super User"
        user1.name = "Hans im Glueck"
        user2.name = "Anna Blume"
        user3.name = "Susi Super"
        user4.name = "Super Susann"

        // when
        conversation.internalAddParticipants([user1, user2, user3, user4])
        self.uiMOC.saveOrRollback()

        // then
        let expected = [user2, user1, user4, user3]

        XCTAssertEqual(conversation.sortedActiveParticipants, expected)
    }
    
    // MARK: - ConnectedUser
    
    func testThatTheConnectedUserIsNilForGroupConversation() {
        // when
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        conversation.add(user: ZMUser.insertNewObject(in: self.uiMOC), isFromLocal: false)
        conversation.add(user: ZMUser.insertNewObject(in: self.uiMOC), isFromLocal: false)
        
        // then
        XCTAssertNil(conversation.connectedUser)
    }
    
    func testThatTheConnectedUserIsNilForSelfconversation() {
        // when
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .self
        
        // then
        XCTAssertNil(conversation.connectedUser)
    }
    
    func testThatWeHaveAConnectedUserForOneOnOneConversation() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .oneOnOne
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        let connection = ZMConnection.insertNewObject(in: self.uiMOC)
        connection.to = user
        
        // when
        connection.conversation = conversation
        
        // then
        XCTAssertEqual(conversation.connectedUser, user)
    }
    
    func testThatWeHaveAConnectedUserForConnectionConversation() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .connection
        let user = ZMUser.insertNewObject(in: self.uiMOC)
        let connection = ZMConnection.insertNewObject(in: self.uiMOC)
        connection.to = user
        
        // when
        connection.conversation = conversation
        
        // then
        XCTAssertEqual(conversation.connectedUser, user)
    }
    
    func testThatWeGetAConversationRolesIfItIsAPartOfATeam() {
        // given
        let team = self.createTeam(in: self.uiMOC)
        let user1 = self.createTeamMember(in: self.uiMOC, for: team)
        let user2 = self.createTeamMember(in: self.uiMOC, for: team)
        let conversation = ZMConversation.insertGroupConversation(into: self.uiMOC, withParticipants: [user1, user2], name: self.name, in: team)
        
        // when
        let adminRole = Role.create(managedObjectContext: uiMOC, name: "wire_admin", team: team)
        let memberRole = Role.create(managedObjectContext: uiMOC, name: "wire_member", team: team)
        team.roles.insert(adminRole)
        team.roles.insert(memberRole)
        
        // then
        XCTAssertNotNil(conversation!.team)
        XCTAssertEqual(conversation!.getRoles(), conversation!.team!.roles)
        XCTAssertNotEqual(conversation!.getRoles(), conversation!.nonTeamRoles)
    }
    
    func testThatWeGetAConversationRolesIfItIsNotAPartOfATeam() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        
        // when
        let adminRole = Role.create(managedObjectContext: uiMOC, name: "wire_admin", conversation: conversation)
        conversation.nonTeamRoles.insert(adminRole)
        
        // then
        XCTAssertNil(conversation.team)
        XCTAssertEqual(conversation.getRoles(), conversation.nonTeamRoles)
        XCTAssertNotEqual(conversation.getRoles(), conversation.team?.roles)
    }
}
