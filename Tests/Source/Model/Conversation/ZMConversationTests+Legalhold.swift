//
//  ZMConversationTests+Legalhold.swift
//  WireDataModelTests
//
//  Created by Jacob Persson on 13.05.19.
//  Copyright © 2019 Wire Swiss GmbH. All rights reserved.
//

import XCTest

class ZMConversationTests_Legalhold: ZMConversationTestsBase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // MARK - Update legal hold on client changes
    
    func testThatLegalholdIsActivatedForUser_WhenLegalholdClientIsDiscovered() {
        
    }
    
    func testThatLegalholdIsDeactivatedForUser_WhenLegalholdClientIsDeleted() {
        
    }
    
    func testThatLegalholdIsActivatedForConversation_WhenLegalholdClientIsDiscovered() {
        
    }
    
    func testThatLegalholdIsDeactivatedInConversation_OnlyWhenTheLastLegalholdClientIsDeleted() {
        
    }
    
    // MARK - Update legal hold on participant changes
    
    func testThatLegalholdIsInConversation_WhenParticipantIsAdded() {
        
    }
    
    func testThatLegalholdIsDeactivatedInConversation_WhenTheLastLegalholdParticipantIsRemoved() {
        
    }
    
    func testThatLegalholdIsNotDeactivatedInConversation_WhenParticipantIsRemoved() {
        
    }
    
    // MARK - System messages
    
    func testThatLegalholdSystemMessageIsInserted_WhenUserIsDiscoveredToBeUnderLegalhold() {
        
    }
    
    func testThatLegalholdSystemMessageIsInserted_WhenUserIsNoLongerUnderLegalhold() {
        
    }
    
    // MARK - Discovering legal hold
    
    func testThatItExpiresAllPendingMessages_WhenLegalholdIsDiscovered() {
        
    }
    
    func testItResendsAllPreviouslyExpiredMessages_WhenConfirmingLegalholdPresence() {
        
    }

}
