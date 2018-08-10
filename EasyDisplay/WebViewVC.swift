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

let EVENT_MOBILE_TO_DESKTOP = "event-mobile-to-desktop"
let EVENT_MOBILE_TO_SERVER = "event-mobile-to-server"
let EVENT_DESKTOP_TO_MOBILE = "event-desktop-to-mobile"
let MOBILE_CONNECTION_SUCCESS = "mobile-connection-success"


class WebViewVC: UIViewController, WKUIDelegate {

    var webView: WKWebView?
    
    var connection: Connection?
    
    @IBOutlet weak var viewContainer: UIView?
    @IBOutlet weak var buttonConnection: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        suggestShowingCameraIfNeeded()
    }
    
    func suggestShowingCameraIfNeeded(){
        if (self.connection == nil){
            let alert = UIAlertController(title: "QR Code", message: "Open Camera to scan QR Code?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
               self.loadCamera()
            }))
            present(alert, animated: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    alert.dismiss(animated: true, completion: {
                        self.loadCamera()
                    })
                }
            }
        }
    }
    
    func loadCamera(){
        let storyboard = UIStoryboard(name: "QRCode", bundle: Bundle.main)
        if let qrVC = storyboard.instantiateInitialViewController() as? QRCodeVC {
            qrVC.callbackConnection = { (con: Connection) -> () in
                DispatchQueue.main.async{
                   self.connectSocket(connection: con)
                }
            }
            present(qrVC, animated: true, completion: nil)
        }

    }
    
    @IBAction func ibActionDelme() {
        guard let manager = manager else {
            return
        }
        let socket = manager.defaultSocket
        socket.emit(EVENT_MOBILE_TO_SERVER , ["asdf" : "asdf"])
    }
    
    func setupWebView(){
        
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        guard let webView = webView else {
            return
        }
        guard let viewContainer = viewContainer else {
            return
        }
        webView.uiDelegate = self
        viewContainer.addSubview(webView)
        webView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(viewContainer)
            make.left.equalTo(viewContainer)
            make.bottom.equalTo(viewContainer)
            make.right.equalTo(viewContainer)
        }
        
        //let myURL = URL(string: "https://www.google.com/")
        let myURL = URL(string: "http://sensu.devops.arabiaweather.com/#/events")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
        webView.isUserInteractionEnabled = false
        
    }

    func runMessages(messages: [Message]){
        messages.forEach { (msg) in
            switch msg.name {
            
            case .EvaluateJS:
                let js = msg.dataString
                webView?.evaluateJavaScript(js, completionHandler: { (obj : Any?, error: Error? ) in
                    print("js: " , js)
                    print("error: " , error)
                })
            
            case .OpenURL:
                let urlStr = msg.dataString
                let url = URL(string: urlStr)!
                let req = URLRequest(url: url)
                webView?.load(req)


            case .Scroll:
                var x : CGFloat = 0.0 ,y: CGFloat = 0.0
                guard let currentPointX = webView?.scrollView.contentOffset.x else {return}
                guard let currentPointY = webView?.scrollView.contentOffset.y else {return}
                guard let currentScrollWidth = webView?.scrollView.contentSize.width else {return}
                guard let currentScrollHeight = webView?.scrollView.contentSize.height else {return}
                
                
                print("current size: (width:\(currentScrollWidth),height:\(currentScrollHeight))")
                print("current offset: (x:\(currentPointX),y:\(currentPointY))")
                
                let unit : CGFloat = 50
                
                if msg.dataNumber == 90 {
                    x = currentPointX + unit <= currentScrollWidth  ? unit : 0
                    y = 0
                } else if msg.dataNumber == 180 {
                    x = 0
                    y = currentPointY + unit <= currentScrollHeight ? unit : 0
                } else if msg.dataNumber == 270 {
                    x = currentPointX - unit >= 0 ? -unit : -currentPointX
                    y = 0
                } else if msg.dataNumber == 0 {
                    y = currentPointY - unit >= 0 ? -unit : -currentPointY
                    x = 0
                }

                let newX = currentPointX + x
                let newY = currentPointY + y
                print("new contentoffset (x:\(newX),y:\(newY))")
                webView?.scrollView.setContentOffset(CGPoint(x: newX, y: newY), animated: true)
            
            case .Reload:
                webView?.reload()
                
            default:
                print("unhandled \(msg.name) !!")
                
            }
            

        }
    }
    
    var manager : SocketManager?
    func connectSocket(connection: Connection){
        
        self.connection = connection
        
        guard let con = self.connection else {
            return
        }
        self.buttonConnection?.setTitle("Connecting ...", for: .normal)
        
        let namespace = "/mobile/\(con.version)"
        
        let connectParams : [String : Any] = [
            "client_type" : "mobile" ,
            "token" : con.token
        ]
        
        let url = URL(string: "\(con.scheme)://\(con.host)")!

        manager = SocketManager(socketURL: url, config: [.log(true),  .compress, .connectParams(connectParams)])
        guard let manager = manager else {
            return
        }
        let socket = manager.socket(forNamespace: namespace)
        
        socket.on(clientEvent: .connect) {data, ack in
            print("socket connected!")
            DispatchQueue.main.async{
                self.buttonConnection?.setTitle("Connected", for: .normal)
                let msgs : [Message] = [Message(name: MOBILE_CONNECTION_SUCCESS, dataString: "", dataNumber: 0)];
                let encoder = JSONEncoder()
                let d = try! encoder.encode(msgs)
                let json = String(data: d, encoding: .utf8)!
//                print( json )
                socket.emit( EVENT_MOBILE_TO_DESKTOP , json)
            }
        }
        
        socket.on(clientEvent: .error) {data, ack in
            var message = "Unkown Error"
            if let arr = data as? Array<String>, arr.count > 0 {
                message = arr[0]
            }
            let ac = UIAlertController(title: "Error", message: message , preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(ac, animated: true, completion: nil)
        }
        
        
        socket.on(clientEvent: .disconnect) {data, ack in
            print("socket disconnected!")
            DispatchQueue.main.async{
                self.buttonConnection?.setTitle("Disconnected", for: .normal)
            }
        }
        
        
        socket.on(clientEvent: .statusChange) {data, ack in
            print("socket disconnected!")
            DispatchQueue.main.async{
                self.buttonConnection?.setTitle(" ????? ", for: .normal)
            }
        }

        socket.on(EVENT_DESKTOP_TO_MOBILE)  {data, ack in
            print("\(EVENT_DESKTOP_TO_MOBILE) :\n\n", data)
            
            guard let dict = data[0] as? Dictionary<String, Any> else {
                return
            }
            
            print("\(EVENT_DESKTOP_TO_MOBILE):\n\n", type(of: dict))
            
            
            guard let arrayOfDict = dict["messages"] as? [Dictionary<String, Any>] else {
                return
            }
            
            print("\(EVENT_DESKTOP_TO_MOBILE):\n\n", type(of: arrayOfDict))
            
            
            let msgs : [Message] = arrayOfDict.compactMap {

                if let name = $0["name"] as? String,
                    let str = $0["dataString"] as? String,
                    let num = $0["dataNumber"] as? Double
                {
                    return Message(name: name, dataString: str, dataNumber: num)
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



enum MessageName: String, Codable
{
    case Unkown = "unknown"
    case OpenURL = "open_url"
    case EvaluateJS = "evaluate_js"
    case Scroll = "scroll"
    case Reload = "reload"
    case MobileConnectionLost = "mobile-connection-lost"
    case MobileConnectionSuccess = "mobile-connection-success"
    case DesktopConnectionLost = "desktop-connection-lost"
    case DesktopConnectionSuccess = "desktop-connection-success"
}

struct Message : Codable {
    
    let name: MessageName
    let dataString: String
    let dataNumber: Double
    
    init( name: String, dataString: String, dataNumber: Double) {
        self.dataString = dataString
        self.dataNumber = dataNumber
        var n = MessageName.Unkown
        if let n2 = MessageName(rawValue: name) {
            n = n2
        }
        self.name = n
    }
    
}


