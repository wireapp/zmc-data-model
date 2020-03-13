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
@testable import WireDataModel

class ZMClientMessageTests_Composite: BaseZMClientMessageTests {
    func compositeItemButton(buttonID: String = "1") -> Composite.Item {
        return Composite.Item.with { $0.button = Button.with {
            $0.text = "Button text"
            $0.id = buttonID
        }}
    }
    
    func compositeItemText() -> Composite.Item {
        return Composite.Item.with { $0.text = Text.with { $0.content = "Text" } }
    }

    func compositeProto(items: Composite.Item...) -> Composite {
        return Composite.with { $0.items = items }
    }
    
    func compositeMessage(with proto: Composite, nonce: UUID = UUID()) -> ZMClientMessage {
        let genericMessage = GenericMessage.with {
            $0.composite = proto
            $0.messageID = nonce.transportString()
        }
        let message = ZMClientMessage(nonce: nonce, managedObjectContext: uiMOC)
        let data = try! genericMessage.serializedData()
        message.add(data)
        return message
    }
    
    func testThatCompositeMessageDataIsReturned() {
        // GIVEN
        let expectedCompositeMessage = compositeProto(items: compositeItemButton(), compositeItemText())
        let message = compositeMessage(with: expectedCompositeMessage)

        // WHEN
        let compositeMessage = message.underlyingMessage?.composite
        
        // THEN
        XCTAssertEqual(compositeMessage, expectedCompositeMessage)
        XCTAssertEqual(compositeMessage?.items, expectedCompositeMessage.items)
    }

    func testThatButtonTouchActionInsertsMessageInConversationIfNoneIsSelected() {
        // GIVEN
        let message = compositeMessage(with: compositeProto(items: compositeItemButton(), compositeItemText()))
        guard case .some(.button(let button)) = message.items.first else { return XCTFail() }
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.append(message)

        // WHEN
        button.touchAction()
        _ = waitForAllGroupsToBeEmpty(withTimeout: 0.5)
        
        // THEN
        let lastMessage = conversation.lastMessage as? ZMClientMessage
        guard case .some(.buttonAction) = lastMessage?.underlyingMessage?.content else { return XCTFail() }
    }
    
    func testThatButtonTouchActionDoesNotInsertMessageInConversationIfAButtonIsSelected() {
        // GIVEN
        let buttonItem = compositeItemButton()
        let message = compositeMessage(with: compositeProto(items: buttonItem))
        guard case .some(.button(let button)) = message.items.first else { return XCTFail() }
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.append(message)
        uiMOC.performAndWait {
            let buttonState = WireDataModel.ButtonState.insert(with: buttonItem.button.id, message: message, inContext: self.uiMOC)
            buttonState.state = .selected
            self.uiMOC.saveOrRollback()

            // WHEN
            button.touchAction()
            
            // THEN
            let lastmessage = conversation.lastMessage as? ZMClientMessage
            if case .some(.buttonAction) = lastmessage?.underlyingMessage?.content { XCTFail() }
        }
    }
    
    func testThatButtonTouchActionCreatesButtonStateIfNeeded() {
        // GIVEN
        let id = "123"
        let buttonItem = compositeItemButton(buttonID: id)
        let message = compositeMessage(with: compositeProto(items: buttonItem))
        guard case .some(.button(let button)) = message.items.first else { return XCTFail() }

        // WHEN
        button.touchAction()
        _ = waitForAllGroupsToBeEmpty(withTimeout: 0.5)
        
        // THEN
        let buttonState = message.buttonStates?.first(where: {$0.remoteIdentifier == id})
        XCTAssertNotNil(buttonState)
        XCTAssertEqual(WireDataModel.ButtonState.State.selected, buttonState?.state)
    }
    
    func testThatItUpdatesButtonStatesUponButtonActionConfirmation() {
        // GIVEN
        let nonce = UUID()
        let buttonItem1 = compositeItemButton(buttonID: "1")
        let buttonItem2 = compositeItemButton(buttonID: "2")
        let buttonItem3 = compositeItemButton(buttonID: "3")
        let buttonItem4 = compositeItemButton(buttonID: "4")

        let message = compositeMessage(with: compositeProto(items: buttonItem1, buttonItem2, buttonItem3, buttonItem4), nonce: nonce)
        
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.append(message)
        
        var buttonState1: WireDataModel.ButtonState!
        var buttonState2: WireDataModel.ButtonState!
        var buttonState3: WireDataModel.ButtonState!
        var buttonState4: WireDataModel.ButtonState!

        uiMOC.performAndWait { [uiMOC] in
            buttonState1 = WireDataModel.ButtonState.insert(with: buttonItem1.button.id, message: message, inContext: uiMOC)
            buttonState2 = WireDataModel.ButtonState.insert(with: buttonItem2.button.id, message: message, inContext: uiMOC)
            buttonState3 = WireDataModel.ButtonState.insert(with: buttonItem3.button.id, message: message, inContext: uiMOC)
            buttonState4 = WireDataModel.ButtonState.insert(with: buttonItem4.button.id, message: message, inContext: uiMOC)

            buttonState1.state = .selected
            buttonState2.state = .confirmed
            buttonState3.state = .unselected
            buttonState4.state = .selected

            uiMOC.saveOrRollback()
        }
        
        let builder = ZMButtonActionConfirmationBuilder()
        builder.setReferenceMessageId(nonce.transportString())
        builder.setButtonId("1")
        
        let confirmation = builder.build()
        
        // WHEN
        ZMClientMessage.updateButtonStates(withConfirmation: confirmation!, forConversation: conversation, inContext: uiMOC)
        _ = waitForAllGroupsToBeEmpty(withTimeout: 0.5)
        
        // THEN
        XCTAssertEqual(buttonState1.state, WireDataModel.ButtonState.State.confirmed)
        XCTAssertEqual(buttonState2.state, WireDataModel.ButtonState.State.unselected)
        XCTAssertEqual(buttonState3.state, WireDataModel.ButtonState.State.unselected)
        XCTAssertEqual(buttonState4.state, WireDataModel.ButtonState.State.unselected)
    }
}
