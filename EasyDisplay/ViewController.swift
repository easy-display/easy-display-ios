//
//  ViewController.swift
//  EasyDisplay
//
//  Created by Mohammed Tillawy on 7/13/18.
//  Copyright © 2018 MOH TILLAWY. All rights reserved.
//

import UIKit
import WebKit
import SnapKit
import SocketIO

class ViewController: UIViewController, WKUIDelegate {

    var webView: WKWebView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadWebView()
        connectSocket()
    }
    
    @IBAction func ibActionDelme() {
        guard let manager = manager else {
            return
        }
        let socket = manager.defaultSocket
        socket.emit("event_to_server", ["asdf" : "asdf"])
    }
    
    func loadWebView(){
        
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        guard let webView = webView else {
            return
        }
        webView.uiDelegate = self
        view.addSubview(webView)
        webView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(view).offset(100)
            make.left.equalTo(view)
            make.bottom.equalTo(view)
            make.right.equalTo(view)
        }
        
        let myURL = URL(string: "https://devdocs.io/")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
        
    }

    var manager : SocketManager?
    func connectSocket(){
        
        manager = SocketManager(socketURL: URL(string: "http://localhost:8999")!, config: [.log(true), .compress])
        guard let manager = manager else {
            return
        }
        let socket = manager.defaultSocket
        
        socket.on(clientEvent: .connect) {data, ack in
            print("socket connected")
        }
        
        socket.on("event_to_client")  {data, ack in
            print("event_to_client ....",data)
            socket.emit("event_to_server", ["asdf" : "asdf"])
        }
        socket.on("currentAmount") {data, ack in
            guard let cur = data[0] as? Double else { return }
            
            socket.emitWithAck("canUpdate", cur).timingOut(after: 0) {data in
                socket.emit("update", ["amount": cur + 2.50])
            }
            
            ack.with("Got your currentAmount", "dude")
        }
        
        socket.connect()
    }
    
}

