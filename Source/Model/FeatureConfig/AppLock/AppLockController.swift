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
import LocalAuthentication

private let zmLog = ZMSLog(tag: "AppLockController")

public protocol LAContextProtocol {

    var evaluatedPolicyDomainState: Data? { get }

    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void)
}

extension LAContext: LAContextProtocol {}

public protocol AppLockType {

    var delegate: AppLockDelegate? { get set }

    /// Whether the app lock feature is availble to the user.

    var isAvailable: Bool { get }

    /// Whether the app lock on.

    var isActive: Bool { get set }

    /// Whether the app lock is mandatorily active.

    var isForced: Bool { get }

    /// The maximum number of seconds allowed in the background before the
    /// authentication is required.

    var timeout: UInt { get }

    /// Whether the app lock is currently locked.

    var isLocked: Bool { get }


    // TODO: revisit this. It's purpose is to communicate that
    // the preferred passcode is custom not device.

    var requiresBiometrics: Bool { get }

    // TODO: Rename to "isCustomPasscodeSet"
    /// Whether a custom passcode has been set.

    var isCustomPasscodeNotSet: Bool { get }

    /// Whether the user needs to be informed about configuration changes.

    var needsToNotifyUser: Bool { get set }

    /// Open the app lock.

    func open() throws

    // TODO: document

    func evaluateAuthentication(passcodePreference: AppLockPasscodePreference,
                                description: String,
                                context: LAContextProtocol,
                                callback: @escaping (AppLockController.AuthenticationResult, LAContextProtocol) -> Void)

    /// Delete the stored passcode.

    func deletePasscode() throws

    /// Update the stored passcode.

    func updatePasscode(_ passcode: String) throws

    // TODO: Document

    func evaluateAuthentication(customPasscode: String) -> AppLockController.AuthenticationResult

}

public extension AppLockType {

    func evaluateAuthentication(passcodePreference: AppLockPasscodePreference,
                                description: String,
                                callback: @escaping (AppLockController.AuthenticationResult, LAContextProtocol) -> Void) {

        evaluateAuthentication(passcodePreference: passcodePreference,
                               description: description,
                               context: LAContext(),
                               callback: callback)
    }
}

public final class AppLockController: AppLockType {

    // MARK: - Properties

    public weak var delegate: AppLockDelegate?

    public var isActive: Bool {
        get {
            return config.forceAppLock || selfUser.isAppLockActive
        }

        set {
            guard !config.forceAppLock else { return }
            selfUser.isAppLockActive = newValue
        }
    }

    public var isLocked: Bool {
        guard isActive else { return false }
        let timeSinceAuth = -lastUnlockedDate.timeIntervalSinceNow
        let timeoutWindow = 0..<Double(config.appLockTimeout)
        return !timeoutWindow.contains(timeSinceAuth)
    }

    public var isCustomPasscodeNotSet: Bool {
        return fetchPasscode() == nil
    }

    public var requiresBiometrics: Bool {
        return config.useBiometricsOrCustomPasscode
    }

    public var needsToNotifyUser: Bool {
        get {
            guard let feature = selfUser.team?.feature(for: .appLock) else { return false }
            return feature.needsToNotifyUser
        }

        set {
            guard let feature = selfUser.team?.feature(for: .appLock) else { return }
            feature.needsToNotifyUser =  newValue
        }
    }

    public var timeout: UInt {
        return config.appLockTimeout
    }

    public var isForced: Bool {
        return config.forceAppLock
    }

    public var isAvailable: Bool {
        return config.isAvailable
    }


    // MARK: - Private properties

    private let selfUser: ZMUser
    private let baseConfig: Config

    private var config: Config {
        guard let team = selfUser.team else { return baseConfig }
        
        let feature = team.feature(for: Feature.AppLock.self)
        
        var result = baseConfig
        result.forceAppLock = baseConfig.forceAppLock || feature.config.enforceAppLock
        result.appLockTimeout = feature.config.inactivityTimeoutSecs
        result.isAvailable = (feature.status == .enabled)
        
        return result
    }

    let biometricsState: BiometricsStateProtocol = BiometricsState()

    /// TODO: [John] We need to update this whenever we go to BG or change sessions.

    private var lastUnlockedDate = Date.distantPast

    /// a weak reference to LAContext, it should be nil when evaluatePolicy is done.
    private weak var weakLAContext: LAContext? = nil 

    let keychainItem: PasscodeKeychainItem
    
    // MARK: - Life cycle
    
    public init(userId: UUID, config: Config, selfUser: ZMUser) {
        precondition(selfUser.isSelfUser, "AppLockController initialized with non-self user")

        // It's safer use userId rather than selfUser.remoteIdentifier!
        self.keychainItem = PasscodeKeychainItem(userId: userId)
        self.baseConfig = config
        self.selfUser = selfUser
    }
    
    // MARK: - Methods

    /// Open the app lock.
    ///
    /// This method informs the delegate that the app lock opened. The delegate should
    /// then react appropriately by transitioning away from the app lock UI.
    ///
    /// - Throws: AppLockError

    public func open() throws {
        guard !isLocked else { throw AppLockError.authenticationNeeded }
        delegate?.appLockDidOpen(self)
    }

    public func evaluateAuthentication(passcodePreference: AppLockPasscodePreference,
                                       description: String,
                                       context: LAContextProtocol = LAContext(),
                                       callback: @escaping (AuthenticationResult, LAContextProtocol) -> Void) {
        let policy = passcodePreference.policy
        var error: NSError?
        let canEvaluatePolicy = context.canEvaluatePolicy(policy, error: &error)

        // Changing biometrics in device settings is protected by the device passcode, but if
        // the device passcode isn't considered secure enough, then ask for the custon passcode
        // to accept the new biometrics state.
        if biometricsState.biometricsChanged(in: context) && !passcodePreference.allowsDevicePasscode {
            callback(.needCustomPasscode, context)
            return
        }

        // No device authentication possible, but can fall back to the custom passcode.
        if !canEvaluatePolicy && passcodePreference.allowsCustomPasscode {
            callback(.needCustomPasscode, context)
            return
        }

        guard canEvaluatePolicy else {
            callback(.unavailable, context)
            zmLog.error("Local authentication error: \(String(describing: error?.localizedDescription))")
            return
        }

        context.evaluatePolicy(policy, localizedReason: description) { success, error in
            var result: AuthenticationResult = success ? .granted : .denied

            if let laError = error as? LAError, laError.code == .userFallback, passcodePreference.allowsCustomPasscode {
                result = .needCustomPasscode
            }

            if result == .granted {
                self.lastUnlockedDate = Date()
            }

            callback(result, context)
        }
    }

    public func evaluateAuthentication(customPasscode: String) -> AuthenticationResult {
        guard
            let storedPasscode = fetchPasscode(),
            let passcode = customPasscode.data(using: .utf8),
            passcode == storedPasscode
        else {
            return .denied
        }

        lastUnlockedDate = Date()
        biometricsState.persistState()
        return .granted
    }

    public func updatePasscode(_ passcode: String) throws {
        try deletePasscode()
        try storePasscode(passcode)
    }

    public func deletePasscode() throws {
        try Keychain.deleteItem(keychainItem)
    }

    private func storePasscode(_ passcode: String) throws {
        try Keychain.storeItem(keychainItem, value: passcode.data(using: .utf8)!)
    }

    private func fetchPasscode() -> Data? {
        return try? Keychain.fetchItem(keychainItem)
    }
    
    // MARK: - Types
    
    public struct Config {
        public let useBiometricsOrCustomPasscode: Bool
        public var forceAppLock: Bool
        public var appLockTimeout: UInt
        public var isAvailable: Bool
        
        public init(useBiometricsOrCustomPasscode: Bool,
                    forceAppLock: Bool,
                    timeOut: UInt) {
            self.useBiometricsOrCustomPasscode = useBiometricsOrCustomPasscode
            self.forceAppLock = forceAppLock
            self.appLockTimeout = timeOut
            self.isAvailable = true
        }
    }

    public enum AuthenticationResult {
        /// User sucessfully authenticated
        case granted
        /// User failed to authenticate or cancelled the request
        case denied
        /// There's no authenticated method available (no passcode is set)
        case unavailable
        /// Biometrics failed and custom passcode is needed
        case needCustomPasscode
    }

}

