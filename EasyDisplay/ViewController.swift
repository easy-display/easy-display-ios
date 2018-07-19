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

    func runMessages(messages: [Message]){
        messages.forEach { (msg) in
            let urlStr = msg.data
            let url = URL(string: urlStr)!
            let req = URLRequest(url: url)
            webView?.load(req)
        }
    }
    
    var manager : SocketManager?
    func connectSocket(){
        
        let host = "localhost:8999"
        let prot = "http"
        let namespace = "/mobile/0.1"
        let userId = 99
        let token = "Az_678987"
        let connectParams : [String : Any] = [
            "client_type" : "mobile",
            "user_id" : userId  ,
            "token" : token ]
        
        let url = URL(string: "\(prot)://\(host)")!

        manager = SocketManager(socketURL: url, config: [.log(true),  .compress, .connectParams(connectParams)])
        guard let manager = manager else {
            return
        }
        let socket = manager.socket(forNamespace: namespace)
        
        socket.on(clientEvent: .connect) {data, ack in
            print("socket connected")
        }
        
        socket.on("event_desktop_to_mobile")  {data, ack in
//            print("event_desktop_to_mobile:\n\n", data[0])
            
            guard let dict = data[0] as? Dictionary<String, Any> else {
                return
            }
            
            print("event_desktop_to_mobile:\n\n", type(of: dict))
            
            
            guard let arrayOfDict = dict["messages"] as? [Dictionary<String, Any>] else {
                return
            }
            
            print("event_desktop_to_mobile:\n\n", type(of: arrayOfDict))
            
            
            let msgs : [Message] = arrayOfDict.compactMap {

                if let name = $0["name"] as? String, let data = $0["data"] as? String {
                    return Message(name: name, data: data)
                }
                return nil
            }
            print("msgs:\n\n", msgs)
            self.runMessages(messages: msgs)

        }
        /*
        socket.on("currentAmount") {data, ack in
            guard let cur = data[0] as? Double else { return }
            
            socket.emitWithAck("canUpdate", cur).timingOut(after: 0) {data in
                socket.emit("update", ["amount": cur + 2.50])
            }
            
            ack.with("Got your currentAmount", "dude")
        }*/
        
        socket.connect()
    }
    
}

struct Message : Codable {
    
    let name: String
    let data: String
    
    init( name: String, data: String) {
        self.data = data
        self.name = name
    }
    
}


