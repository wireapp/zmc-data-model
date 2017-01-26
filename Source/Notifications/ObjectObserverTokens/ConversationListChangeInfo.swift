//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import ZMCSystem

extension ZMConversationList {
    
    func toOrderedSet() -> NSOrderedSet {
        return NSOrderedSet(array: self.map{$0})
    }
    
}

@objc public final class ConversationListChangeInfo : SetChangeInfo {
    
    public var conversationList : ZMConversationList { return self.observedObject as! ZMConversationList }
    
    init(setChangeInfo: SetChangeInfo) {
        super.init(observedObject: setChangeInfo.observedObject, changeSet: setChangeInfo.changeSet)
    }
}



//@objc public protocol ZMConversationListObserverOpaqueToken : NSObjectProtocol {}

@objc public protocol ZMConversationListObserver : NSObjectProtocol {
    func conversationListDidChange(_ changeInfo: ConversationListChangeInfo)
    @objc optional func conversationInsideList(_ list: ZMConversationList, didChange changeInfo: ConversationChangeInfo)
}

extension ConversationListChangeInfo {

    @objc(addObserver:forList:)
    public static func add(observer: ZMConversationListObserver,for list: ZMConversationList) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .ZMConversationListDidChange,
                                                      object: list,
                                                      queue: nil)
        { [weak observer] (note) in
            guard let `observer` = observer, let list = note.object as? ZMConversationList
                else { return }
            
            if let changeInfo = note.userInfo?["conversationListChangeInfo"] as? ConversationListChangeInfo{
                observer.conversationListDidChange(changeInfo)
            }
            if let changeInfo = note.userInfo?["conversationChangeInfo"] as? ConversationChangeInfo {
                observer.conversationInsideList?(list, didChange: changeInfo)
            }
        }
    }
    
    @objc(removeObserver:forList:)
    public static func remove(observer: NSObjectProtocol, for list: ZMConversationList?) {
        NotificationCenter.default.removeObserver(observer, name: .ZMConversationListDidChange, object: list)
    }
}
