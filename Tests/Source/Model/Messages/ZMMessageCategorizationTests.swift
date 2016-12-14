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
import ZMUtilities
import ZMCDataModel
import ZMCLinkPreview


class ZMMessageCategorizationTests : ZMBaseManagedObjectTest {
    
    var conversation : ZMConversation!
    
    override func setUp() {
        super.setUp()
        self.conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        self.conversation.conversationType = .group
        self.conversation.remoteIdentifier = UUID.create()
    }
    
    override func tearDown() {
        self.conversation = nil
        super.tearDown()
    }
    
    func testThatItCategorizesATextMessage() {
        
        // GIVEN
        let message = self.conversation.appendMessage(withText: "ramble on!")!
        
        // THEN
        XCTAssertEqual(message.categorization, MessageCategory.text)
    }

    func testThatItCategorizesATextMessageWithLink() {
        
        // GIVEN
        let message = self.conversation.appendMessage(withText: "ramble on https://en.wikipedia.org/wiki/Ramble_On here")!
        
        // THEN
        XCTAssertEqual(message.categorization, [MessageCategory.text, MessageCategory.link])
    }
    
    func testThatItCategorizesALinkPreviewMessage() {
        
        // GIVEN
        let article = Article(
            originalURLString: "www.example.com/article/original",
            permamentURLString: "http://www.example.com/article/1",
            offset: 12
        )
        article.title = "title"
        article.summary = "summary"
        let linkPreview = article.protocolBuffer.update(withOtrKey: Data(), sha256: Data())
        let genericMessage = ZMGenericMessage.message(text: "foo", linkPreview: linkPreview, nonce: UUID.create().transportString())
        let message = self.conversation.appendClientMessage(with: genericMessage.data())
        message.linkPreviewState = .processed
        
        // THEN
        XCTAssertEqual(message.categorization, [MessageCategory.text, MessageCategory.link])
    }
    
    func testThatItCategorizesAnImageMessage() {
        
        // GIVEN
        let message = self.conversation.appendMessage(withImageData: self.verySmallJPEGData())!
        
        // THEN
        XCTAssertEqual(message.categorization, MessageCategory.image)
    }
    
    func testThatItCategorizesAGifImageMessage() {
        
        // GIVEN
        let data = self.data(forResource: "animated", extension: "gif")!
        let message = ZMAssetClientMessage(originalImageData: data, nonce: .create(), managedObjectContext: uiMOC, expiresAfter: 0)
        message.isEncrypted = true
        let testProperties = ZMIImageProperties(size: CGSize(width: 33, height: 55), length: UInt(10), mimeType: "image/gif")
        message.imageAssetStorage!.setImageData(data, for: .medium, properties: testProperties)
        
        
        // THEN
        XCTAssertEqual(message.categorization, [MessageCategory.image, MessageCategory.GIF])
    }

    func testThatItCategorizesKnocks() {
        
        // GIVEN
        let message = self.conversation.appendKnock()
        
        // THEN
        XCTAssertEqual(message.categorization, MessageCategory.knock)
    }
    
    func testThatItCategorizesFile() {
        
        // GIVEN
        let message = self.conversation.appendMessage(with: ZMFileMetadata(fileURL: self.fileURL(forResource: "Lorem Ipsum", extension: "txt")!))
        
        // THEN
        XCTAssertEqual(message?.categorization, MessageCategory.file)
    }
    
//    func testThatItCategorizesAudioFile() {
//        
//        // GIVEN
//        let message = self.conversation.appendMessage(with: ZMAudioMetadata(fileURL: self.fileURL(forResource: <#T##String!#>, extension: <#T##String!#>), duration: <#T##TimeInterval#>)
//        
//        // THEN
//        XCTAssertEqual(message?.categorization, MessageCategory.file)
//    }
}

/*
 
 public static let none = MessageCategory(rawValue: 0)
 public static let undefined = MessageCategory(rawValue: 1 << 0)
 public static let audio = MessageCategory(rawValue: 1 << 6)
 public static let video = MessageCategory(rawValue: 1 << 7)
 public static let location = MessageCategory(rawValue: 1 << 8)
 public static let liked = MessageCategory(rawValue: 1 << 9)
 public static let systemMessage = MessageCategory(rawValue: 1 << 11)
 
 */
