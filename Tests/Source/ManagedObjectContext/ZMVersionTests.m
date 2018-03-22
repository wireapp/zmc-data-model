//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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

@import WireDataModel;
@import XCTest;

@interface ZMVersionTests: XCTestCase
@end

@implementation ZMVersionTests

- (void)testThatItComparesCorrectly
{
    // given
    NSString *version1String = @"0.1";
    NSString *version2String = @"1.0";
    NSString *version3String = @"1.0";
    NSString *version4String = @"1.0.1";
    NSString *version5String = @"1.1";
    
    ZMVersion *version1 = [[ZMVersion alloc] initWithVersionString:version1String];
    ZMVersion *version2 = [[ZMVersion alloc] initWithVersionString:version2String];
    ZMVersion *version3 = [[ZMVersion alloc] initWithVersionString:version3String];
    ZMVersion *version4 = [[ZMVersion alloc] initWithVersionString:version4String];
    ZMVersion *version5 = [[ZMVersion alloc] initWithVersionString:version5String];
    
    // then
    XCTAssertEqual([version1 compareWithVersion:version2], NSOrderedAscending);
    XCTAssertEqual([version1 compareWithVersion:version3], NSOrderedAscending);
    XCTAssertEqual([version1 compareWithVersion:version4], NSOrderedAscending);
    XCTAssertEqual([version1 compareWithVersion:version5], NSOrderedAscending);
    
    XCTAssertEqual([version2 compareWithVersion:version1], NSOrderedDescending);
    XCTAssertEqual([version2 compareWithVersion:version3], NSOrderedSame);
    XCTAssertEqual([version2 compareWithVersion:version4], NSOrderedAscending);
    XCTAssertEqual([version2 compareWithVersion:version5], NSOrderedAscending);
    
    XCTAssertEqual([version3 compareWithVersion:version1], NSOrderedDescending);
    XCTAssertEqual([version3 compareWithVersion:version2], NSOrderedSame);
    XCTAssertEqual([version3 compareWithVersion:version4], NSOrderedAscending);
    XCTAssertEqual([version3 compareWithVersion:version5], NSOrderedAscending);
    
    XCTAssertEqual([version4 compareWithVersion:version1], NSOrderedDescending);
    XCTAssertEqual([version4 compareWithVersion:version2], NSOrderedDescending);
    XCTAssertEqual([version4 compareWithVersion:version3], NSOrderedDescending);
    XCTAssertEqual([version4 compareWithVersion:version5], NSOrderedAscending);
    
    XCTAssertEqual([version5 compareWithVersion:version1], NSOrderedDescending);
    XCTAssertEqual([version5 compareWithVersion:version2], NSOrderedDescending);
    XCTAssertEqual([version5 compareWithVersion:version3], NSOrderedDescending);
    XCTAssertEqual([version5 compareWithVersion:version4], NSOrderedDescending);
}

@end
