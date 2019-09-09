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

extension ZMMessage {
    
    class func predicateForMessagesOlderThan(_ date: Date) -> NSPredicate {
        return NSPredicate(format: "%K < %@", ZMMessageServerTimestampKey, date as NSDate)
    }
    
    public class func deleteMessagesOlderThan(_ date: Date, context: NSManagedObjectContext) throws {
        let predicate = predicateForMessagesOlderThan(date)
        try deleteCachedAssetsForMessagesMatching(predicate: predicate, in: context)
        try context.batchDeleteEntities(named: ZMMessage.entityName(), matching: predicate)
    }
    
    private class func deleteCachedAssetsForMessagesMatching(predicate: NSPredicate, in context: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<ZMMessage>(entityName: ZMMessage.entityName())
        fetchRequest.predicate = predicate
        
        for message in try context.fetch(fetchRequest) {
            context.zm_fileAssetCache.deleteAssetData(message)
        }
    }
    
}
