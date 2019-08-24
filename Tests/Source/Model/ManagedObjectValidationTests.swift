//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

import WireDataModel
import OCMock
//Integration tests for validation
// TODO

/*
class ManagedObjectValidationTests: ZMBaseManagedObjectTest {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testThatValidationOnUIContextIsPerformed() {
        
        let user = ZMUser.selfUser(in: self.uiMOC)
        user.name = "Ilya"
        let value = user.name
        
        let validator = OCMockObject.mock(for: StringLengthValidator.self)
 
        
        

        ZMUser *user = [ZMUser selfUserInContext:self.uiMOC];
        user.name = @"Ilya";
        id value = user.name;
        
        id validator = [OCMockObject mockForClass:[StringLengthValidator class]];
        [[[validator expect] andForwardToRealObject] validateValue:[OCMArg anyObjectRef]
            minimumStringLength:2
            maximumStringLength:100
            maximumByteLength:INT_MAX
            error:[OCMArg anyObjectRef]];
        
        BOOL result = [user validateValue:&value forKey:@"name" error:NULL];
        XCTAssertTrue(result);
        [validator verify];
        [validator stopMocking];
 
    }
    
    func testThatValidationOnNonUIContextAlwaysPass() {
 
        [self.syncMOC performGroupedBlockAndWait:^{
            ZMUser *user = [ZMUser selfUserInContext:self.syncMOC];
            user.name = @"Ilya";
            id value = user.name;
            
            id validator = [OCMockObject mockForClass:[StringLengthValidator class]];
            [[[validator reject] andForwardToRealObject] validateValue:[OCMArg anyObjectRef]
            minimumStringLength:2
            maximumStringLength:64
            maximumByteLength:256
            error:[OCMArg anyObjectRef]];
            
            BOOL result = [user validateValue:&value forKey:@"name" error:NULL];
            XCTAssertTrue(result);
            [validator verify];
            [validator stopMocking];
            }];

    }
    
    
}
*/
