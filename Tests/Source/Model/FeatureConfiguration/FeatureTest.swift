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

final class FeatureTest: ZMBaseManagedObjectTest {
    
    let config = AppLockConfig(enforceAppLock: true,
                               inactivityTimeoutSecs: 30)
    
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }
    
    func testThatCreateOrUpdate_FetchesAnExistingRole() {
        // given
       // let feature = Feature<AppLockConfig>.fetch(with: .applock, context: uiMOC)
        let feature1 = Feature<AppLockConfig>.insert(with: .applock,
                                                     status: true,
                                                     config: config,
                                                     context: uiMOC)
//        let feature = Feature.createOrUpdate(with: .applock,
//                                             status: true,
//                                             config: config,
//                                             context: syncMOC)
//
//        // when
//        let fetchedFeature = Feature.createOrUpdate(with: .applock,
//                                                    status: true,
//                                                    config: config,
//                                                    context: syncMOC)
//
//        // then
//        XCTAssertEqual(feature, fetchedFeature)
    }
}
