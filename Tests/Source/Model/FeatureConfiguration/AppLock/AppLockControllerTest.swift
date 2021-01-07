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

import XCTest
import LocalAuthentication
@testable import WireDataModel

final class AppLockControllerTest: ZMBaseManagedObjectTest {
    
    let decoder = JSONDecoder()
    var selfUser: ZMUser!
    var sut: AppLockController!
    
    override func setUp() {
        super.setUp()
        
        selfUser = ZMUser.selfUser(in: uiMOC)
        sut = createAppLockController()
    }
    
    override func tearDown() {
        selfUser = nil
        sut = nil
        
        super.tearDown()
    }

    func testThatForcedAppLockDoesntAffectSettings() {
        
        //given
        sut = createAppLockController(forceAppLock: true)
        XCTAssertTrue(sut.config.forceAppLock)
        
        //when
        XCTAssertTrue(sut.isActive)
        sut.isActive = false
        
        //then
        XCTAssertTrue(sut.isActive)
    }
    
    func testThatAppLockAffectsSettings() {

        //given
        XCTAssertFalse(sut.config.forceAppLock)
        sut.isActive = true

        //when
        XCTAssertTrue(sut.isActive)
        sut.isActive = false

        //then
        XCTAssertFalse(sut.isActive)
    }
    
    
    func testThatBiometricsChangedIsTrueIfDomainStatesDiffer() {
        //given
        UserDefaults.standard.set(Data(), forKey: "DomainStateKey")
        
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: &error)
        
        //when/then
        XCTAssertTrue(BiometricsState.biometricsChanged(in: context))
    }
    
    func testThatBiometricsChangedIsFalseIfDomainStatesDontDiffer() {
        //given
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: &error)
        UserDefaults.standard.set(context.evaluatedPolicyDomainState, forKey: "DomainStateKey")
        
        //when/then
        XCTAssertFalse(BiometricsState.biometricsChanged(in: context))
    }
    
    func testThatBiometricsStatePersistsState() {
        //given
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: &error)
        _ = BiometricsState.biometricsChanged(in: context)
        
        //when
        BiometricsState.persist()
        
        //then
        XCTAssertEqual(context.evaluatedPolicyDomainState, UserDefaults.standard.object(forKey: "DomainStateKey") as? Data)
    }

    func testThatItHonorsTheTeamConfiguration_WhenSelfUserIsATeamUser() {
        
        //given
        XCTAssertFalse(sut.config.forceAppLock)
        XCTAssertTrue(sut.config.isAvailable)
        XCTAssertEqual(sut.config.appLockTimeout, 900)
        
        //when
        let team = createTeam(in: uiMOC)
        _ = createMembership(in: uiMOC, user: selfUser, team: team)
        
        let config = Feature.AppLock.Config.init(enforceAppLock: true, inactivityTimeoutSecs: 30)
        let configData = try? JSONEncoder().encode(config)
        _ = Feature.createOrUpdate(
            name: .appLock,
            status: .disabled,
            config: configData,
            team: team,
            context: uiMOC
        )
        
        //then
        XCTAssertTrue(sut.config.forceAppLock)
        XCTAssertFalse(sut.config.isAvailable)
        XCTAssertEqual(sut.config.appLockTimeout, 30)
    }
    
    func testThatItHonorsForcedAppLockFromTheBaseConfiguration() {
        
        //given
        sut = createAppLockController(forceAppLock: true)
        XCTAssertTrue(sut.config.forceAppLock)
        
        //when
        let team = createTeam(in: uiMOC)
        _ = createMembership(in: uiMOC, user: selfUser, team: team)
        
        let config = Feature.AppLock.Config.init(enforceAppLock: false, inactivityTimeoutSecs: 30)
        let configData = try? JSONEncoder().encode(config)
        _ = Feature.createOrUpdate(
            name: .appLock,
            status: .disabled,
            config: configData,
            team: team,
            context: uiMOC
        )
        
        //then
        XCTAssertTrue(sut.config.forceAppLock)
    }
    
    func testThatItDoesNotHonorTheTeamConfiguration_WhenSelfUserIsNotATeamUser() {
        
        //given
        XCTAssertFalse(sut.config.forceAppLock)
        XCTAssertTrue(sut.config.isAvailable)
        XCTAssertEqual(sut.config.appLockTimeout, 900)
        
        //when
        let team = createTeam(in: uiMOC)
        XCTAssertNil(selfUser.team)
        
        let config = Feature.AppLock.Config.init(enforceAppLock: true, inactivityTimeoutSecs: 30)
        let configData = try? JSONEncoder().encode(config)
        _ = Feature.createOrUpdate(
            name: .appLock,
            status: .disabled,
            config: configData,
            team: team,
            context: uiMOC
        )
        
        //then
        XCTAssertFalse(sut.config.forceAppLock)
        XCTAssertTrue(sut.config.isAvailable)
        XCTAssertNotEqual(sut.config.appLockTimeout, 30)
    }
}

// MARK : Evaluate Authentication

extension AppLockControllerTest {
    
    func testThatCustomPasscodeIsRequested_IfThePolicyCanNotBeEvaluated() {
        //given
        let scenario = AppLockController.AuthenticationScenario.screenLock(requireBiometrics: true)
        XCTAssertEqual(scenario.policy, .deviceOwnerAuthenticationWithBiometrics)
        XCTAssertTrue(scenario.supportsUserFallback)
        
        //when
        sut.evaluateAuthentication(scenario: scenario, description: "evaluate authentication") { (result, context) in
            var error: NSError?
            XCTAssertFalse(context.canEvaluatePolicy(scenario.policy, error: &error))
            
            //then
            XCTAssertEqual(result, .needCustomPasscode)
        }
    }
    
    func testThatCustomPasscodeIsRequested_IfThePolicyCanBeEvaluated_ButBiometricsHaveChanged() {
        //given
        sut = createAppLockController(useBiometricsOrCustomPasscode: true)
        
        let scenario = AppLockController.AuthenticationScenario.screenLock(requireBiometrics: false)
        XCTAssertEqual(scenario.policy, .deviceOwnerAuthentication)
        XCTAssertTrue(scenario.supportsUserFallback)
        
        UserDefaults.standard.set(Data(), forKey: "DomainStateKey")
               
        //when
        let context = LAContext()
        var error: NSError?
        XCTAssertTrue(context.canEvaluatePolicy(scenario.policy, error: &error))
        XCTAssertTrue(BiometricsState.biometricsChanged(in: context))
        XCTAssertTrue(sut.config.useBiometricsOrCustomPasscode)
        
        sut.evaluateAuthentication(scenario: scenario, description: "evaluate authentication") { (result, context) in
            //then
            XCTAssertEqual(result, .needCustomPasscode)
        }
    }
    
    func testThatCustomPasscodeIsNotRequested_IfThePolicyCanBeEvaluatedAndBiometricsHaveChanged_ButConfigValueIsFalse() {
        //given
        let scenario = AppLockController.AuthenticationScenario.screenLock(requireBiometrics: false)
        XCTAssertEqual(scenario.policy, .deviceOwnerAuthentication)
        XCTAssertTrue(scenario.supportsUserFallback)
        XCTAssertFalse(sut.config.useBiometricsOrCustomPasscode)
        
        UserDefaults.standard.set(Data(), forKey: "DomainStateKey")
        
        //when
        let context = LAContext()
        var error: NSError?
        XCTAssertTrue(context.canEvaluatePolicy(scenario.policy, error: &error))
        XCTAssertTrue(BiometricsState.biometricsChanged(in: context))
        
        sut.evaluateAuthentication(scenario: scenario, description: "evaluate authentication") { (result, context) in
            
            //then
            XCTAssertNotEqual(result, .needCustomPasscode)
        }
    }
}

// MARK : Private

extension AppLockControllerTest {
    private func createAppLockController(useBiometricsOrCustomPasscode: Bool = false, forceAppLock: Bool = false, timeOut: UInt = 900) -> AppLockController {
        let config = AppLockController.Config(useBiometricsOrCustomPasscode: useBiometricsOrCustomPasscode,
                                              forceAppLock: forceAppLock,
                                              timeOut: timeOut)
        return AppLockController(config: config, selfUser: selfUser)
    }
}
