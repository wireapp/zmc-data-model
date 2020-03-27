//
//  ZMMessage+Conversation.swift
//  WireDataModel
//
//  Created by David Henner on 27.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMMessage {
    var isSenderInConversation: Bool {
        return conversation?.has(participantWithId: sender?.userId) ?? false
    }
}
