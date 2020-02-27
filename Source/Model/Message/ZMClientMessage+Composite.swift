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
    
    internal init?(with protoItem: CompositeMessage.Item, message: ZMClientMessage) {
        guard let content = protoItem.content else { return nil }
        let itemContent = CompositeMessageItemContent(with: protoItem, message: message)
        switch content {
        case .button:
            self = .button(itemContent)
        case .text:
            self = .text(itemContent)
        }
    }
}

public protocol ButtonMessageData {
    var title: String? { get }
    var state: ButtonMessageState { get }
    func touchAction()
}

public enum ButtonMessageState {
    case unselected
    case selected
    case confirmed
}

extension ZMClientMessage: CompositeMessageData {
    public var items: [CompositeMessageItem] {
        guard let message = underlyingMessage, case .some(.compositeMessage) = message.content else {
            return []
        }
        var items = [CompositeMessageItem]()
        for protoItem in message.compositeMessage.items {
            guard let compositeMessageItem = CompositeMessageItem(with: protoItem, message: self) else { continue }
            items += [compositeMessageItem]
        }
        return items
    }
}

extension ZMClientMessage: ConversationCompositeMessage {
    public var compositeMessageData: CompositeMessageData? {
        guard case .some(.compositeMessage) = underlyingMessage?.content else {
            return nil
        }
        return self
    }
}

fileprivate class CompositeMessageItemContent: NSObject {
    private let parentMessage: ZMClientMessage
    private let item: CompositeMessage.Item
    
    private var text: Text? {
        guard case .some(.text) = item.content else { return nil }
        return item.text
    }
    
    private var button: Button? {
        guard case .some(.button) = item.content else { return nil }
        return item.button
    }
    
    init(with item: CompositeMessage.Item, message: ZMClientMessage) {
        self.item = item
        self.parentMessage = message
    }
}

extension CompositeMessageItemContent: ZMTextMessageData {
    var messageText: String? {
        return text?.content.removingExtremeCombiningCharacters
    }
    
    var linkPreview: LinkMetadata? {
        return nil
    }
    
    var mentions: [Mention] {
        return Mention.mentions(from: text?.mentions, messageText: messageText, moc: parentMessage.managedObjectContext)
    }
    
    var quote: ZMMessage? {
        return nil
    }
    
    var linkPreviewHasImage: Bool {
        return false
    }
    
    var linkPreviewImageCacheKey: String? {
        return nil
    }
    
    var isQuotingSelf: Bool {
        return false
    }
    
    var hasQuote: Bool {
        return false
    }
    
    func fetchLinkPreviewImageData(with queue: DispatchQueue, completionHandler: @escaping (Data?) -> Void) {
        // no op
    }
    
    func requestLinkPreviewImageDownload() {
        // no op
    }
    
    func editText(_ text: String, mentions: [Mention], fetchLinkPreview: Bool) {
        // no op
    }
}

extension CompositeMessageItemContent: ButtonMessageData {
    var title: String? {
        return button?.text
    }
    
    var state: ButtonMessageState {
        // TODO: Get message state from database
        return .unselected
    }
    
    func touchAction() {
        // TODO:
        // 1. Update button state
        // 2. Insert ButtonAction as silent message in conversation with service as a recipient
        // 3. Save changes
    }
}
