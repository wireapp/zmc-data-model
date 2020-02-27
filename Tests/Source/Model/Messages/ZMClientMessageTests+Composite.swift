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
    func testThatCompositeMessageDataIsReturned() {
        // GIVEN
        let nonce = UUID()
        let item1 = CompositeMessage.Item.with { $0.button = Button.with {
            $0.text = "Button text"
            $0.id = UUID().transportString()
        }}
        let item2 = CompositeMessage.Item.with { $0.text = Text.with { $0.content = "Text" } }
        let expectedCompositeMessage = CompositeMessage.with { $0.items = [item1, item2] }
        let genericMessage = GenericMessage.with {
            $0.compositeMessage = expectedCompositeMessage
            $0.messageID = nonce.transportString()
        }
        let message = ZMClientMessage(nonce: nonce, managedObjectContext: uiMOC)
        let data = try! genericMessage.serializedData()
        message.add(data)
        
        // WHEN
        let compositeMessage = message.underlyingMessage?.compositeMessage
        
        // THEN
        XCTAssertEqual(compositeMessage, expectedCompositeMessage)
        XCTAssertEqual(compositeMessage?.items, expectedCompositeMessage.items)
    }
}
