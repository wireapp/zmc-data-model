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
import XCTest
@testable import WireDataModel

class ModelValidationTests: XCTestCase {

    // MARK: Generic Message

    func testThatItCreatesGenericMessageWithValidFields() {

        let text = ZMText.builder()!
        text.setContent("Hello hello hello")

        let builder = ZMGenericMessage.builder()!
        builder.setText(text)
        builder.setMessageId("8783C4BD-A5D3-4F6B-8C41-A6E75F12926F")

        let message = builder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateGenericMessageWithInvalidFields() {

        let text = ZMText.builder()!
        text.setContent("Hieeee!")

        let builder = ZMGenericMessage.builder()!
        builder.setText(text)
        builder.setMessageId("nonce")

        let message = builder.buildAndValidate()
        XCTAssertNil(message)

    }

    // MARK: Mention

    func testThatItCreatesTextWithValidMentions() {

        let mentionBuilder = ZMMention.builder()!
        mentionBuilder.setUserName("John Appleseed")
        mentionBuilder.setUserId("8783C4BD-A5D3-4F6B-8C41-A6E75F12926F")

        let textBuilder = ZMText.builder()!
        textBuilder.setContent("Hello @John Appleseed")
        textBuilder.addMention(mentionBuilder.build()!)

        let builder = ZMGenericMessage.builder()!
        builder.setMessageId(UUID.create().transportString())
        builder.setText(textBuilder.build()!)

        let message = builder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateTextWithInvalidMention() {

        let mentionBuilder = ZMMention.builder()!
        mentionBuilder.setUserName("Jane Appleseed")
        mentionBuilder.setUserId("user\u{0}")

        let textBuilder = ZMText.builder()!
        textBuilder.setContent("Hello @John Appleseed")
        textBuilder.addMention(mentionBuilder.build()!)

        let builder = ZMGenericMessage.builder()!
        builder.setMessageId(UUID.create().transportString())
        builder.setText(textBuilder.build()!)

        let message = builder.buildAndValidate()
        XCTAssertNil(message)

    }

    // MARK: Last Read

    func testThatItCreatesLastReadWithValidFields() {

        let builder = ZMLastRead.builder()!
        builder.setConversationId("8783C4BD-A5D3-4F6B-8C41-A6E75F12926F")
        builder.setLastReadTimestamp(25_000)

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setLastRead(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateLastReadWithInvalidFields() {

        let builder = ZMLastRead.builder()!
        builder.setConversationId("null")
        builder.setLastReadTimestamp(25_000)

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setLastRead(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNil(message)

    }

    // MARK: Cleared

    func testThatItCreatesClearedWithValidFields() {

        let builder = ZMCleared.builder()!
        builder.setConversationId("8783C4BD-A5D3-4F6B-8C41-A6E75F12926F")
        builder.setClearedTimestamp(25_000)

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setCleared(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateClearedWithInvalidFields() {

        let builder = ZMCleared.builder()!
        builder.setConversationId("wirewire")
        builder.setClearedTimestamp(25_000)

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setCleared(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNil(message)

    }

    // MARK: Message Hide

    func testThatItCreatesHideWithValidFields() {

        let builder = ZMMessageHide.builder()!
        builder.setConversationId("8783C4BD-A5D3-4F6B-8C41-A6E75F12926F")
        builder.setMessageId("8B496992-E74D-41D2-A2C4-C92EEE777DCE")

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setHidden(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateHideWithInvalidFields() {

        let invalidConversationBuilder = ZMMessageHide.builder()!
        invalidConversationBuilder.setConversationId("")
        invalidConversationBuilder.setMessageId("8B496992-E74D-41D2-A2C4-C92EEE777DCE")

        let invalidConversationMessageBuilder = genericMessageBuilder()
        invalidConversationMessageBuilder.setHidden(invalidConversationBuilder.build())
        let invalidConversationHide = invalidConversationMessageBuilder.buildAndValidate()
        XCTAssertNil(invalidConversationHide)

        let invalidMessageBuilder = ZMMessageHide.builder()!
        invalidMessageBuilder.setConversationId("8B496992-E74D-41D2-A2C4-C92EEE777DCE")
        invalidMessageBuilder.setMessageId("")

        let invalidMessageMessageBuilder = genericMessageBuilder()
        invalidMessageMessageBuilder.setHidden(invalidMessageBuilder)
        let invalidMessageHide = invalidMessageMessageBuilder.buildAndValidate()
        XCTAssertNil(invalidMessageHide)

        let invalidHideBuilder = ZMMessageHide.builder()!
        invalidHideBuilder.setConversationId("")
        invalidHideBuilder.setMessageId("")

        let invalidHideMessageBuilder = genericMessageBuilder()
        invalidHideMessageBuilder.setHidden(invalidHideBuilder)
        let invalidHide = invalidHideMessageBuilder.buildAndValidate()
        XCTAssertNil(invalidHide)

    }

    // MARK: Message Delete

    func testThatItCreatesMessageDeleteWithValidFields() {

        let builder = ZMMessageDelete.builder()!
        builder.setMessageId("8B496992-E74D-41D2-A2C4-C92EEE777DCE")

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setDeleted(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateMessageDeleteWithInvalidFields() {

        let builder = ZMMessageDelete.builder()!
        builder.setMessageId("invalid")

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setDeleted(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNil(message)

    }

    // MARK: Message Edit

    func testThatItCreatesMessageEditWithValidFields() {

        let text = ZMText.builder()!
        text.setContent("Hello")

        let builder = ZMMessageEdit.builder()!
        builder.setText(text)
        builder.setReplacingMessageId("8B496992-E74D-41D2-A2C4-C92EEE777DCE")

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setEdited(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateMessageEditWithInvalidFields() {

        let text = ZMText.builder()!
        text.setContent("Hello")

        let builder = ZMMessageEdit.builder()!
        builder.setText(text)
        builder.setReplacingMessageId("N0TAUNIV-ER5A-77YU-NIQU-EID3NTIF1ER!")

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setEdited(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNil(message)

    }

    // MARK: Message Confirmation

    func testThatItCreatesConfirmationWithValidFields() {

        let builder = ZMConfirmation.builder()!
        builder.setType(.DELIVERED)
        builder.setFirstMessageId("8B496992-E74D-41D2-A2C4-C92EEE777DCE")
        builder.setMoreMessageIdsArray(["54A6E947-1321-42C6-BA99-F407FDF1A229"])

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setConfirmation(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateConfirmationWithInvalidFields() {

        let invalidFirstIDBuilder = ZMConfirmation.builder()!
        invalidFirstIDBuilder.setType(.DELIVERED)
        invalidFirstIDBuilder.setFirstMessageId("invalid")
        invalidFirstIDBuilder.setMoreMessageIdsArray(["54A6E947-1321-42C6-BA99-F407FDF1A229"])

        let invalidFirstIDMessageBuilder = genericMessageBuilder()
        invalidFirstIDMessageBuilder.setConfirmation(invalidFirstIDBuilder.build())
        let invalidFirstIDMessage = invalidFirstIDMessageBuilder.buildAndValidate()
        XCTAssertNil(invalidFirstIDMessage)

        let invalidArrayBuilder = ZMConfirmation.builder()!
        invalidArrayBuilder.setType(.DELIVERED)
        invalidArrayBuilder.setFirstMessageId("8B496992-E74D-41D2-A2C4-C92EEE777DCE")
        invalidArrayBuilder.setMoreMessageIdsArray(["54A6E947-1321-42C6-BA99-F407FDF1A229", 150])

        let invalidArrayMessageBuilder = genericMessageBuilder()
        invalidArrayMessageBuilder.setConfirmation(invalidArrayBuilder.build())
        let invalidArrayMessage = invalidArrayMessageBuilder.buildAndValidate()
        XCTAssertNil(invalidArrayMessage)

    }

    // MARK: Reaction

    func testThatItCreatesReactionWithValidFields() {

        let builder = ZMReaction.builder()!
        builder.setMessageId("8B496992-E74D-41D2-A2C4-C92EEE777DCE")
        builder.setEmoji("🤩")

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setReaction(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNotNil(message)

    }

    func testThatItDoesNotCreateReactionWithInvalidFields() {

        let builder = ZMReaction.builder()!
        builder.setMessageId("Not-A-UUID")
        builder.setEmoji("🤩")

        let messageBuilder = genericMessageBuilder()
        messageBuilder.setReaction(builder.build())

        let message = messageBuilder.buildAndValidate()
        XCTAssertNil(message)

    }

    // MARK: User ID

    func testThatItCreatesUserIDWithValidFields() {

        let builder = ZMUserId.builder()!
        builder.setUuid(NSUUID().data())

        let userID = builder.build().validatingFields()
        XCTAssertNotNil(userID)

    }

    func testThatItDoesNotCreateUserIDWithInvalidFields() {

        let tooSmallBuilder = ZMUserId.builder()!
        tooSmallBuilder.setUuid(Data())

        let tooSmall = tooSmallBuilder.build().validatingFields()
        XCTAssertNil(tooSmall)

    }

    // MARK: - Utilities

    private func genericMessageBuilder() -> ZMGenericMessageBuilder {
        let builder = ZMGenericMessage.builder()!
        builder.setMessageId(UUID.create().uuidString)
        return builder
    }

}
