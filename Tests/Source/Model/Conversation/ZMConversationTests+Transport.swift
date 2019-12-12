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
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
@testable import WireDataModel

extension ZMConversationTransportTests {

    func testThatItDoesNotUpdatesLastModifiedDateIfAlreadyExists() {
        syncMOC.performGroupedAndWait() {_ in
            // given
            ZMUser.selfUser(in: self.syncMOC).teamIdentifier = UUID()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            let uuid = UUID.create()
            conversation.remoteIdentifier = uuid
            let currentTime = Date()

            // assume that the backup date is one day before
            let lastModifiedDate = currentTime.addingTimeInterval(86400)
            conversation.lastModifiedDate = lastModifiedDate
            let serverTimestamp = currentTime

            let payload = self.payloadForMetaData(of: conversation, conversationType: .group, isArchived: true, archivedRef: currentTime, isSilenced: true, silencedRef: currentTime, silencedStatus: nil)

            // when
            conversation.update(transportData: payload as! [String: Any], serverTimeStamp: serverTimestamp)

            // then
            XCTAssertEqual(conversation.lastServerTimeStamp, serverTimestamp)
            XCTAssertEqual(conversation.lastModifiedDate, lastModifiedDate)
            XCTAssertNotEqual(conversation.lastModifiedDate, serverTimestamp)
        }
    }
    
    func testThatItParserRolesFromConversationMetadataNotInTeam() {
        
        syncMOC.performGroupedAndWait() { _ -> () in
            // given
            ZMUser.selfUser(in: self.syncMOC).teamIdentifier = UUID()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            conversation.remoteIdentifier = UUID.create()
            let user1ID = UUID.create()
            let user2ID = UUID.create()
            
            let payload = self.simplePayload(
                conversation: conversation,
                team: nil,
                otherActiveUsersAndRoles: [
                    (user1ID, nil),
                    (user2ID, "test_role")
                ]
            )
            
            // when
            conversation.update(transportData: payload, serverTimeStamp: Date())
            
            // then
            XCTAssertEqual(
                Set(conversation.localParticipants.map { $0.remoteIdentifier }),
                Set([user1ID, user2ID, selfUser.remoteIdentifier!])
            )
            guard let participant1 = conversation.participantRoles
                .first(where: {$0.user.remoteIdentifier == user1ID}) else {
                return XCTFail()
            }
            guard let participant2 = conversation.participantRoles
                .first(where: {$0.user.remoteIdentifier == user2ID}) else {
                    return XCTFail()
            }
            XCTAssertNil(participant1.role)
            XCTAssertEqual(participant2.role?.name, "test_role")
            XCTAssertEqual(conversation.nonTeamRoles.count, 1)
            XCTAssertEqual(conversation.nonTeamRoles.first, participant2.role)
        }
    }
    
    func testThatItParserRolesFromConversationMetadataInTeam() {
        
        syncMOC.performGroupedAndWait() { _ -> () in
            // given
            ZMUser.selfUser(in: self.syncMOC).teamIdentifier = UUID()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            conversation.remoteIdentifier = UUID.create()
            let user1ID = UUID.create()
            let user2ID = UUID.create()
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = UUID.create()
            
            let payload = self.simplePayload(
                conversation: conversation,
                team: team,
                otherActiveUsersAndRoles: [
                    (user1ID, "test_role1"),
                    (user2ID, "test_role2")
                ]
            )
            
            // when
            conversation.update(transportData: payload, serverTimeStamp: Date())
            
            // then
            XCTAssertEqual(
                Set(conversation.localParticipants.map { $0.remoteIdentifier }),
                Set([user1ID, user2ID, selfUser.remoteIdentifier!])
            )
            guard let participant1 = conversation.participantRoles
                .first(where: {$0.user.remoteIdentifier == user1ID}) else {
                    return XCTFail()
            }
            guard let participant2 = conversation.participantRoles
                .first(where: {$0.user.remoteIdentifier == user2ID}) else {
                    return XCTFail()
            }
            XCTAssertEqual(participant1.role?.team, team)
            XCTAssertEqual(participant2.role?.team, team)
            XCTAssertEqual(participant1.role?.name, "test_role1")
            XCTAssertEqual(participant2.role?.name, "test_role2")
            XCTAssertEqual(team.roles, Set([participant1.role, participant2.role].compactMap {$0}))
            
        }
    }
}

extension ZMConversationTransportTests {
    
    func simplePayload(
        conversation: ZMConversation,
        team: Team?,
        conversationType: BackendConversationType = BackendConversationType.group,
        otherActiveUsersAndRoles: [(UUID, String?)] = []
        ) -> [String: Any] {
        
        let others = otherActiveUsersAndRoles.map { id, role -> [String: Any] in
            var dict: [String: Any] = ["id": id.transportString()]
            if let role = role {
                dict["conversation_role"] = role
            }
            return dict
        }
        
        return [
            "name": NSNull(),
            "creator": "3bc5750a-b965-40f8-aff2-831e9b5ac2e9",
            "members": [
                "self": [
                    "id" : "3bc5750a-b965-40f8-aff2-831e9b5ac2e9",
                ],
                "others": others,
            ],
            "type" : conversationType.rawValue,
            "id" : conversation.remoteIdentifier?.transportString() ?? "",
            "team": team?.remoteIdentifier?.transportString() ?? NSNull(),
            "access": [],
            "access_role": "non_activated",
            "receipt_mode": 0
        ]
    }

}

