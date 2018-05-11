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

import CoreData
import Foundation
import os.log
import UIKit



private var keyFetchedResultsControllerMoveMode = "fetched results controller move mode"
private var keyFetchedResultsControllerReloadMode = "fetched results controller reload mode"

private var keyFetchedResultsControllerPostponedReloads = "fetched results controller postponed reloads"

public extension UICollectionView {
	
	/** Default is `.deleteInsert`, which is what is recommended by Apple. */
	var fetchedResultsControllerMoveMode: FetchedResultsControllerMoveMode {
		get {return (objc_getAssociatedObject(self, &keyFetchedResultsControllerMoveMode) as! ObjC_FetchedResultsControllerMoveModeWrapper?)?.moveMode ?? .deleteInsert}
		set {objc_setAssociatedObject(self, &keyFetchedResultsControllerMoveMode, ObjC_FetchedResultsControllerMoveModeWrapper(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
	}
	
	/** Default is `.none`. Apple recommends the handler, but we cannot “invent“
	said handler, so we fallback to no reload by default (`.reload` has a
	reputation of being a little dangerous...) */
	var fetchedResultsControllerReloadMode: FetchedResultsControllerReloadMode {
		get {return (objc_getAssociatedObject(self, &keyFetchedResultsControllerReloadMode) as! ObjC_FetchedResultsControllerReloadModeWrapper?)?.reloadMode ?? .none}
		set {objc_setAssociatedObject(self, &keyFetchedResultsControllerReloadMode, ObjC_FetchedResultsControllerReloadModeWrapper(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
	}
	
	func fetchedResultsControllerWillChangeContent() {
		/*UNSAFE_RELOAD: assert(postponedReloads == nil)
		postponedReloads = []*/
		beginUpdates()
	}
	
	func fetchedResultsControllerDidChange(section: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
		let sectionIndexSet = IndexSet(integer: sectionIndex)
		
		/* We switch on the raw value. A bug can arise in the fetched controller
		 * did change object where we get an invalid change type (see method
		 * implementation). The bug has not been observed on an updated of a
		 * section, but let's be extra-cautious, it costs nothing... */
		switch type.rawValue {
		case NSFetchedResultsChangeType.insert.rawValue: groupedInsertSections(sectionIndexSet)
		case NSFetchedResultsChangeType.delete.rawValue: groupedDeleteSections(sectionIndexSet)
			
		case NSFetchedResultsChangeType.move.rawValue, NSFetchedResultsChangeType.update.rawValue:
			if #available(iOS 10.0, *) {di.log.flatMap{ os_log("Got invalid section change %{public}@. Ignoring...", log: $0, type: .info, String(describing: type)) }}
			else                       {NSLog("Got invalid section change %@. Ignoring...", String(describing: type))}
			
		default:
			(/* Extra protection against potential Core Data bug... */)
		}
	}
	
	func fetchedResultsControllerDidChange(object: Any, atIndexPath indexPath: IndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		/* We MUST switch on the raw value. Core Data sometimes sends notification
		 * with invalid change type... if we do not switch on the raw value, as
		 * the type does not exist and is not handled, the first case is executed.
		 * See answer from RoyalPhysique on https://forums.developer.apple.com/thread/11662 */
		switch type.rawValue {
		case NSFetchedResultsChangeType.insert.rawValue:
			guard let newIndexPath = newIndexPath else {
				if #available(iOS 10.0, *) {di.log.flatMap{ os_log("Got an insert object change type, but no new index path", log: $0, type: .info) }}
				else                       {NSLog("Got an insert object change type, but no new index path")}
				return
			}
			groupedInsertItems(at: [newIndexPath])
			
		case NSFetchedResultsChangeType.delete.rawValue:
			guard let indexPath = indexPath else {
				if #available(iOS 10.0, *) {di.log.flatMap{ os_log("Got a delete object change type, but no index path", log: $0, type: .info) }}
				else                       {NSLog("Got a delete object change type, but no index path")}
				return
			}
			groupedDeleteItems(at: [indexPath])
			
		case NSFetchedResultsChangeType.move.rawValue:
			guard let indexPath = indexPath, let newIndexPath = newIndexPath else {
				if #available(iOS 10.0, *) {di.log.flatMap{ os_log("Got a move object change type, but no index path or no new index path", log: $0, type: .info) }}
				else                       {NSLog("Got a move object change type, but no index path or no new index path")}
				return
			}
			switch fetchedResultsControllerMoveMode {
			case .deleteInsert:
				groupedDeleteItems(at: [indexPath])
				groupedInsertItems(at: [newIndexPath])
				
			case .move(reloadMode: let moveReloadMode):
				let reloadMode: FetchedResultsControllerReloadMode
				switch moveReloadMode {
				case .standard: reloadMode = fetchedResultsControllerReloadMode
				case .specific(let rm): reloadMode = rm
				}
				groupedMoveItem(at: indexPath, to: newIndexPath)
				handleUpdate(object: object, indexPathBeforeEndUpdates: indexPath, indexPathAfterEndUpdates: newIndexPath, reloadMode: reloadMode)
			}
			
		case NSFetchedResultsChangeType.update.rawValue:
			guard let indexPath = indexPath else {
				if #available(iOS 10.0, *) {di.log.flatMap{ os_log("Got an update object change type, but no index path", log: $0, type: .info) }}
				else                       {NSLog("Got an update object change type, but no index path")}
				return
			}
			handleUpdate(object: object, indexPathBeforeEndUpdates: indexPath, indexPathAfterEndUpdates: newIndexPath, reloadMode: fetchedResultsControllerReloadMode)
			
		default:
			(/* Core Data bug... */)
		}
	}
	
	private func handleUpdate(object: Any, indexPathBeforeEndUpdates: IndexPath, indexPathAfterEndUpdates: IndexPath?, reloadMode: FetchedResultsControllerReloadMode) {
		switch reloadMode {
		case .none: (/*nop*/)
		
		case .handler(let handler):
			guard let cell = cellForItem(at: indexPathBeforeEndUpdates) else {return}
			handler(cell, object, indexPathBeforeEndUpdates, indexPathAfterEndUpdates)
			
		/*UNSAFE_RELOAD: case .reload: postponedReloads!.append(indexPathAfterEndUpdates!)
		case .deleteInsert: groupedDeleteItems(at: [indexPathBeforeEndUpdates]); groupedInsertItems(at: [indexPathAfterEndUpdates!])*/
		}
	}
	
	func fetchedResultsControllerDidChangeContent(endUpdatesHandler: ((_ finished: Bool) -> Void)?) {
		endUpdates(handler: endUpdatesHandler)
		/*UNSAFE_RELOAD: reloadItems(at: postponedReloads!)
		postponedReloads = nil*/
	}
	
	enum FetchedResultsControllerMoveMode {
		
		/** When a move is received, the source index path is deleted, and the
		destination index path is inserted (batched). This is the “Typical Use”
		implementation in the documentation from Apple with a UITableView. */
		case deleteInsert
		/** When a move is received, the collection view is sent the moveRow
		message (batched). */
		case move(reloadMode: ReloadMode)
		
		public enum ReloadMode {
			
			/** Use the `fetchedResultsControllerReloadMode` set to the table view. */
			case standard
			/** Use this specific reload mode for the moves. */
			case specific(FetchedResultsControllerReloadMode)
			
		}
		
	}
	
	enum FetchedResultsControllerReloadMode {
		
		/** The reload of a cell will be done with the given handler. This is the
		way recommended by Apple in their “Typical Use” implementation with a
		UITableView. */
		case handler((_ cell: UICollectionViewCell, _ object: Any, _ collectionViewIndexPath: IndexPath, _ dataSourceIndexPath: IndexPath?) -> Void)
		
		/** The cell is never reloaded (for instance if the cell does KVO on the
		model it represent there are no need for any reload ever). */
		case none
		
		/* Modes below are disabled because mostly experimental. They should work
		as expected however, and can be uncommented if needed (uncomment all
		comments tagged with UNSAFE_RELOAD). */
		
		/**
		Delete and re-insert the cell.
		
		- Important: Do **not** use for the reload of a move as it systematically
		crashes (invalid data source update).
		
		Also not recommended because we have to use the undocumented newIndexPath
		for an update message from the Fetched Results Controller when using this
		mode. */
		/*UNSAFE_RELOAD: case deleteInsert*/
		
		/** The collection view will be sent a reloadRows message (not batched;
		the message is sent _after_ the batch). Not recommended because we have to
		use the undocumented newIndexPath for an update message from the Fetched
		Results Controller when using this mode. */
		/*UNSAFE_RELOAD: case reload*/
		
	}
	
	/*UNSAFE_RELOAD: private var postponedReloads: [IndexPath]? {
		get {return objc_getAssociatedObject(self, &keyFetchedResultsControllerPostponedReloads) as! [IndexPath]?}
		set {objc_setAssociatedObject(self, &keyFetchedResultsControllerPostponedReloads, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
	}*/
	
	private class ObjC_FetchedResultsControllerMoveModeWrapper {
		let moveMode: FetchedResultsControllerMoveMode
		init(_ mm: FetchedResultsControllerMoveMode) {moveMode = mm}
	}
	
	private class ObjC_FetchedResultsControllerReloadModeWrapper {
		let reloadMode: FetchedResultsControllerReloadMode
		init(_ rm: FetchedResultsControllerReloadMode) {reloadMode = rm}
	}
	
}
