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

public final class AppLockController: AppLockType {

    static let log = ZMSLog(tag: "AppLockController")

    // MARK: - Properties

    public weak var delegate: AppLockDelegate?

    public var isAvailable: Bool {
        return config.isAvailable
    }

    public var isActive: Bool {
        get {
            return isForced || selfUser.isAppLockActive
        }

        set {
            guard !isForced else { return }
            selfUser.isAppLockActive = newValue
        }
    }

    public var isForced: Bool {
        return config.isForced
    }

    public var timeout: UInt {
        return config.timeout
    }

    public var isLocked: Bool {
        guard isActive else { return false }
        let timeSinceAuth = -lastUnlockedDate.timeIntervalSinceNow
        let timeoutWindow = 0..<Double(timeout)
        return !timeoutWindow.contains(timeSinceAuth)
    }

    public var requireCustomPasscode: Bool {
        return config.requireCustomPasscode
    }

    public var isCustomPasscodeSet: Bool {
        return fetchPasscode() != nil
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

    // MARK: - Private properties

    private let selfUser: ZMUser

    /// TODO: [John] We need to update this whenever we go to BG or change sessions.

    private var lastUnlockedDate = Date.distantPast

    let keychainItem: PasscodeKeychainItem

    var biometricsState: BiometricsStateProtocol = BiometricsState()

    private let baseConfig: Config

    private var config: Config {
        guard let team = selfUser.team else { return baseConfig }

        let feature = team.feature(for: Feature.AppLock.self)

        var result = baseConfig
        result.isForced = baseConfig.isForced || feature.config.enforceAppLock
        result.timeout = feature.config.inactivityTimeoutSecs
        result.isAvailable = (feature.status == .enabled)

        return result
    }

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

    // MARK: - Authentication

    public func evaluateAuthentication(passcodePreference: AppLockPasscodePreference,
                                       description: String,
                                       context: LAContextProtocol = LAContext(),
                                       callback: @escaping (AppLockAuthenticationResult, LAContextProtocol) -> Void) {
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
            Self.log.error("Local authentication error: \(String(describing: error?.localizedDescription))")
            return
        }

        context.evaluatePolicy(policy, localizedReason: description) { success, error in
            var result: AppLockAuthenticationResult = success ? .granted : .denied

            if let laError = error as? LAError, laError.code == .userFallback, passcodePreference.allowsCustomPasscode {
                result = .needCustomPasscode
            }

            if result == .granted {
                self.lastUnlockedDate = Date()
            }

            callback(result, context)
        }
    }

    public func evaluateAuthentication(customPasscode: String) -> AppLockAuthenticationResult {
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

    // MARK: - Passcode management

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
    
}

