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

public final class AppLockController {
    
    private let selfUser: ZMUser
    private let configFromBundle: Config
    
    public var config: Config {
        guard let team = selfUser.team else {
            return configFromBundle
        }
        
        let configFromCoreData = team.feature(for: Feature.AppLock.self)
        let forceAppLock = !configFromBundle.forceAppLock
            ? configFromCoreData.config.enforceAppLock
            : configFromBundle.forceAppLock
        
        return Config(useBiometricsOrAccountPassword: configFromBundle.useBiometricsOrAccountPassword,
                      useCustomCodeInsteadOfAccountPassword: configFromBundle.useCustomCodeInsteadOfAccountPassword,
                                forceAppLock: forceAppLock,
                                timeOut: configFromCoreData.config.inactivityTimeoutSecs)
    }
    
    // Returns true if user enabled the app lock feature or it has been forced by the team manager.
    public var isActive: Bool {
        get {
            guard !config.forceAppLock else { return true }
            guard let data = ZMKeychain.data(forAccount: SettingsPropertyName.lockApp.rawValue),
                data.count != 0 else {
                    return false
            }

            return String(data: data, encoding: .utf8) == "YES"
        }
        set {
            guard !config.forceAppLock else { return }
            let data = (newValue ? "YES" : "NO").data(using: .utf8)!
            ZMKeychain.setData(data, forAccount: SettingsPropertyName.lockApp.rawValue)
        }
    }
    
    // Returns the time since last lock happened.
    public let lastUnlockedDate: Date = Date(timeIntervalSince1970: 0)
    
    /// a weak reference to LAContext, it should be nil when evaluatePolicy is done.
    private weak var weakLAContext: LAContext? = nil 
    
    
    // MARK: - Life cycle
    
    public init(config: Config, selfUser: ZMUser) {
        self.configFromBundle = config
        self.selfUser = selfUser
    }
    
    // MARK: - Methods
    
    // Creates a new LAContext and evaluates the authentication settings of the user.
    public func evaluateAuthentication(scenario: AuthenticationScenario,
                                             description: String,
                                             with callback: @escaping (AuthenticationResult, LAContext) -> Void) {
        guard self.weakLAContext == nil else { return }
        
        let context: LAContext = LAContext()
        var error: NSError?
        
        self.weakLAContext = context
        
        let canEvaluatePolicy = context.canEvaluatePolicy(scenario.policy, error: &error)
        
        if scenario.supportsUserFallback && (BiometricsState.biometricsChanged(in: context) || !canEvaluatePolicy) {
            callback(.needAccountPassword, context)
            return
        }
        
        if canEvaluatePolicy {
            context.evaluatePolicy(scenario.policy, localizedReason: description, reply: { (success, error) -> Void in
                var authResult: AuthenticationResult = success ? .granted : .denied
                
                if scenario.supportsUserFallback, let laError = error as? LAError, laError.code == .userFallback {
                    authResult = .needAccountPassword
                }
                
                callback(authResult, context)
            })
        } else {
            // If the policy can't be evaluated automatically grant access unless app lock
            // is a requirement to run the app. This will for example allow a user to access
            // the app if he/she has disabled his/her passcode.
            callback(scenario.grantAccessIfPolicyCannotBeEvaluated ? .granted : .unavailable, context)
            zmLog.error("Local authentication error: \(String(describing: error?.localizedDescription))")
        }
    }
    
    public func persistBiometrics() {
        BiometricsState.persist()
    }
    
    
    // MARK: - Types
    
    public struct Config {
        public let useBiometricsOrAccountPassword: Bool
        public let useCustomCodeInsteadOfAccountPassword: Bool
        public var forceAppLock: Bool
        public var appLockTimeout: UInt
        
        public init(useBiometricsOrAccountPassword: Bool,
                    useCustomCodeInsteadOfAccountPassword: Bool,
                    forceAppLock: Bool,
                    timeOut: UInt) {
            self.useBiometricsOrAccountPassword = useBiometricsOrAccountPassword
            self.useCustomCodeInsteadOfAccountPassword = useCustomCodeInsteadOfAccountPassword
            self.forceAppLock = forceAppLock
            self.appLockTimeout = timeOut
        }
    }
    
    public enum AuthenticationResult {
        /// User sucessfully authenticated
        case granted
        /// User failed to authenticate or cancelled the request
        case denied
        /// There's no authenticated method available (no passcode is set)
        case unavailable
        /// Biometrics failed and account password is needed instead of device PIN
        case needAccountPassword
    }
    
    public enum AuthenticationScenario {
        case screenLock(requireBiometrics: Bool, grantAccessIfPolicyCannotBeEvaluated: Bool)
        case databaseLock
        
        var policy: LAPolicy {
            switch self {
            case .screenLock(requireBiometrics: let requireBiometrics, grantAccessIfPolicyCannotBeEvaluated: _):
                return requireBiometrics ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
            case .databaseLock:
                return .deviceOwnerAuthentication
                
            }
        }
        
        var supportsUserFallback: Bool {
            if case .screenLock(requireBiometrics: true, grantAccessIfPolicyCannotBeEvaluated: _) = self {
                return true
            }
            
            return false
        }
        
        var grantAccessIfPolicyCannotBeEvaluated: Bool {
            if case .screenLock(requireBiometrics: _, grantAccessIfPolicyCannotBeEvaluated: true) = self {
                return true
            }
            
            return false
        }
        
    }
    
    private enum SettingsPropertyName: String {
         case lockApp = "lockApp"
    }
}

public class BiometricsState {
    private static let UserDefaultsDomainStateKey = "DomainStateKey"
    
    private static var lastPolicyDomainState: Data? {
        get {
            return UserDefaults.standard.data(forKey: UserDefaultsDomainStateKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsDomainStateKey)
        }
    }
    
    private static var currentPolicyDomainState: Data?
    
    // Tells us if biometrics database has changed (ex: fingerprints added or removed)
    public static func biometricsChanged(in context: LAContext) -> Bool {
        currentPolicyDomainState = context.evaluatedPolicyDomainState
        guard let currentState = currentPolicyDomainState,
            let lastState = lastPolicyDomainState,
            currentState == lastState else {
                return true
        }
        return false
    }
    
    /// Persists the state of the biometric credentials.
    /// Should be called after a successful unlock with account password
    public static func persist() {
        lastPolicyDomainState = currentPolicyDomainState
    }
}
