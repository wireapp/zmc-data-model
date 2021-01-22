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

final class AppLockControllerTests: ZMBaseManagedObjectTest {

    var selfUser: ZMUser!

    override func setUp() {
        super.setUp()
        selfUser = ZMUser.selfUser(in: uiMOC)
        selfUser.remoteIdentifier = .create()
    }
    
    override func tearDown() {
        selfUser = nil
        super.tearDown()
    }

    // MARK: - Configuration merging

    func test_ItCantBeTurnedOff_WhenItIsForced() {
        // Given
        let sut = createAppLockController(isForced: true)
        XCTAssertTrue(sut.isActive)

        // When
        sut.isActive = false
        
        // Then
        XCTAssertTrue(sut.isActive)
    }
    
    func test_ItCanBeTurnedOff_WhenItIsNotForced() {
        // Given
        let sut = createAppLockController(isForced: false)

        sut.isActive = true
        XCTAssertTrue(sut.isActive)

        // When
        sut.isActive = false

        // Then
        XCTAssertFalse(sut.isActive)
    }

    func test_ItHonorsTheTeamConfiguration_WhenSelfUserIsATeamUser() {
        // Given
        let sut = createAppLockController(isAvailable: true, isForced: false, timeout: 10)
        createTeamConfiguration(isAvailable: false, isForced: true, timeout: 30)

        // Then
        XCTAssertFalse(sut.isAvailable)
        XCTAssertTrue(sut.isForced)
        XCTAssertEqual(sut.timeout, 30)
    }

    func test_ItCanBeForced_EvenIfTheTeamConfigurationDoesntEnforceIt() {
        // Given
        let sut = createAppLockController(isForced: true)
        createTeamConfiguration(isForced: false)

        // Then
        XCTAssertTrue(sut.isForced)
    }

    // MARK: - Evaluate Authentication

    func test_ItEvaluatesAuthentication() {
        assert(
            input: (passcodePreference: .customOnly, canEvaluate: true, biometricsChanged: true),
            output: .needCustomPasscode
        )

        assert(
            input: (passcodePreference: .customOnly, canEvaluate: false, biometricsChanged: true),
            output: .needCustomPasscode
        )

        assert(
            input: (passcodePreference: .customOnly, canEvaluate: false, biometricsChanged: false),
            output: .needCustomPasscode
        )

        assert(
            input: (passcodePreference: .deviceThenCustom, canEvaluate: true, biometricsChanged: false),
            output: .granted
        )

        performIgnoringZMLogError {
            self.assert(
                input: (passcodePreference: .deviceThenCustom, canEvaluate: false, biometricsChanged: false),
                output: .needCustomPasscode
            )
        }

        performIgnoringZMLogError {
            self.assert(
                input: (passcodePreference: .deviceOnly, canEvaluate: false, biometricsChanged: false),
                output: .unavailable
            )
        }
    }

}

// MARK: - Helpers

extension AppLockControllerTests {

    typealias Input = (passcodePreference: AppLockPasscodePreference, canEvaluate: Bool, biometricsChanged: Bool)
    typealias Output = AppLockAuthenticationResult
    
    private func assert(input: Input, output: Output, file: StaticString = #file, line: UInt = #line) {
        let sut = createAppLockController()
        let context = MockLAContext(canEvaluate: input.canEvaluate)
        sut.biometricsState = MockBiometricsState(didChange: input.biometricsChanged)

        let assertion: (Output, LAContextProtocol) -> Void = { result, _ in
            XCTAssertEqual(result, output, file: file, line: line)
        }
        
        sut.evaluateAuthentication(passcodePreference: input.passcodePreference,
                                   description: "",
                                   context: context,
                                   callback: assertion)
    }
    
    private func createAppLockController(isAvailable: Bool = true,
                                         isForced: Bool = false,
                                         timeout: UInt = 900,
                                         requireCustomPasscode: Bool = false) -> AppLockController {

        let config = AppLockController.Config(isAvailable: isAvailable,
                                              isForced: isForced,
                                              timeout: timeout,
                                              requireCustomPasscode: requireCustomPasscode
        )

        return AppLockController(userId: selfUser.remoteIdentifier, config: config, selfUser: selfUser)
    }

    private func createTeamConfiguration(isAvailable: Bool = true, isForced: Bool = false, timeout: UInt = 30) {
        let team = createTeam(in: uiMOC)
        _ = createMembership(in: uiMOC, user: selfUser, team: team)

        let config = Feature.AppLock.Config.init(enforceAppLock: isForced, inactivityTimeoutSecs: timeout)
        let configData = try? JSONEncoder().encode(config)

        _ = Feature.createOrUpdate(name: .appLock,
                                   status: isAvailable ? .enabled : .disabled,
                                   config: configData,
                                   team: team,
                                   context: uiMOC)
    }

}
