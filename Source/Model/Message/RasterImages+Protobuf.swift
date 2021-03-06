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

public extension WireProtos.Asset.Original {
    var hasRasterImage: Bool {
        guard case .image? = self.metaData else {
            return false
        }
        
        // FUTUREWORK remove once arm64 simulator support have been added JIRA ticket: SQPIT-583
        #if targetEnvironment(simulator)
        if let utType = UTType(mimeType: mimeType) {
            return utType.isSVG == false
        } else if mimeType == "image/svg+xml" {
            return false
        }
        #else
        guard UTType(mimeType: mimeType)?.isSVG == false else {
            return false
        }
        #endif
        return true
    }
}

fileprivate extension ImageAsset {
    var isRaster: Bool {
        return UTType(mimeType: mimeType)?.isSVG == false
    }
}

public extension GenericMessage {
    var hasRasterImage: Bool {
        guard let content = content else { return false }
        switch content {
        case .image(let data):
            return data.isRaster
        case .ephemeral(let data):
            switch data.content {
            case .image(let image)?:
                return image.isRaster
            default:
                return false
            }
        default:
            return false
        }
    }
}
