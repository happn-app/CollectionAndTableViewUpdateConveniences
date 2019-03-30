# CollectionAndTableViewUpdateConveniences ![Platforms](https://img.shields.io/badge/platform-iOS-lightgrey.svg?style=flat) [![Carthage compatible](https://img.shields.io/badge/carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![License](https://img.shields.io/github/license/happn-tech/CollectionAndTableViewUpdateConveniences.svg)](License.txt) [![happn](https://img.shields.io/badge/from-happn-0087B4.svg?style=flat)](https://happn.com)

Easily handle `NSFetchedResultsController` updates in a `UITableView` or a `UICollectionView`.

## What’s this for?
CoreData has a wonderful tool called `NSFetchedResultsController`. This tool allows
receiving notifications when an object matching a specific set of requirements (`NSPredicate`)
is created or deleted in an `NSManagedObjectContext`. Whenever such objects are created or
deleted, you can tell a corresponding `UITableView` or `UICollectionView` to insert/delete
rows accordingly.

For a `UITableView`, it is relatively easy to do. Apple does provide a CoreData Master/Detail
project template which has all of the code to do it too.

With a `UICollectionView`, it is a bit more tricky (because grouped updates are done via a
handler instead of using the `beginUpdates`/`endUpdates` methods).

This project makes it easy for a `UICollectionView` (and easier for a `UITableView`) to use
the `NSFetchedResultsController` class in a CoreData project: receive the notifications
from the results controller and just forward them to your table or collection view directly.

## Example of use
```swift
/* *** Collection View Setup *** */

/* First, how to handle a reload of a cell? */
collectionView.fetchedResultsControllerReloadMode = .handler({ [weak self] cell, object, collectionViewIndexPath, dataSourceIndexPath in
   self?.setup(cell: cell as! MyCellType, with: object as! MyObjectType)
})
/* Next, when a cell moves, what to do? Here, we do a move (other solution
 * is to delete/insert the cell).
 * When a cell is moved, it must be reloaded too. We say we want the
 * standard reload mode (the one we have defined above). */
collectionView.fetchedResultsControllerMoveMode = .move(reloadMode: .standard)



/* *** Handling the NSFetchedResultsController notifications *** */

/* We simply forward the methods to the collection view */
func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
   collectionView.fetchedResultsControllerWillChangeContent()
}
func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
   collectionView.fetchedResultsControllerDidChange(section: sectionInfo, atIndex: sectionIndex, forChangeType: type)
}
func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
   collectionView.fetchedResultsControllerDidChange(object: anObject, atIndexPath: indexPath, forChangeType: type, newIndexPath: newIndexPath)
}
func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
   collectionView.fetchedResultsControllerDidChangeContent(endUpdatesHandler: nil)
}
```

## Installation
The project is compatible with Carthage.

You can also simply copy the two `UICollectionView` extensions and the `UITableView` extension in your project.

## Credits
This project was originally created by [François Lamboley](https://github.com/Frizlab) while working at [happn](https://happn.com).
