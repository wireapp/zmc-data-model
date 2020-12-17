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
@testable import WireDataModel

class TransferApplockKeychain: DiskDatabaseTest {
    
    var selfUser: ZMUser!
    
    override func setUp() {
        super.setUp()
        selfUser = ZMUser.selfUser(in: moc)
    }
    
    override func tearDown() {
        selfUser = nil
        
        super.tearDown()
    }
    
    func testItMigratesIsActiveStateFromTheKeychainToTheMOC() {
        //given
        let config = AppLockController.Config(useBiometricsOrCustomPasscode: false,
                                              forceAppLock: false,
                                              timeOut: 900)
        let sut = AppLockController(config: config, selfUser: selfUser)
        XCTAssertFalse(sut.isActive)
        
        //when
        let data = ("YES").data(using: .utf8)!
        ZMKeychain.setData(data, forAccount: WireDataModel.TransferApplockKeychain.FeatureName.lockApp.rawValue)
        
        WireDataModel.TransferApplockKeychain.migrateIsApplockActiveState(in: moc)
        
        //then
        XCTAssertTrue(sut.isActive)
    }
    
    func testItDoesNotMigrateIsActiveStateFromTheKeychainToTheMOC_IfKeychainIsEmpty() {
        //given
        let config = AppLockController.Config(useBiometricsOrCustomPasscode: false,
                                              forceAppLock: false,
                                              timeOut: 900)
        let sut = AppLockController(config: config, selfUser: selfUser)
        XCTAssertFalse(sut.isActive)
        
        //when
        ZMKeychain.deleteAllKeychainItems(withAccountName: WireDataModel.TransferApplockKeychain.FeatureName.lockApp.rawValue)
        WireDataModel.TransferApplockKeychain.migrateIsApplockActiveState(in: moc)
        
        //then
        XCTAssertFalse(sut.isActive)
    }
}
