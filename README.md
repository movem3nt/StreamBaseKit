# StreamBaseKit - UI toolkit for Firebase

StreamBaseKit is a Swift UI toolkit for [Firebase](https://www.firebase.com).  It surfaces Firebase queries as streams that are synched with Firebase in real time, and can be incrementally fetched, combined, or split into multiple sections.

## Installing StreamBaseKit

Using Cocoapods, add to your `Podfile`:

```
pod 'StreamBaseKit', '~> 0.1'
```

And, if you don't have it already:

```
platform :ios, '8.0'
use_frameworks!
```

## Getting Started with StreamBaseKit:

If you don't have one already, sign up for a [Firebase account](https://www.firebase.com/signup/).

To use StreamBaseKit, you'll want to know about these classes:

Class  |  Description
-------|-------------
StreamBase | This is the main class that exposes a Firebase query as a Stream.
StreamBaseItem | Base class for objects that appear in streams.
StreamBaseDelegate | Delegate that is notified of stream changes.
StreamTableViewAdapter | Adapter from streams to UITableViews.
PartitionedStream | Split a stream into multiple sections.
TransientStream |  Stream that's not connected to Firebase.
UnionStream |  Stream for merging multiple streams.
QueryBuilder | Helper for composing Firebase queries.

To get started, you'll need to build from StreamBaseItem and StreamBase.  Additionally, StreamTableViewAdapter provides some convenient functionality to connect streams with tables.  Here's the basic outline:

```swift

MyItem.swift

class MyItem : StreamBaseItem {
  var name: String?

  func update(dict: [String: AnyObject) {
    super.update(dict)
    name = dict["name"] as? String
  }

  var dict: [String: AnyObject] {
    var d = super.dict
    d["name"] = name
    return d
  }
}

MyViewController.swift

class MyViewController : UIViewController {
  var stream: StreamBase!
  var adapter: StreamTableViewAdapter!
  // etc...

  override func viewDidLoad() {
    // etc...

    let firebaseRef = Firebase(url:"https://<YOUR-FIREBASE-APP>.firebaseio.com/")
    stream = StreamBase(type: MyItem.self, ref: firebaseRef)
    adapter = StreamTableViewAdapter(tableView: tableView)
    stream.delegate = adapter
  }
}

extension MyViewController : UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return stream.count
  } 

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("MyCell", forIndexPath: indexPath)
    let item = stream[indexPath.row] as! MyItem
    cell.titleLabel?.text = item.name 
    return cell
  }
}
```

## Multiple Sections with PartitionedStream

PartitionedStream allows you to define a partition function for splitting a stream into mulitple sections.  This is useful, eg, in splitting a roster of users into organizers and participants.  Building off of the previous example:

```swift

User.swift

class User : StreamBaseItem {
  var isOrganizer: Bool
  // etc...
}

MyViewController.swift

class MyViewController : UIViewController {
  var pstream: PartitionedStream!
  // etc...

  override func viewDidLoad() {
    // etc...
    pstream = PartitionedStream(stream: stream, sectionTitles: ["organizers", "participants"]) { ($0 as! User).isOrganizer ? 0 : 1 }
    pstream.delegate = adapter
  }
} 

extension MyViewController : UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return pstream[section].count
  } 

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("MyCell", forIndexPath: indexPath)
    let item = pstream[indexPath] as! User  // Index partitioned stream with whole NSIndexPath
    cell.titleLabel?.text = item.name 
    return cell
  }

  func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return pstream.sectionTitles[section]
  }
}

```

## Multiple Sections with Multiple Streams

PartitionedStream is convenient to use, but if the underlying data has hundreds or more elements you'll need to provide limits per section.  You can do this by constructing multiple sections like this:

```swift

class MyViewController : UIViewController {
  var organizerStream: StreamBase!
  var participantStream: StreamBase!
  var organizerAdapter: StreamTableViewAdapter!
  var participantAdapter: StreamTableViewAdapter!
  // etc...

  override func viewDidLoad() {
    // etc...
    let organizerQuery = QueryBuilder(ref)
    organizerQuery.limit = 100
    organizerQuery.ordering = .Child("is_organizer")
    organizerQuery.start = true
    organizerStream = StreamBase(type: User.self, queryBuilder: organizerQuery)
    organizerAdapter = StreamTableViewAdapter(tableView: tableView, section: 0)

    let participantQuery = QueryBuilder(ref)
    participantQuery.limit = 100
    participantQuery.ordering = .Child("is_organizer")
    participantQuery.end = false
    participantStream = StreamBase(type: User.self, queryBuilder: participantQuery)
    participantAdapter = StreamTableViewAdapter(tableView: tableView, section: 1)
  }
}
  
extension MyViewController : UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return (section == 0) ? organizerStream.count : participantStream.count
  } 

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("MyCell", forIndexPath: indexPath)
    let user: User
    if indexPath.section == 0 {
      user = organizerStream[indexPath.row] as! User
    } else {
      user = participantStream[indexPath.row] as! User
    }
    // etc...
    return cell
  }
}
```

## Placeholders and Incremental Fetching with TransientStream and UnionStream

Chat histories can grow long, so it's important to enable them to be incrementally fetched.  To do this, we need to be able to insert temporary placeholders into the table to provide a ui for the fetch, and to actually perform the additional fetch.  There are further details (such as knowing the actual size of the stream!), but this is a rough sketch of how this would work:

```swift

class MyViewController : UIViewController {
  let maxToFetch = 100
  var stream: StreamBase!
  var unionStream: UnionStream!
  var transientStream: TransientStream!
  var fetchmore: FetchMoreItem?

  override func viewDidLoad() {
    // etc...
    stream = StreamBase(type: MyItem.self, ref: firebaseRef, ascending: false, limit: maxToFetch)
    transient = TransientStream()
    unionStream = UnionStream(sources: stream, transient)
    unionStream.delegate = self
  }

  func fetchMoreTapped(sender: UIButton) {
    stream.fetchMore(maxToFetch, start: stream[0].key!) {
      transient.remove(fetchmore)
      fetchmore = nil
    }
  }
}
```

Here we extend the StreamBaseDelegate rather than use the StreamTableViewAdapter because we need to manipulate state in the controller.

```swift
extension MyViewController : StreamBaseDelegate {
  override func streamDidFinishInitialLoad(error: NSError?) {
    super.streamDidFinishInitialLoad(error)
    if stream.count > maxToFetch {
      fetchmore = FetchMoreItem(key: dropLast(stream[0].key))
      transient.add(fetchmore)
    }
  }
}

```


# Comparison with FirebaseUI-iOS

[FirebaseUI-iOS](https://github.com/firebase/FirebaseUI-iOS) is the official client library for Firebase.  It's written in Objective-C instead of Swift, and is simpler overall.  StreamBaseKit grew out of a real world social application and addresses a variety of problems encountered in doing so.  For example, ios table views are designed for insertion on top, and Firebase appends new data.  To make these work well together for messaging-type apps, one needs to invert both the firebase collection and the table view.  StreamBaseKit also makes it easy to add more complex functionality like splitting a collection into multiple table sections, and inserting transient content into the table like a "fetch more" control for incremental fetching.

Another consideration is that Firebase also has a Android UI library. StreamBaseKit does not (yet).
