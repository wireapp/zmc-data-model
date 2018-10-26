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

class ZMClientMessagesTests_Replies: BaseZMClientMessageTests {
    
    func createMessage(text: String, quote: ZMClientMessage?) -> ZMClientMessage {
        let zmText = ZMText.text(with: text, mentions: [], linkPreviews: [], quote: quote)
        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.add(ZMGenericMessage.message(content: zmText).data())
        return message
    }
    
    func testQuoteIsReturned() {
        let quotedMessage = createMessage(text: "I have a proposal", quote: nil)
        let message = createMessage(text: "That's fine", quote: quotedMessage)
        
        XCTAssertEqual(message.quote, quotedMessage)
    }
    
}
