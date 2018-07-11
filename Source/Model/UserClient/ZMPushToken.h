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


#import <Foundation/Foundation.h>
@import CoreData;

/// Legacy push token that was replaced by PushToken.swift
/// Used for migrating from old
@interface ZMPushToken : NSObject <NSSecureCoding>

- (instancetype _Nonnull)initWithDeviceToken:(NSData * _Nonnull)deviceToken
                         identifier:(NSString * _Nonnull)appIdentifier
                      transportType:(NSString * _Nonnull)transportType
                       isRegistered:(BOOL)isRegistered
                         isMarkedForDeletion:(BOOL)isMarkedForDeletion;

@property (nonatomic, copy, readonly, nonnull) NSData *deviceToken;
@property (nonatomic, copy, readonly, nonnull) NSString *appIdentifier;
@property (nonatomic, copy, readonly, nonnull) NSString *transportType;
@property (nonatomic, readonly) BOOL isRegistered;
@property (nonatomic, readonly) BOOL isMarkedForDeletion;

@end
