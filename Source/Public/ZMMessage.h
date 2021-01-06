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


#import "ZMManagedObject.h"
#import <CoreGraphics/CoreGraphics.h>

@class ZMUser;
@class ZMConversation;
@class UserClient;
@class LinkMetadata;
@class Mention;
@class ZMMessage;

@protocol ZMImageMessageData;
@protocol ZMSystemMessageData;
@protocol ZMKnockMessageData;
@protocol ZMFileMessageData;
@protocol UserClientType;


#pragma mark - ZMImageMessageData


@protocol ZMImageMessageData <NSObject>

@property (nonatomic, readonly, nullable) NSData *imageData; ///< This will either returns the mediumData or the original image data. Useful only for newly inserted messages.
@property (nonatomic, readonly, nullable) NSString *imageDataIdentifier; /// This can be used as a cache key for @c -imageData

@property (nonatomic, readonly) BOOL isAnimatedGIF; // If it is GIF and has more than 1 frame
@property (nonatomic, readonly) BOOL isDownloaded; // If the image has been downloaded and cached locally
@property (nonatomic, readonly, nullable) NSString *imageType; // UTI e.g. kUTTypeGIF
@property (nonatomic, readonly) CGSize originalSize;

- (void)fetchImageDataWithQueue:(dispatch_queue_t _Nonnull )queue completionHandler:(void (^_Nonnull)(NSData * _Nullable imageData))completionHandler;

/// Request the download of the image if not already present.
/// The download will be executed asynchronously. The caller can be notified by observing the message window.
/// This method can safely be called multiple times, even if the content is already available locally
- (void)requestFileDownload;

@end


#pragma mark - ZMSystemMessageData


typedef NS_ENUM(int16_t, ZMSystemMessageType) {
    ZMSystemMessageTypeInvalid = 0,
    ZMSystemMessageTypeParticipantsAdded,
    ZMSystemMessageTypeParticipantsRemoved,
    ZMSystemMessageTypeConversationNameChanged,
    ZMSystemMessageTypeConnectionRequest,
    ZMSystemMessageTypeConnectionUpdate,
    ZMSystemMessageTypeMissedCall,
    ZMSystemMessageTypeNewClient,
    ZMSystemMessageTypeIgnoredClient,
    ZMSystemMessageTypeConversationIsSecure,
    ZMSystemMessageTypePotentialGap,
    ZMSystemMessageTypeDecryptionFailed,
    ZMSystemMessageTypeDecryptionFailed_RemoteIdentityChanged,
    ZMSystemMessageTypeNewConversation,
    ZMSystemMessageTypeReactivatedDevice,
    ZMSystemMessageTypeUsingNewDevice,
    ZMSystemMessageTypeMessageDeletedForEveryone,
    ZMSystemMessageTypePerformedCall,
    ZMSystemMessageTypeTeamMemberLeave,
    ZMSystemMessageTypeMessageTimerUpdate,
    ZMSystemMessageTypeReadReceiptsEnabled,
    ZMSystemMessageTypeReadReceiptsDisabled,
    ZMSystemMessageTypeReadReceiptsOn,
    ZMSystemMessageTypeLegalHoldEnabled,
    ZMSystemMessageTypeLegalHoldDisabled
};



@protocol ZMTextMessageData <NSObject>

@property (nonatomic, readonly, nullable) NSString *messageText;
@property (nonatomic, readonly, nullable) LinkMetadata *linkPreview;
@property (nonatomic, readonly, nonnull) NSArray<Mention *> *mentions;
@property (nonatomic, readonly, nullable) ZMMessage *quote;

/// Returns true if the link preview will have an image
@property (nonatomic, readonly) BOOL linkPreviewHasImage;

/// Unique identifier for link preview image.
@property (nonatomic, readonly, nullable) NSString *linkPreviewImageCacheKey;

/// Detect if user replies to a message sent from himself
@property (nonatomic, readonly) BOOL isQuotingSelf;

/// Check if message has a quote
@property (nonatomic, readonly) BOOL hasQuote;

/// Fetch linkpreview image data from disk on the given queue
- (void)fetchLinkPreviewImageDataWithQueue:(dispatch_queue_t _Nonnull )queue completionHandler:(void (^_Nonnull)(NSData * _Nullable imageData))completionHandler;

/// Request link preview image to be downloaded
- (void)requestLinkPreviewImageDownload;

/// Edit the text content
- (void)editText:(NSString * _Nonnull)text mentions:(NSArray<Mention *> * _Nonnull)mentions fetchLinkPreview:(BOOL)fetchLinkPreview;

@end

#pragma mark - ZMKnockMessageData


@protocol ZMKnockMessageData <NSObject>

@end

typedef NS_ENUM(int16_t, ZMLinkPreviewState) {
    /// Link preview has been sent or message did not contain any preview
    ZMLinkPreviewStateDone = 0,
    /// Message text needs to be parsed to see if it contain any links
    ZMLinkPreviewStateWaitingToBeProcessed,
    /// Link preview have been downloaded
    ZMLinkPreviewStateDownloaded,
    /// Link preview assets have been processed & encrypted
    ZMLinkPreviewStateProcessed,
    /// Link preview assets have been uploaded
    ZMLinkPreviewStateUploaded
};
