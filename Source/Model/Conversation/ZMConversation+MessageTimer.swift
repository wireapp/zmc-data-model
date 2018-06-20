//
//  ZMConversation+MessageTimer.swift
//  WireDataModel
//
//  Created by Nicola Giancecchi on 19.06.18.
//  Copyright © 2018 Wire Swiss GmbH. All rights reserved.
//

import UIKit

extension ZMConversation {
    
    @objc public func appendMessageTimerUpdateMessage(fromUser user: ZMUser, with duration: Int) -> ZMSystemMessage {
        let (message, index) = appendSystemMessage(
            type: .missedCall,
            sender: user,
            users: [user],
            clients: nil,
            timestamp: timestamp
        )
        
        if isArchived && !isSilenced {
            isArchived = false
        }
        
        if let previous = associatedMessage(before: message, at: index) {
            previous.addChild(message)
        }
        
        managedObjectContext?.enqueueDelayedSave()
        return message
    }
    
}
