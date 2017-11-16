//
//  ZMMessageTimerTests.swift
//  WireDataModelTests
//
//  Created by John Nguyen on 14.11.17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import XCTest
@testable import WireDataModel
import WireTransport

class ZMMessageTimerTests: BaseZMMessageTests {
    
    let application = UIApplication.shared
    let groupQueue = DispatchGroupQueue(queue: .main)
    var sut: ZMMessageTimer!
    
    override func setUp() {
        super.setUp()
        BackgroundActivityFactory.sharedInstance().application = application
        BackgroundActivityFactory.sharedInstance().mainGroupQueue = groupQueue
        sut = ZMMessageTimer(managedObjectContext: uiMOC)!
    }
    
    override func tearDown() {
        sut.tearDown()
        sut = nil
        super.tearDown()
    }
    
    func testThatItCreatesTheBackgroundActivityWhenTimerStarted() {
        // given
        let message = createClientTextMessage("hello", encrypted: false)
        
        // when
        sut.start(forMessageIfNeeded: message, fire: Date(timeIntervalSinceNow: 1.0), userInfo: [:])
        
        // then
        let timer = sut.timer(for: message)
        XCTAssertNotNil(timer)
        let bgActivity = timer!.userInfo["bgActivity"] as? ZMBackgroundActivity
        XCTAssertNotNil(bgActivity)
    }
    
    func testThatItRemovesTheInternalTimerAfterTimerFired() {
        // given
        let message = createClientTextMessage("hello", encrypted: false)
        let expectation = self.expectation(description: "timer fired")
        sut.timerCompletionBlock = { _, _ in expectation.fulfill() }
        
        // when
        sut.start(forMessageIfNeeded: message, fire: Date(), userInfo: [:])
        _ = waitForCustomExpectations(withTimeout: 0.5)
        
        // then
        XCTAssertNil(sut.timer(for: message))
    }

    func testThatItRemovesTheInternalTimerWhenTimerStopped() {
        // given
        let message = createClientTextMessage("hello", encrypted: false)
        sut.start(forMessageIfNeeded: message, fire: Date(), userInfo: [:])
        
        // when
        sut.stop(for: message)
        
        // then
        XCTAssertNil(sut.timer(for: message))
    }
}
