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

    func testThatForcedAppLockDoesntAffectSettings() {
        
        //given
        let config = AppLockController.Config(useBiometricsOrAccountPassword: false,
                                              useCustomCodeInsteadOfAccountPassword: false,
                                              forceAppLock: true,
                                              appLockTimeout: 900)
        let sut = AppLockController(config: config)
        XCTAssertTrue(sut.config.forceAppLock)
        
        //when
        XCTAssertTrue(sut.isActive)
        sut.isActive = false
        
        //then
        XCTAssertTrue(sut.isActive)
    }
    
    func testThatAppLockAffectsSettings() {

        //given
        let config = AppLockController.Config(useBiometricsOrAccountPassword: false,
                                              useCustomCodeInsteadOfAccountPassword: false,
                                              forceAppLock: false,
                                              appLockTimeout: 10)
        let sut = AppLockController(config: config)
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

}

