//
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


#import "ZMVersion.h"

@import Foundation;
@import WireUtilities;

@interface ZMVersion ()

@property (nonatomic) NSArray *arrayRepresentation;
@property (nonatomic) NSString *versionString;

@end


@implementation ZMVersion

- (instancetype)initWithVersionString:(NSString *)versionString
{
    if (versionString == nil) {
        return nil;
    }
    
    self = [super init];
    if (self != nil) {
        self.versionString = versionString;
        self.arrayRepresentation = [self intComponentsOfString:versionString];
    }
    return self;
}

- (NSArray *)intComponentsOfString:(NSString *)versionString;
{
    NSArray *components = [versionString componentsSeparatedByString:@"."];
    return [components mapWithBlock:^id(NSString *numberPresentation) {
        return @([numberPresentation intValue]);
    }];
}

- (NSComparisonResult)compareWithVersion:(ZMVersion *)otherVersion;
{
    if (otherVersion.arrayRepresentation.count == 0) {
        return NSOrderedDescending;
    }
    
    if ([self.versionString isEqualToString:otherVersion.versionString]) {
        return NSOrderedSame;
    }
    
    for (NSUInteger i = 0; i < self.arrayRepresentation.count; i++) {
        if (otherVersion.arrayRepresentation.count == i) {
            // 1.0.1 compare 1.0
            return NSOrderedDescending;
        }
        
        NSNumber *selfNumber = self.arrayRepresentation[i];
        NSNumber *otherNumber = otherVersion.arrayRepresentation[i];
        
        if (selfNumber > otherNumber) {
            return NSOrderedDescending;
        } else if (selfNumber < otherNumber) {
            return NSOrderedAscending;
        }
    }
    
    if (self.arrayRepresentation.count < otherVersion.arrayRepresentation.count) {
        // 1.0 compare 1.0.1
        return NSOrderedAscending;
    }
    
    return NSOrderedSame;
}

- (NSString *)description
{
    return [self.arrayRepresentation componentsJoinedByString:@","];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@ %p> %@",NSStringFromClass(self.class), self, self.description];
}

@end
