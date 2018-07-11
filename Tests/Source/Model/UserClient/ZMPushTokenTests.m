////
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

#import <XCTest/XCTest.h>
@import WireDataModel;

@interface ZMPushTokenTests : XCTestCase

@property (nonatomic) NSString *identifier;
@property (nonatomic) NSString *transportType;

@end

@implementation ZMPushTokenTests

- (void)setUp
{
    [super setUp];
    self.identifier = @"foo-bar.baz";
    self.transportType = @"apns";
}

- (void)tearDown
{
    self.identifier = nil;
    self.transportType = nil;
    [super tearDown];
}

- (void)testThatItCanBeArchived
{
    for (int i = 0; i < 3; ++i) {
        // given
        NSData * const deviceToken = [NSData dataWithBytes:(uint8_t[]){1, 0, 128, 255} length:4];
        BOOL const isRegistered = (i == 1);
        BOOL const isDeleted = (i == 2);
        ZMPushToken *token = [[ZMPushToken alloc] initWithDeviceToken:deviceToken identifier:self.identifier transportType:self.transportType isRegistered:isRegistered isMarkedForDeletion: isDeleted];

        // when
        NSMutableData *archive = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archive];
        archiver.requiresSecureCoding = YES;
        [archiver encodeObject:token forKey:@"token"];
        [archiver finishEncoding];

        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
        unarchiver.requiresSecureCoding = YES;
        ZMPushToken *unarchivedToken = [unarchiver decodeObjectOfClass:ZMPushToken.class forKey:@"token"];

        // then
        XCTAssertNotNil(unarchivedToken);
        XCTAssertEqualObjects(unarchivedToken.deviceToken, deviceToken);
        XCTAssertEqualObjects(unarchivedToken.appIdentifier, self.identifier);
        XCTAssertEqualObjects(unarchivedToken.transportType, self.transportType);
        XCTAssertEqual(unarchivedToken.isRegistered, isRegistered);
        XCTAssertEqual(unarchivedToken.isMarkedForDeletion, isDeleted);
    }
}

@end
