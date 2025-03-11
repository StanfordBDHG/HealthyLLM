//
//  NsManagedObjectContext+saveOrRollback.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/21/25.
//

import CoreData


extension NSManagedObjectContext {
    /**
     Attempt to save the context to storage, rollingback if the save fails.
     
     - returns: true if saved
     */
    @discardableResult func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        } catch {
            print(error)
            rollback()
            return false
        }
    }
}
