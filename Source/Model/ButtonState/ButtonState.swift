//
//  ButtonState.swift
//  WireDataModel
//
//  Created by David Henner on 05.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

final public class ButtonState: ZMManagedObject {
    @NSManaged public var identifier: UUID?
    @NSManaged public var stateValue: Int16
    @NSManaged public var message: ZMMessage?
    
    enum State: Int16 {
        case unselected
        case selected
        case confirmed
    }
    
    var state: State {
        get {
            return State(rawValue: stateValue) ?? .unselected
        }
        set {
            stateValue = newValue.rawValue
        }
    }
}
