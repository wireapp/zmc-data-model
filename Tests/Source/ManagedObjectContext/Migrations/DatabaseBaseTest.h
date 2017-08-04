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
//
//#import <XCTest/XCTest.h>
//
//@import WireTesting;
//@class ManagedObjectContextDirectory;
//
//@interface DatabaseBaseTest : ZMTBaseTest
//
//@property (nonatomic, readonly, nonnull) NSFileManager *fm;
//@property (nonatomic, readonly, nonnull) NSString *databaseIdentifier;
//@property (nonatomic, readonly, nonnull) NSURL *cachesDirectoryStoreURL;
//@property (nonatomic, readonly, nonnull) NSURL *applicationSupportDirectoryStoreURL;
//@property (nonatomic, readonly, nonnull) NSURL *sharedContainerDirectoryURL;
//@property (nonatomic, readonly, nonnull) NSURL *sharedContainerStoreURL;
//@property (nonatomic, readonly, nonnull) NSArray <NSString *> *databaseFileExtensions;
//@property (nonatomic, readonly, nonnull) NSUUID *accountID;
//@property (nonatomic, nullable) ManagedObjectContextDirectory *contextDirectory;
//
//- (void)cleanUp;
//- (BOOL)createDatabaseInDirectory:(NSSearchPathDirectory)directory accountIdentifier:(nonnull NSUUID *)accountIdentifier;
//- (BOOL)createDatabaseAtSharedContainerURL:(nonnull NSURL *)sharedContainerURL accountIdentifier:(nonnull NSUUID *)accountIdentifier;
//
//- (nonnull NSData *)invalidData;
//- (BOOL)createdUnreadableLocalStore;
//- (BOOL)createExternalSupportFileForDatabaseAtURL:(nonnull NSURL *)databaseURL;
//- (void)createDirectoryForStoreAtURL:(nonnull NSURL *)storeURL;
//
//@end
//
//
//@interface NSFileManager (StoreLocation)
//
//+ (nonnull NSURL *)storeURLInDirectory:(NSSearchPathDirectory)directory;
//
//@end
