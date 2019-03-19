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

import Foundation

/**
 * Represents a link attachment.
 *
 * We use these attachments for links that are sent through link previous, but
 * that we want to parse anyway.
 */

@objc public protocol ZMLinkAttachment: NSObjectProtocol {}

// MARK: - ZMMediaThumbnail

/**
 * Represents a remote media thumbnail.
 */

@objc public class ZMMediaThumbnail: NSObject, NSCoding {

    /// The URL to download the image.
    @objc public let url: URL

    /// The size of the image.
    @objc public let size: CGSize

    // MARK: Initialization

    /**
     * Creates a new media thumbnail reference.
     * - parameter url: The URL to download the image.
     * - parameter size: The size of the image.
     */

    @objc public init(url: URL, size: CGSize) {
        self.url = url
        self.size = size
    }

    // MARK: NSCoding

    public required init?(coder aDecoder: NSCoder) {
        guard let url = aDecoder.decodeObject(of: NSURL.self, forKey: #keyPath(url)) else {
            return nil
        }

        self.url = url as URL
        self.size = aDecoder.decodeCGSize(forKey: #keyPath(size))
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(url as NSURL, forKey: #keyPath(url))
        aCoder.encode(size, forKey: #keyPath(size))
    }

}

/**
 * A list of supported media items.
 */

@objc public enum ZMLinkAttachmentProvider: Int {
    case youTube = 0
    case soundCloud = 1
}

// MARK: - Media Attachments

/**
 * Represents a link attachment for a single media.
 */

@objc public class ZMMediaLinkAttachment: NSObject, NSCoding, ZMLinkAttachment {

    /// The provider of the media.
    @objc public let provider: ZMLinkAttachmentProvider

    /// The identifier of the media.
    @objc public let identifier: String

    /// The title of the media.
    @objc public let title: String

    /// The permalink to the media on the provider's website.
    @objc public let permalink: URL

    /// The list of the video thumbnails.
    @objc public let thumbnails: [ZMMediaThumbnail]

    // MARK: Initialization

    /**
     * Creates a new media thumbnail reference.
     * - parameter provider: The provider of the media.
     * - parameter identifier: The identifier of the video.
     * - parameter title: The title of the video.
     * - parameter permalink: The permalink to the media on the provider's website.
     * - parameter thumbnails: The list of the video thumbnails.
     */

    @objc public init(provider: ZMLinkAttachmentProvider, identifier: String, title: String, permalink: URL, thumbnails: [ZMMediaThumbnail]) {
        self.provider = provider
        self.identifier = identifier
        self.title = title
        self.permalink = permalink
        self.thumbnails = thumbnails
    }

    // MARK: NSCoding

    public required init?(coder aDecoder: NSCoder) {
        guard
            let provider = ZMLinkAttachmentProvider(rawValue: aDecoder.decodeInteger(forKey: #keyPath(provider))),
            let identifier = aDecoder.decodeString(forKey: #keyPath(identifier)),
            let title = aDecoder.decodeString(forKey: #keyPath(title)),
            let permalink = aDecoder.decodeObject(of: NSURL.self, forKey: #keyPath(permalink)) as URL?,
            let thumbnails = aDecoder.decodeObject(of: NSArray.self, forKey: #keyPath(thumbnails)) as? [ZMMediaThumbnail]
        else {
            return nil
        }

        self.provider = provider
        self.identifier = identifier
        self.title = title
        self.permalink = permalink
        self.thumbnails = thumbnails
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(provider.rawValue, forKey: #keyPath(provider))
        aCoder.encode(identifier, forKey: #keyPath(identifier))
        aCoder.encode(title, forKey: #keyPath(title))
        aCoder.encode(permalink, forKey: #keyPath(permalink))
        aCoder.encode(thumbnails, forKey: #keyPath(thumbnails))
    }

}

// MARK: - Playlist Attachments

/**
 * Represents a media playlist link attachment.
 */

@objc public class ZMPlaylistLinkAttachment: NSObject, NSCoding, ZMLinkAttachment {

    /// The provider of the media playlist.
    @objc public let provider: ZMLinkAttachmentProvider

    /// The identifier of the track.
    @objc public let identifier: String

    /// The title of the video.
    @objc public let title: String

    /// The permalink to the playlist on the provider's website.
    @objc public let permalink: URL

    /// The list of the video thumbnails.
    @objc public let thumbnails: [ZMMediaThumbnail]

    /// The media in the playlist.
    @objc public let mediaAttachments: [ZMMediaLinkAttachment]

    // MARK: Initialization

    /**
     * Creates a new media thumbnail reference.
     * - parameter provider: The provider of the media playlist.
     * - parameter identifier: The identifier of the video.
     * - parameter title: The title of the video.
     * - parameter permalink: The permalink to the playlist on the provider's website.
     * - parameter thumbnails: The list of the video thumbnails.
     * - parameter mediaAttachments: The media in the playlist.
     */

    @objc public init(provider: ZMLinkAttachmentProvider, identifier: String, title: String, permalink: URL, thumbnails: [ZMMediaThumbnail], mediaAttachments: [ZMMediaLinkAttachment]) {
        self.provider = provider
        self.identifier = identifier
        self.title = title
        self.permalink = permalink
        self.thumbnails = thumbnails
        self.mediaAttachments = mediaAttachments
    }

    // MARK: NSCoding

    public required init?(coder aDecoder: NSCoder) {
        guard
            let provider = ZMLinkAttachmentProvider(rawValue: aDecoder.decodeInteger(forKey: #keyPath(provider))),
            let identifier = aDecoder.decodeString(forKey: #keyPath(identifier)),
            let title = aDecoder.decodeString(forKey: #keyPath(title)),
            let permalink = aDecoder.decodeObject(of: NSURL.self, forKey: #keyPath(permalink)) as URL?,
            let thumbnails = aDecoder.decodeObject(of: NSArray.self, forKey: #keyPath(thumbnails)) as? [ZMMediaThumbnail],
            let mediaAttachments = aDecoder.decodeObject(of: NSArray.self, forKey: #keyPath(mediaAttachments)) as? [ZMMediaLinkAttachment]
        else {
            return nil
        }

        self.provider = provider
        self.identifier = identifier
        self.title = title
        self.permalink = permalink
        self.thumbnails = thumbnails
        self.mediaAttachments = mediaAttachments
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(provider.rawValue, forKey: #keyPath(provider))
        aCoder.encode(identifier, forKey: #keyPath(identifier))
        aCoder.encode(title, forKey: #keyPath(title))
        aCoder.encode(permalink, forKey: #keyPath(permalink))
        aCoder.encode(thumbnails, forKey: #keyPath(thumbnails))
        aCoder.encode(mediaAttachments, forKey: #keyPath(mediaAttachments))
    }

}
