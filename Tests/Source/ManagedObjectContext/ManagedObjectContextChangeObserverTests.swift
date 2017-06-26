//
//  ManagedObjectContextChangeObserverTests.swift
//  WireDataModel
//
//  Created by Silvan Dähn on 26.06.17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation


class ManagedObjectContextChangeObserverTests : ZMBaseManagedObjectTest {


    func testThatItCallsTheCallbackWhenObjectsAreInserted() {
        // given
        let changeExpectation = expectation(description: "The callback should be called")
        let sut = ManagedObjectContextChangeObserver(context: uiMOC) {
            changeExpectation.fulfill()
        }

        // when
        uiMOC.perform {
            ZMMessage.insertNewObject(in: self.uiMOC)
        }

        // then
        XCTAssert(waitForCustomExpectations(withTimeout: 0.1))
        _ = sut
    }

    func testThatItCallsTheCallbackWhenObjectsAreDelted() {
        // given
        let message = ZMMessage.insertNewObject(in: uiMOC)
        XCTAssert(uiMOC.saveOrRollback())

        let changeExpectation = expectation(description: "The callback should be called")
        let sut = ManagedObjectContextChangeObserver(context: uiMOC) {
            changeExpectation.fulfill()
        }

        // when
        uiMOC.perform {
            self.uiMOC.delete(message)
        }

        // then
        XCTAssert(waitForCustomExpectations(withTimeout: 0.1))
        _ = sut
    }

    func testThatItCallsTheCallbackWhenObjectsAreUpdated() {
        // given
        let message = ZMMessage.insertNewObject(in: uiMOC)
        XCTAssert(uiMOC.saveOrRollback())

        let changeExpectation = expectation(description: "The callback should be called")
        let sut = ManagedObjectContextChangeObserver(context: uiMOC) {
            changeExpectation.fulfill()
        }

        // when
        uiMOC.perform {
            message.markAsSent()
        }

        // then
        XCTAssert(waitForCustomExpectations(withTimeout: 0.1))
        _ = sut
    }

    func testThatItRemovesItselfAsObserverWhenReleased() {
        // given
        var called = false
        var sut: ManagedObjectContextChangeObserver? = ManagedObjectContextChangeObserver(context: uiMOC) {
            called = true
        }

        // when
        _ = sut
        sut = nil
        uiMOC.perform {
            ZMMessage.insertNewObject(in: self.uiMOC)
        }

        // then
        spinMainQueue(withTimeout: 0.05)
        XCTAssertFalse(called)
    }

}
