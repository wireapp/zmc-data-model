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

@testable import ZMCDataModel

class MockAssetCollectionDelegate : NSObject, AssetCollectionDelegate {

    var messagesByFilter = [[MessageCategory: [ZMMessage]]]()
    var hadMore = false
    var didCallDelegate = false
    var result : AssetFetchResult?
    
    public func assetCollectionDidFinishFetching(result: AssetFetchResult) {
        self.result = result
        didCallDelegate = true
    }
    
    public func assetCollectionDidFetch(messages: [MessageCategory : [ZMMessage]], hasMore: Bool) {
        messagesByFilter.append(messages)
        hadMore = hasMore
        didCallDelegate = true
    }
}

class AssetColletionTests : ModelObjectsTests {

    var sut : AssetCollection!
    var delegate : MockAssetCollectionDelegate!
    var conversation : ZMConversation!
    
    override func setUp() {
        super.setUp()
        delegate = MockAssetCollectionDelegate()
        conversation = ZMConversation.insertNewObject(in: uiMOC)
    }
    
    override func tearDown() {
        delegate = nil
        if sut != nil {
            sut.tearDown()
            XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
            sut = nil
        }
        super.tearDown()
    }
    
    func insertAssetMessages(count: Int) {
        var offset : TimeInterval = 0
        (0..<count).forEach{ _ in
            let message = conversation.appendMessage(withImageData: verySmallJPEGData()) as! ZMMessage
            offset = offset + 5
            message.setValue(Date().addingTimeInterval(offset), forKey: "serverTimestamp")
        }
        uiMOC.saveOrRollback()
    }
    
    func testThatItCanGetMessages_TotalMessageCountSmallerThanInitialFetchCount() {
        // given
        let totalMessageCount = AssetCollection.initialFetchCount - 10
        XCTAssertGreaterThan(totalMessageCount, 0)
        insertAssetMessages(count: totalMessageCount)
        
        // when
        sut = AssetCollection(conversation: conversation, categoriesToFetch: [.image], delegate: delegate)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(delegate.result, .success)
        XCTAssertFalse(delegate.hadMore)
        XCTAssertEqual(delegate.messagesByFilter.count, 1)
        XCTAssertTrue(sut.doneFetching)

        let receivedMessageCount = delegate.messagesByFilter.first?[.image]?.count
        XCTAssertEqual(receivedMessageCount, 90)
        
        guard let lastMessage =  delegate.messagesByFilter.last?[.image]?.last,
              let context = lastMessage.managedObjectContext else { return XCTFail() }
        XCTAssertTrue(context.zm_isUserInterfaceContext)
    }
    
    func testThatItCanGetMessages_TotalMessageCountEqualInitialFetchCount() {
        // given
        let totalMessageCount = AssetCollection.initialFetchCount
        insertAssetMessages(count: totalMessageCount)
        
        // when
        sut = AssetCollection(conversation: conversation, categoriesToFetch: [.image], delegate: delegate)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(delegate.result, .success)
        XCTAssertEqual(delegate.messagesByFilter.count, 1)
        XCTAssertFalse(delegate.hadMore)
        XCTAssertTrue(sut.doneFetching)
        
        let receivedMessageCount = delegate.messagesByFilter.first?[.image]?.count
        XCTAssertEqual(receivedMessageCount, 100)
        
        guard let lastMessage =  delegate.messagesByFilter.last?[.image]?.last,
            let context = lastMessage.managedObjectContext else { return XCTFail() }
        XCTAssertTrue(context.zm_isUserInterfaceContext)
    }
    
    func testThatItCanGetMessages_TotalMessageCountGreaterThanInitialFetchCount() {
        // given
        let totalMessageCount = 2 * AssetCollection.defaultFetchCount
        XCTAssertGreaterThan(totalMessageCount, AssetCollection.initialFetchCount)

        insertAssetMessages(count: totalMessageCount)
        
        // when
        sut = AssetCollection(conversation: conversation, categoriesToFetch: [.image], delegate: delegate)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        // messages were filtered in three batches
        XCTAssertEqual(delegate.result, .success)
        XCTAssertEqual(delegate.messagesByFilter.count, 3)
        XCTAssertFalse(delegate.hadMore)
        XCTAssertTrue(sut.doneFetching)
        
        let receivedMessageCount = delegate.messagesByFilter.reduce(0){$0 + ($1[.image]?.count ?? 0)}
        XCTAssertEqual(receivedMessageCount, 1000)
        
        guard let lastMessage =  delegate.messagesByFilter.last?[.image]?.last,
            let context = lastMessage.managedObjectContext else { return XCTFail() }
        XCTAssertTrue(context.zm_isUserInterfaceContext)
    }
    
    func testThatItCallsTheDelegateWhenTheMessageCountIsZero() {
        // when
        sut = AssetCollection(conversation: conversation, categoriesToFetch: [.image], delegate: delegate)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(delegate.result, .noAssetsToFetch)
        XCTAssertTrue(delegate.didCallDelegate)
        XCTAssertTrue(sut.doneFetching)
    }
    
    func testThatItCanCancelFetchingMessages() {
        // given
        let totalMessageCount = 2 * AssetCollection.defaultFetchCount
        insertAssetMessages(count: totalMessageCount)
        
        // when
        sut = AssetCollection(conversation: conversation, categoriesToFetch: [.image], delegate: delegate)
        sut.tearDown()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        // messages would filtered in three batches if the fetching was not cancelled
        XCTAssertEqual(delegate.result, .cancelled)
        XCTAssertNotEqual(delegate.messagesByFilter.count, 3)
        XCTAssertTrue(sut.doneFetching)
    }
    
    func testPerformanceOfMessageFetching() {
        // average: 0.275, relative standard deviation: 8.967%, values: [0.348496, 0.263188, 0.266409, 0.268903, 0.265612, 0.265829, 0.271573, 0.265206, 0.268697, 0.264837]
        
        // given
        insertAssetMessages(count: 1000)
        uiMOC.registeredObjects.forEach{uiMOC.refresh($0, mergeChanges: false)}
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            // when
            self.startMeasuring()
            self.sut = AssetCollection(conversation: self.conversation, categoriesToFetch: [.image], delegate: self.delegate)
            XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
            
            self.stopMeasuring()
            
            // then
            self.sut.tearDown()
            self.sut = nil
            self.uiMOC.registeredObjects.forEach{self.uiMOC.refresh($0, mergeChanges: false)}
        }
    
    }
}
