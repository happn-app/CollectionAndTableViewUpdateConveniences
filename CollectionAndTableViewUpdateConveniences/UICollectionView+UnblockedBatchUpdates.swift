/*
Copyright 2018 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation
import UIKit



private var keyQueuedGroupedOperations = "queued grouped operations"

public extension UICollectionView {
	
	func beginUpdates() {
		assert(queuedGroupedOperations == nil, "Call end or cancel updates before beginUpdates! (Not re-entrant.)")
		queuedGroupedOperations = []
	}
	
	func groupedInsertSections(_ sections: IndexSet) {
		queuedGroupedOperations!.append{
			self.insertSections(sections)
		}
	}
	
	func groupedDeleteSections(_ sections: IndexSet) {
		queuedGroupedOperations!.append{
			self.deleteSections(sections)
		}
	}
	
	func groupedReloadSections(_ sections: IndexSet) {
		queuedGroupedOperations!.append{
			self.reloadSections(sections)
		}
	}
	
	func groupedMoveSection(_ section: Int, toSection newSection: Int) {
		queuedGroupedOperations!.append{
			self.moveSection(section, toSection: newSection)
		}
	}
	
	func groupedInsertItems(at indexPaths: [IndexPath]) {
		queuedGroupedOperations!.append{
			self.insertItems(at: indexPaths)
		}
	}
	
	func groupedDeleteItems(at indexPaths: [IndexPath]) {
		queuedGroupedOperations!.append{
			self.deleteItems(at: indexPaths)
		}
	}
	
	func groupedReloadItems(at indexPaths: [IndexPath]) {
		queuedGroupedOperations!.append{
			self.reloadItems(at: indexPaths)
		}
	}
	
	func groupedMoveItem(at indexPath: IndexPath, to newIndexPath: IndexPath) {
		queuedGroupedOperations!.append{
			self.moveItem(at: indexPath, to: newIndexPath)
		}
	}
	
	func groupedGenericUpdate(_ handler: @escaping () -> Void) {
		queuedGroupedOperations!.append(handler)
	}
	
	func endUpdates(handler: ((_ finishedAnimations: Bool) -> Void)?) {
		guard let operations = queuedGroupedOperations else {
			fatalError("Call beginUpdates before endUpdates!")
		}
		
		queuedGroupedOperations = nil
		guard operations.count > 0 else {handler?(true); return}
		
		performBatchUpdates({ operations.forEach{ $0() } }, completion: handler)
	}
	
	func cancelUpdates() {
		assert(queuedGroupedOperations != nil, "Call beginUpdates before cancelUpdates!")
		queuedGroupedOperations = nil
	}
	
	private var queuedGroupedOperations: (Array<() -> Void>)? {
		get {return objc_getAssociatedObject(self, &keyQueuedGroupedOperations) as! (Array<() -> Void>)?}
		set {objc_setAssociatedObject(self, &keyQueuedGroupedOperations, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
	}
	
}
