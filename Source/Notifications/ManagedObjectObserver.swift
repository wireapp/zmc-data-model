//
//  ManagedObjectObserver.swift
//  WireDataModel
//
//  Created by Silvan Dähn on 26.06.17.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//


import Foundation


@objc final public class ManagedObjectContextChangeObserver: NSObject {

    public typealias ChangeCallback = () -> Void
    private unowned var context: NSManagedObjectContext
    private let callback: ChangeCallback
    private var token: NSObjectProtocol?

    public init(context: NSManagedObjectContext, callback: @escaping ChangeCallback) {
        self.context = context
        self.callback = callback
        super.init()
        addSaveNotificationObsever()
    }

    private func addSaveNotificationObsever() {
        token = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: nil,
            using: {  [weak self] _ in self?.callback() }
        )
    }

    deinit {
        guard let token = token else { return }
        NotificationCenter.default.removeObserver(token)
    }

}
