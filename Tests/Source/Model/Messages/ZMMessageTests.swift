//
//  ZMMessageTests.swift
//  WireDataModelTests
//
//  Created by Bill, Yiu Por Chan on 28.05.21.
//  Copyright © 2021 Wire Swiss GmbH. All rights reserved.
//

import XCTest
@testable import WireDataModel

//extension ZMMessageTests {
//    func mockEventOf(_ type: ZMUpdateEventType, for conversation: ZMConversation?, sender senderID: UUID?, data: [AnyHashable : Any]?) -> Any? {
//        let updateEvent = OCMockObject.niceMock(for: ZMUpdateEvent.self)
////        (updateEvent?.stub().andReturnValue(OCMOCK_VALUE(type)) as? ZMUpdateEvent)?.type()
////        let serverTimeStamp: Date? = (conversation?.lastServerTimeStamp ? conversation?.lastServerTimeStamp.addingTimeInterval(5) : Date()) as? Date
////        let from = senderID ?? NSUUID.createUUID
////        var payload: [StringLiteralConvertible : UnknownType?]? = nil
////        if let transportString = conversation?.remoteIdentifier.transportString, let transportString1 = serverTimeStamp?.transportString, let transportString2 = from?.transportString, let data = data {
////            payload = [
////                "conversation": transportString,
////                "time": transportString1,
////                "from": transportString2,
////                "data": data
////            ]
////        }
////        (updateEvent?.stub().andReturn(payload) as? ZMUpdateEvent)?.payload()
//
//        let nonce = UUID()
//        ((updateEvent? as AnyObject).stub().andReturn(nonce) as? ZMUpdateEvent)?.messageNonce
////        (updateEvent?.stub().andReturn(serverTimeStamp) as? ZMUpdateEvent)?.timestamp()
////        (updateEvent?.stub().andReturn(conversation?.remoteIdentifier) as? ZMUpdateEvent)?.conversationUUID()
////        (updateEvent?.stub().andReturn(from) as? ZMUpdateEvent)?.senderUUID()
//        return updateEvent
//    }
//}
