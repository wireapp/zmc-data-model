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


/// An `Account` holds information related to a single account,
/// such as the accounts users name,
/// team name if there is any, picture and uuid.
public final class Account: NSObject {

    let userName: String
    let teamName: String?
    let userIdentifier: UUID
    var imageData: Data?

    public required init(userName: String, userIdentifier: UUID, teamName: String? = nil, imageData: Data? = nil) {
        self.userName = userName
        self.userIdentifier = userIdentifier
        self.teamName = teamName
        self.imageData = imageData
        super.init()
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Account else { return false }
        return userName == other.userName
            && teamName == other.teamName
            && userIdentifier == other.userIdentifier
            && imageData == other.imageData
    }

    public override var hash: Int {
        return userIdentifier.hashValue
    }

    public override var debugDescription: String {
        return "<Account>:\n\tname: \(userName)\n\tid: \(userIdentifier)\n\tteam: \(String(describing: teamName))\n\timage: \(String(describing: imageData?.count))\n"
    }
}

// MARK: - NSSecureCoding

extension Account: NSSecureCoding {

    public static var supportsSecureCoding = true

    public convenience init?(coder aDecoder: NSCoder) {
        guard let id = aDecoder.decodeString(forKey: #keyPath(Account.userIdentifier)).flatMap(UUID.init),
            let name = aDecoder.decodeString(forKey: #keyPath(Account.userName)) else { return nil }
        self.init(
            userName: name,
            userIdentifier: id,
            teamName: aDecoder.decodeString(forKey: #keyPath(Account.teamName)),
            imageData: aDecoder.decodeData(forKey: #keyPath(Account.imageData))
        )
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(userName, forKey: #keyPath(Account.userName))
        aCoder.encode(userIdentifier.uuidString, forKey: #keyPath(Account.userIdentifier))
        aCoder.encode(teamName, forKey: #keyPath(Account.teamName))
        aCoder.encode(imageData, forKey: #keyPath(Account.imageData))
    }

}

// MARK: - Serialization Helper

extension Account {

    func write(to url: URL) throws {
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        try data.write(to: url)
    }

    static func load(from url: URL) -> Account? {
        let data = try? Data(contentsOf: url)
        return data.map(NSKeyedUnarchiver.unarchiveObject) as? Account
    }
    
}
