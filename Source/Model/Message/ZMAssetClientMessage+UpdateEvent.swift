//
//  ZMAssetClientMessage+UpdateEvent.swift
//  WireDataModel
//
//  Created by David Henner on 26.03.20.
//  Copyright © 2020 Wire Swiss GmbH. All rights reserved.
//

import Foundation

extension ZMAssetClientMessage {
    override open func update(with updateEvent: ZMUpdateEvent, initialUpdate: Bool) {
        guard let message = ZMGenericMessage(from: updateEvent) else {
            return
        }
        update(with: message, updateEvent: updateEvent, initialUpdate: initialUpdate)
    }
}
