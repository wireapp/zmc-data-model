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

import XCTest
import WireTesting
@testable import WireDataModel

class TestEntity_Root: NSManagedObject {
    @NSManaged var identifier: String?
    @NSManaged var parameter: String?
}

class BatchDeleteTests: ZMTBaseTest {
    var model: NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        let entity = NSEntityDescription()
        entity.name = "\(TestEntity_Root.self)"
        entity.managedObjectClassName = NSStringFromClass(TestEntity_Root.self)
        
        var properties = Array<NSAttributeDescription>()
        
        let remoteURLAttribute = NSAttributeDescription()
        remoteURLAttribute.name = #keyPath(TestEntity_Root.identifier)
        remoteURLAttribute.attributeType = .stringAttributeType
        remoteURLAttribute.isOptional = true
        remoteURLAttribute.isIndexed = true
        properties.append(remoteURLAttribute)
        
        let fileDataAttribute = NSAttributeDescription()
        fileDataAttribute.name = #keyPath(TestEntity_Root.parameter)
        fileDataAttribute.attributeType = .stringAttributeType
        fileDataAttribute.isOptional = true
        properties.append(fileDataAttribute)

        entity.properties = properties
        model.entities = [entity]
        return model
    }
    
    func createTestCoreData() throws -> (NSManagedObjectModel, NSManagedObjectContext) {
        let model = self.model
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        let path = NSTemporaryDirectory().appending("test.sqlite")
        let url = URL(fileURLWithPath: path)
        
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(at: url)
        }
        
        try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                          configurationName: nil,
                                                          at: url,
                                                          options: [:])
        
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        return (model, managedObjectContext)
    }
    
    var mom: NSManagedObjectModel!
    var moc: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        let (mom, moc) = try! createTestCoreData()
        self.mom = mom
        self.moc = moc
    }
    
    override func tearDown() {
        self.moc = nil
        self.mom = nil
        super.tearDown()
    }
    
    func testThatItDoesNotRemoveValidGenericMessageData() throws {
        // given
        let entity = mom.entitiesByName["\(TestEntity_Root.self)"]!
        
        let ints = Array(0...10)
        let objects: [TestEntity_Root] = ints.map { (id: Int) in
            let object = TestEntity_Root(entity: entity, insertInto: self.moc)
            object.identifier = "\(id)"
            object.parameter = "value"
            return object
        }
        
        let objectsShouldBeDeleted: [TestEntity_Root] = ints.map { (id: Int) in
            let object = TestEntity_Root(entity: entity, insertInto: self.moc)
            object.identifier = "\(id + 100)"
            object.parameter = nil
            return object
        }
        
        // when
        
        try moc.save()
        
        let predicate = NSPredicate(format: "%K == nil", #keyPath(TestEntity_Root.parameter))
        try moc.batchDeleteEntities(named: "\(TestEntity_Root.self)", matching: predicate)
        
        // then
        objects.forEach {
            XCTAssertFalse($0.isDeleted)
        }
        
        objectsShouldBeDeleted.forEach {
            XCTAssertTrue($0.isDeleted)
        }
    }
    
    func testThatItNotifiesAboutDelete() throws {
        class FetchRequestObserver: NSObject, NSFetchedResultsControllerDelegate {
            var deletedCount: Int = 0
            
            public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                                   didChange anObject: Any,
                                   at indexPath: IndexPath?,
                                   for type: NSFetchedResultsChangeType,
                                   newIndexPath: IndexPath?)
            {
                switch type {
                case .delete:
                    deletedCount = deletedCount + 1
                case .insert:
                    break
                case .move:
                    break
                case .update:
                    break
                }
            }
        }
        
        // given
        let entity = mom.entitiesByName["\(TestEntity_Root.self)"]!
        
        let object = TestEntity_Root(entity: entity, insertInto: self.moc)
        object.identifier = "1"
        object.parameter = nil
        
        // when
        
        try moc.save()
        
        let observer = FetchRequestObserver()
        
        let fetchRequest = NSFetchRequest<TestEntity_Root>(entityName: "\(TestEntity_Root.self)")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(TestEntity_Root.identifier), ascending: true)]
        let fetchRequestController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                managedObjectContext: moc,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)
        fetchRequestController.delegate = observer
        try fetchRequestController.performFetch()
        XCTAssertEqual(fetchRequestController.sections?.count, 1)
        XCTAssertEqual(fetchRequestController.sections?.first?.objects?.count, 1)
        XCTAssertEqual(fetchRequestController.sections?.first?.objects?.first as! TestEntity_Root, object)
        
        let predicate = NSPredicate(format: "%K == nil", #keyPath(TestEntity_Root.parameter))
        try moc.batchDeleteEntities(named: "\(TestEntity_Root.self)", matching: predicate)
        try moc.save()

        // then
        XCTAssertEqual(observer.deletedCount, 1)
    }
}
