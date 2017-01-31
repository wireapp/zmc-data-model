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


@class ZMUser;

@interface ZMPersonName : NSObject

@property (nonatomic, readonly, copy, nonnull) NSArray *components;

@property (nonatomic, readonly, copy, nonnull) NSString *givenName;
@property (nonatomic, readonly, copy, nonnull) NSString *fullName;
@property (nonatomic, readonly, copy, nonnull) NSString *initials;
@property (nonatomic, copy, nullable) NSString *displayName;

+ (_Nonnull instancetype)personWithName:(NSString * _Nullable)name;


@end
