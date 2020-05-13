//
//  GenericMessage+Content.swift
//  WireDataModel
//
//  Created by David Henner on 12.05.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

// MARK: - GenericMessage

public extension GenericMessage {
    var hasText: Bool {
        guard let content = content else { return false }
        switch content {
        case .text:
            return true
        default:
            return false
        }
    }
    
    var hasConfirmation: Bool {
        guard let content = content else { return false }
        switch content {
        case .confirmation:
            return true
        default:
            return false
        }
    }
    
    var hasReaction: Bool {
        guard let content = content else { return false }
        switch content {
        case .reaction:
            return true
        default:
            return false
        }
    }
    
    var hasAsset: Bool {
        guard let content = content else { return false }
        switch content {
        case .asset:
            return true
        default:
            return false
        }
    }
    
    var hasEphemeral: Bool {
        guard let content = content else { return false }
        switch content {
        case .ephemeral:
            return true
        default:
            return false
        }
    }
    
    var hasClientAction: Bool {
        guard let content = content else { return false }
        switch content {
        case .clientAction:
            return true
        default:
            return false
        }
    }
    
    var hasCleared: Bool {
        guard let content = content else { return false }
        switch content {
        case .cleared:
            return true
        default:
            return false
        }
    }
    
    var hasLastRead: Bool {
        guard let content = content else { return false }
        switch content {
        case .lastRead:
            return true
        default:
            return false
        }
    }
    
    var hasKnock: Bool {
        guard let content = content else { return false }
        switch content {
        case .knock:
            return true
        default:
            return false
        }
    }
    
    var hasExternal: Bool {
        guard let content = content else { return false }
        switch content {
        case .external:
            return true
        default:
            return false
        }
    }
    
    var hasAvailability: Bool {
        guard let content = content else { return false }
        switch content {
        case .availability:
            return true
        default:
            return false
        }
    }
    
    var hasEdited: Bool {
        guard let content = content else { return false }
        switch content {
        case .edited:
            return true
        default:
            return false
        }
    }
}

// MARK: - Ephemeral

public extension Ephemeral {
    var hasAsset: Bool {
        switch content {
        case .asset:
            return true
        default:
            return false
        }
    }
    
    var hasKnock: Bool {
        switch content {
        case .knock:
            return true
        default:
            return false
        }
    }
    
    var hasLocation: Bool {
        switch content {
        case .location:
            return true
        default:
            return false
        }
    }
    
    var hasText: Bool {
        switch content {
        case .text:
            return true
        default:
            return false
        }
    }
}
