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

#import "ZMPushToken.h"

#import <stdio.h>

static NSString * const DeviceTokenKey = @"deviceToken";
static NSString * const IdentifierKey = @"identifier";
static NSString * const TransportKey = @"transportType";
static NSString * const IsRegisteredKey = @"isRegistered";
static NSString * const IsMarkedForDeletionKey = @"isMarkedForDeletion";

@interface ZMPushToken ()

@property (nonatomic, copy) NSData *deviceToken;
@property (nonatomic, copy) NSString *appIdentifier;
@property (nonatomic, copy) NSString *transportType;

@property (nonatomic) BOOL isRegistered;
@property (nonatomic) BOOL isMarkedForDeletion;

@end

@implementation ZMPushToken

- (instancetype)initWithDeviceToken:(NSData *)deviceToken identifier:(NSString *)appIdentifier transportType:(NSString *)transportType isRegistered:(BOOL)isRegistered isMarkedForDeletion:(BOOL)isMarkedForDeletion;
{
    self = [super init];
    if (self) {
        self.deviceToken = deviceToken;
        self.appIdentifier = appIdentifier;
        self.transportType = transportType;
        self.isRegistered = isRegistered;
        self.isMarkedForDeletion = isMarkedForDeletion;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder;
{
    if (self.deviceToken != nil) {
        [coder encodeObject:self.deviceToken forKey:DeviceTokenKey];
    }
    if (self.appIdentifier != nil) {
        [coder encodeObject:self.appIdentifier forKey:IdentifierKey];
    }
    if (self.transportType != nil) {
        [coder encodeObject:self.transportType forKey:TransportKey];
    }
    [coder encodeBool:self.isRegistered forKey:IsRegisteredKey];
    [coder encodeBool:self.isMarkedForDeletion forKey:IsMarkedForDeletionKey];
}

- (id)initWithCoder:(NSCoder *)coder;
{
    self = [self init];
    if (self != nil) {
        self.deviceToken = [coder decodeObjectOfClass:NSData.class forKey:DeviceTokenKey];
        self.appIdentifier = [coder decodeObjectOfClass:NSString.class forKey:IdentifierKey];
        self.transportType = [coder decodeObjectOfClass:NSString.class forKey:TransportKey];
        self.isRegistered = [coder decodeBoolForKey:IsRegisteredKey];
        self.isMarkedForDeletion = [coder decodeBoolForKey:IsMarkedForDeletionKey];
    }
    return self;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@: %p> %@, %@ \"%@\" - %@ - device token: %@",
            self.class, self,
            self.isRegistered ? @"registered" : @"not registered",
            self.isMarkedForDeletion ? @"markedForDeletion" : @"valid",
            self.appIdentifier,
            self.transportType,
            self.deviceToken];
}

+ (BOOL)supportsSecureCoding;
{
    return YES;
}

@end
