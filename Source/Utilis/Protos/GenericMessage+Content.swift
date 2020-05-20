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
    
    var hasDeleted: Bool {
        guard let content = content else { return false }
        switch content {
        case .deleted:
            return true
        default:
            return false
        }
    }
    
    var hasCalling: Bool {
        guard let content = content else { return false }
        switch content {
        case .calling:
            return true
        default:
            return false
        }
    }
    
    var hasHidden: Bool {
        guard let content = content else { return false }
        switch content {
        case .hidden:
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
