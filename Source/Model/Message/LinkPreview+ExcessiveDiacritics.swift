//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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
import ZMCLinkPreview


internal extension LinkPreview {
    @objc(linkPreviewByRemovingExcessiveDiacriticsUsage)
    var removingExcessiveDiacriticsUsage: LinkPreview {
        return self
    }
}

internal extension TwitterStatus {
    @objc(linkPreviewByRemovingExcessiveDiacriticsUsage)
    override var removingExcessiveDiacriticsUsage: TwitterStatus {
        let newStatus = TwitterStatus(protocolBuffer: self.protocolBuffer)
        newStatus.message  = self.message?.removingExtremeCombiningCharacters
        newStatus.username = self.username?.removingExtremeCombiningCharacters
        newStatus.author   = self.author?.removingExtremeCombiningCharacters
        return newStatus
    }
}

internal extension Article {
    @objc(linkPreviewByRemovingExcessiveDiacriticsUsage)
    override var removingExcessiveDiacriticsUsage: Article {
        let newStatus = Article(protocolBuffer: self.protocolBuffer)
        newStatus.title  = self.title?.removingExtremeCombiningCharacters
        newStatus.summary = self.summary?.removingExtremeCombiningCharacters
        return newStatus
    }
}
