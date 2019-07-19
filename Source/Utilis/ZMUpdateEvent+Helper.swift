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

import Foundation
import WireTransport

extension ZMUpdateEvent {
    public convenience override init() {
        self.init(uuid: nil, payload: ["type": "conversation.create"], transient: false, decrypted: false, source: .download)!
    }

    @objc
    public func timeStamp() -> Date? {
        if isTransient || type == .userConnection {
            return nil
        }

        ///TODO: study why the below method return nil
        //            return (payload as NSDictionary).date(forKey: "time")

        if let timeString = payload[AnyHashable("time")] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            let date = dateFormatter.date(from: timeString)

            print(timeString)


            return date
        }

        return nil
    }
}
