//
//  ViewController.swift
//  StreamBaseExample
//
//  Created by Steve Farrell on 9/14/15.
//  Copyright (c) 2015 Movem3nt. All rights reserved.
//

import UIKit
import SlackTextViewController
import StreamBaseKit

class ViewController: SLKTextViewController {
    
    var resourceContext: ResourceContext!
    var stream: StreamBase!
    var adapter: StreamTableViewAdapter!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        inverted = true
        
        resourceContext = ResourceContext(base: Environment.sharedEnv.resourceBase, resources: nil)
        stream = StreamBase(type: Message.self, ref: resourceContext.collectionRef(Message.self), limit: nil, ascending: false)
        adapter = StreamTableViewAdapter(tableView: tableView)
        stream.delegate = adapter
    }
    
    override func didPressRightButton(sender: AnyObject!) {
        let message = Message()
        message.username = UIDevice.currentDevice().name
        message.text = textView.text
        textView.text = nil
        resourceContext.create(message)
    }
}

extension ViewController : UITableViewDataSource {
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stream.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .Subtitle, reuseIdentifier: nil)
        let message = stream[indexPath.row] as! Message
        cell.textLabel?.text = message.text
        cell.detailTextLabel?.text = message.username
        cell.transform = tableView.transform  // Because inverted=true
        return cell
    }
}
