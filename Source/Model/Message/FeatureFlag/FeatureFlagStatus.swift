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

// MARK: - FeatureFlagObserver
@objc(ZMFeatureFlagObserver)
public protocol FeatureFlagObserver: NSObjectProtocol {
    func didReceiveSignatureFeatureFlag(_ flag: Bool)
    func didFailSignatureFeatureFlag()
}

// MARK: - FeatureFlagState
public enum FeatureFlagState {
    case none
    case digitalSignature
    case digitalSignatureFail
    case digitalSignatureSuccess
}

@objc
public final class FeatureFlagStatus: NSObject {
    
    // MARK: - Private Property
    private(set) var managedObjectContext: NSManagedObjectContext

    // MARK: - Public Property
    public var state: FeatureFlagState = .none
    public var teamId: String?
    
    // MARK: - Init
    public init(teamId: String?,
                managedObjectContext: NSManagedObjectContext) {
        self.teamId = teamId
        self.managedObjectContext = managedObjectContext
    }
    
    // MARK: - Public Method
    public func getDigitalSignatureFeatureFlag() {
        guard teamId != nil else {
            return
        }
        state = .digitalSignature
        RequestAvailableNotification.notifyNewRequestsAvailable(nil)
    }
    
    public func didReceiveSignatureFeatureFlag(_ flag: Bool) {
        state = .digitalSignatureSuccess
        FeatureFlagNotification(state: .signatureFeatureFlagReceived(flag))
            .post(in: managedObjectContext.notificationContext)
    }
    
    public func didReceiveSignatureFeatureFlagError() {
        state = .digitalSignatureFail
        FeatureFlagNotification(state: .signatureFeatureFlagInvalid)
            .post(in: managedObjectContext.notificationContext)
    }
}

// MARK: - Observable
public extension FeatureFlagStatus {
    static func addObserver(_ observer: FeatureFlagObserver,
                            context: NSManagedObjectContext) -> Any {
        return NotificationInContext.addObserver(name: FeatureFlagNotification.notificationName,
                                                 context: context.notificationContext,
                                                 queue: .main) { [weak observer] note in
            if let note = note.userInfo[FeatureFlagNotification.userInfoKey] as? FeatureFlagNotification  {
                switch note.state {
                case let .signatureFeatureFlagReceived(flag):
                    observer?.didReceiveSignatureFeatureFlag(flag)
                case .signatureFeatureFlagInvalid:
                    observer?.didFailSignatureFeatureFlag()
                }
            }
        }
    }
}

// MARK: - FeatureFlagNotification
public class FeatureFlagNotification: NSObject  {
    
    // MARK: - State
    public enum State {
        case signatureFeatureFlagReceived(_ flag: Bool)
        case signatureFeatureFlagInvalid
    }
    
    // MARK: - Public Property
    public static let notificationName = Notification.Name("FeatureFlagNotification")
    public static let userInfoKey = notificationName.rawValue
    
    public let state: State
    
    // MARK: - Init
    public init(state: State) {
        self.state = state
        super.init()
    }
    
    // MARK: - Public Method
    public func post(in context: NotificationContext) {
        NotificationInContext(name: FeatureFlagNotification.notificationName,
                              context: context,
                              userInfo: [FeatureFlagNotification.userInfoKey: self]).post()
    }
}

// MARK: - NSManagedObjectContext
extension NSManagedObjectContext {
    private static let featureFlagStatusKey = "FeatureFlagStatus"
    
    @objc public var featureFlagStatus: FeatureFlagStatus? {
        get {
            precondition(zm_isSyncContext, "featureFlagStatus can only be accessed on the sync context")
            return self.userInfo[NSManagedObjectContext.featureFlagStatusKey] as? FeatureFlagStatus
        }
        set {
            precondition(zm_isSyncContext, "featureFlagStatus can only be accessed on the sync context")
            self.userInfo[NSManagedObjectContext.featureFlagStatusKey] = newValue
        }
    }
}
