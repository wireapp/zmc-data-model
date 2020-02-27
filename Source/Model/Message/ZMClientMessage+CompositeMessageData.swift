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

public protocol CompositeMessageData {
    var items: [CompositeMessageItem] { get }
}

public enum CompositeMessageItem {
    case text(ZMTextMessageData)
    case button(ButtonMessageData)
}

public protocol ButtonMessageData {
    var id: UUID { get }
    var title: String { get }
    var state: ButtonMessageState { get }
    func touchAction()
}

public enum ButtonMessageState {
    case notSelected
    case selected
    case confirmed
}

extension ZMClientMessage: CompositeMessageData {
    public var items: [CompositeMessageItem] {
        return []
    }
}
