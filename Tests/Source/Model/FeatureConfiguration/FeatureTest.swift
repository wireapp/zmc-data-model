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
    
    let config: Data = {
      let json = """
      {
        "enforceAppLock": true,
        "inactivityTimeoutSecs": 30
      }
      """

      return json.data(using: .utf8)!
    }()
    
    func testThatItCreatesFeature() {
        // given
        let configData = try? JSONEncoder().encode(config)
        
        // when
        let feature = Feature.createOrUpdate("applock",
                                             status: .enabled,
                                             config: configData,
                                             context: uiMOC)
        
        // then
        let fetchedFeature = Feature.fetch("applock", context: uiMOC)
        XCTAssertEqual(feature, fetchedFeature)
    }
    
    func testThatItUpdatesFeature() {
        // given
        let configData = try? JSONEncoder().encode(config)
        let feature = Feature.insert("applock",
                                      status: .enabled,
                                      config: configData,
                                      context: uiMOC)
        XCTAssertEqual(feature.status, .enabled)
        
        // when
        let _ = Feature.createOrUpdate("applock",
                                       status: .disabled,
                                       config: configData,
                                       context: uiMOC)
        
        // then
        XCTAssertEqual(feature.status, .disabled)
    }
    
    func testThatItFetchesFeature() {
        // given
        let configData = try? JSONEncoder().encode(config)
        let _ = Feature.createOrUpdate("applock",
                                       status: .enabled,
                                       config: configData,
                                       context: uiMOC)
        
        
        // when
        let fetchedFeature = Feature.fetch("applock", context: uiMOC)
        
        // then
        XCTAssertNotNil(fetchedFeature)
    }
}
