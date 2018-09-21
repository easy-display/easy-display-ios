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
import SVProgressHUD


let EVENT_MOBILE_TO_DESKTOP = "event-mobile-to-desktop"
let EVENT_MOBILE_TO_SERVER = "event-mobile-to-server"
let EVENT_DESKTOP_TO_MOBILE = "event-desktop-to-mobile"
let EVENT_SERVER_TO_MOBILE = "event-server-to-mobile"
let MOBILE_CONNECTION_SUCCESS = "mobile-connection-success"

let INVALID_TOKEN = "invalid-token";

let K_DEFAULTS_CONNECTION = "K_DEFAULTS_CONNECTION"


class WebViewVC: UIViewController, WKUIDelegate, WKNavigationDelegate {

    var webView: WKWebView?
    var connection: Connection?
    
    @IBOutlet weak var viewContainer: UIView?
    @IBOutlet weak var buttonConnection: UIButton?
    @IBOutlet weak var activityIndicatorView : UIActivityIndicatorView?
    @IBOutlet weak var buttonAddress: UIButton?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupButtonAddress()
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: nil) { (notif) in
            self.emitMessage(to: EVENT_MOBILE_TO_DESKTOP, name: .MobileToBackground)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) { (notif) in
            self.emitMessage(to: EVENT_MOBILE_TO_DESKTOP, name: .MobileIsForeground)
        }

        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        SVProgressHUD.dismiss()
        activityIndicatorView?.isHidden = true
        buttonAddress?.setTitle(webView.url?.absoluteString, for: .normal)
    }
    
    func emitMessage(to: String ,name: MessageName, dataString: String = "" , dataNumber: Double = 0){
        guard let socket = socket else { return }
        if (socket.status != .connected){
            print("Error: emitMessage while still not connected")
            return
        }
        let msg = messageWith(name: name, dataString: dataString, dataNumber: dataNumber)
        socket.emit( to , msg )
    }
    
    func setupButtonAddress(){
        self.buttonAddress?.setTitle("", for: .normal)
        self.buttonAddress?.layer.cornerRadius = 3
    }
    
    func messageWith( name: MessageName, dataString: String = "" , dataNumber: Double = 0) -> String {
        let msgs : [Message] = [Message(name: name, dataString: dataString, dataNumber: dataNumber)]
        let encoder = JSONEncoder()
        let d = try! encoder.encode(msgs)
        let json = String(data: d, encoding: .utf8)!
//                print( json )
        return json
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let conn = self.loadSavedConnectionInUserDefaults() {
            self.connectSocket(connection: conn)
        } else {
            suggestShowingCameraIfNeeded()
        }
    }
    
    
    private func saveConnectionInUserDefaults(connection: Connection){
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(connection) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: K_DEFAULTS_CONNECTION)
        }
    }
    
    private func loadSavedConnectionInUserDefaults() -> Connection?{
        let defaults = UserDefaults.standard
        if let savedConnection = defaults.object(forKey: K_DEFAULTS_CONNECTION) as? Data {
            let decoder = JSONDecoder()
            if let loadedConnection = try? decoder.decode(Connection.self, from: savedConnection) {
                return loadedConnection
            }
        }
       return nil
    }
    
    private func removeSavedConnectionFromUserDefaults(){
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: K_DEFAULTS_CONNECTION)
        defaults.synchronize()
        self.connection = nil
    }
    
    
    @IBAction func ibActionConnectionButton(_ sender: UIButton) {

        if (self.socket?.status == SocketIOStatus.connected){
            let alert = UIAlertController(title: "App is Connected", message: "Disconnect?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) in
                self.manager?.disconnect()
                self.loadCamera()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true)
        }
        if (self.socket?.status == SocketIOStatus.connecting){
            self.loadCamera()
        }
        
    }
    
    func suggestShowingCameraIfNeeded(){
        if (Platform.isSimulator){
            self.connectSocket(connection: Connection(host: "localhost", scheme: "http", token: "SIMULATOR", version: "0.1"))
            return
        }
        if (self.connection == nil){
            let alert = UIAlertController(title: "QR Code", message: "Open Camera to scan QR Code?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
               self.loadCamera()
            }))
            present(alert, animated: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    alert.dismiss(animated: true, completion: {
                        self.loadCamera()
                    })
                }
            }
        }
    }
    
    func loadCamera(){
        self.resetSavedConnection()
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
        webView.navigationDelegate = self
        viewContainer.addSubview(webView)
        webView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(viewContainer)
            make.left.equalTo(viewContainer)
            make.bottom.equalTo(viewContainer)
            make.right.equalTo(viewContainer)
        }
        
        activityIndicatorView?.isHidden = false
        webviewLoadUrl(url: pairingRequiredPageURL)
        webView.isUserInteractionEnabled = true
        
    }

    
    func webviewLoadUrl(url: String){
        SVProgressHUD.show()
        if let url = URL(string: url) {
            let myRequest = URLRequest(url: url)
            webView?.load(myRequest)
        } else {
            SVProgressHUD.dismiss()
            let alert = UIAlertController(title: "Error", message: "Invalid URL: '\(url)'", preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .default, handler: nil)
            alert.addAction(action)
            present(alert, animated: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    alert.dismiss(animated: true, completion: nil)
                }
            }
            
        }
    }
    
    
    
    let pairingRequiredPageURL = "https://www.easydisplay.info/ios-app-pairing-required"
    
    let pairingSuccessPageURL = "https://www.easydisplay.info/ios-app-pairing-success"
    
    
    func runMessages(messages: [Message]){
        messages.forEach { (msg) in
            
            print("runMessages message: \(msg.name)")
            
            switch msg.name {
            
            case .NewSyncRequired:
                self.manager?.disconnect()
                self.loadCamera()
                
            case .DesktopConnectionLost:
                print("DesktopConnectionLost")
    
            case .EvaluateJS:
                activityIndicatorView?.isHidden = false
                let js = msg.dataString
                webView?.evaluateJavaScript(js, completionHandler: { (obj : Any?, error: Error? ) in
                    print("EvaluateJS js: " , js)
                    if let err = error {
                        print("EvaluateJS error: " , err.localizedDescription)
                    }
                    self.activityIndicatorView?.isHidden = true
                })
            
            case .OpenURL:
                activityIndicatorView?.isHidden = false
                let urlStr = msg.dataString
                self.webviewLoadUrl(url: urlStr)


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
                SVProgressHUD.show()
                activityIndicatorView?.isHidden = false
                webView?.reload()
                
            default:
                print("unhandled \(msg.name) !!")
                
            }
            

        }
    }
    
    
    func extractMessages(data: [Any]) -> [Message]?
    {
        /*guard let dict = data[0] as? Dictionary<String, Any> else {
            return nil
        }*/
        guard let arrayOfDict = data[0] as? [Dictionary<String, Any>] else {
            return nil
        }
        let msgs : [Message] = arrayOfDict.compactMap {
            
            if let name = $0["name"] as? String,
                let str = $0["dataString"] as? String,
                let num = $0["dataNumber"] as? Double
            {
                guard let messageName = MessageName( rawValue: name) else {
                    return nil
                }
                return Message(name: messageName, dataString: str, dataNumber: num)
            }
            return nil
        }
        return msgs
    }
    
    
    var manager : SocketManager?
    var socket: SocketIOClient?
    
    func resetSavedConnection(){
        closeExistingSocketIfExists()
        removeSavedConnectionFromUserDefaults()
    }
    
    func suggestResetAndShowCamera(){
        let ac = UIAlertController(title: "Something went wrong", message: "Would you like to restart the pairing process?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Reset", style: .default, handler: { (a: UIAlertAction) in
            self.resetAndShowCamera()
        }))
        ac.addAction(UIAlertAction(title: "No, wait.", style: .default, handler: nil))
        present(ac, animated: true, completion: nil)
    }
    
    func resetAndShowCamera(){
        resetSavedConnection()
        suggestShowingCameraIfNeeded()
    }
    
    func closeExistingSocketIfExists(){
        if let s = socket {
            s.disconnect()
            socket = nil
        }
    }
    
    var socketErrorsAlert: UIAlertController?
    
    func connectSocket(connection: Connection){
        
        SVProgressHUD.show(withStatus: "Connecting, Please Wait")
        removeSavedConnectionFromUserDefaults()
        closeExistingSocketIfExists()
        
        self.connection = connection
        
        guard let con = self.connection else {
            return
        }
        self.buttonConnection?.setTitle("Connecting ...", for: .normal)
        self.buttonConnection?.setTitleColor(UIColor.green, for: .normal)
        
        let namespace = "/mobile/\(con.version)"
        
        let connectParams : [String : Any] = [
            "client_type" : "mobile" ,
            "token" : con.token
        ]
        
        let url = URL(string: "\(con.scheme)://\(con.host)")!
        let isSecure = con.scheme.rawValue == "https"
        manager = SocketManager(socketURL: url, config: [ .log(true), .secure(isSecure) , .compress, .connectParams(connectParams)])
        guard let manager = manager else {
            return
        }
        socket = manager.socket(forNamespace: namespace)
        guard let socket = socket else {
            return
        }
    
        
        socket.on(clientEvent: .connect) {data, ack in
            print("socket connected!")
            SVProgressHUD.dismiss()
            DispatchQueue.main.async{
                self.buttonConnection?.setTitle("Pairing ...", for: .normal)
                self.buttonConnection?.setTitleColor(UIColor.yellow, for: .normal)
            }
            
        }
        
        socket.on(clientEvent: .error) {data , ack in
            SVProgressHUD.dismiss()
            var message = "Unkown Error"
            if let arr = data as? Array<String>, arr.count > 0 {
                message = arr[0]
                print("socket.on(clientEvent: .error): \n\(message)")
            }
            
            if (message == "The request timed out."){
                print("socket.on(clientEvent: .error): \n\(message)")
                self.suggestResetAndShowCamera()
            }
            if (message == "Could not connect to the server."){
                print("socket.on(clientEvent: .error): \n\(message)")
                self.suggestResetAndShowCamera()
            }
            
            if (message == "Tried emitting when not connected"){
                assert(false,"Tried emitting when not connected, review your code")
            }

            
            self.socketErrorsAlert = UIAlertController(title: "Error", message: message , preferredStyle: .alert)
            self.socketErrorsAlert?.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(self.socketErrorsAlert!, animated: true, completion: nil)
        }
        
        
        socket.on(clientEvent: .disconnect) {data, ack in
            print("socket disconnected!")
            SVProgressHUD.dismiss()
            DispatchQueue.main.async{
                self.buttonConnection?.setTitle("Disconnected", for: .normal)
                self.buttonConnection?.setTitleColor(UIColor.red, for: .normal)
            }
        }
        
        
        socket.on(clientEvent: .statusChange) {data, ack in
            print("socket statusChange", data)
            SVProgressHUD.dismiss()
            DispatchQueue.main.async{
                guard let status = self.socket?.status else { return }
                self.buttonConnection?.setTitle("\(status)", for: .normal)
                self.buttonConnection?.setTitleColor(UIColor.red, for: .normal)
            }
        }

        socket.on(EVENT_SERVER_TO_MOBILE) {data, ack in
            print("\(EVENT_SERVER_TO_MOBILE) :\n\n", data)
            
            if let msgs = self.extractMessages(data: data){
                
                if let msg = msgs.first, msg.name == .ConnectionFailure, msg.dataString == INVALID_TOKEN {
                    self.resetAndShowCamera()
                    return
                }
                
                if let msg = msgs.first, msg.name == .MobileConnectionSuccess {
                    self.saveConnectionInUserDefaults(connection: connection)
                    
                    DispatchQueue.main.async{
                        self.buttonConnection?.setTitle("Connected", for: .normal)
                        self.buttonConnection?.setTitleColor(UIColor.lightGray, for: .normal)
//                        let msgs : [Message] = [Message(name: .MobileConnectionSuccess, dataString: "", dataNumber: 0)];
//                        let encoder = JSONEncoder()
//                        let d = try! encoder.encode(msgs)
//                        let json = String(data: d, encoding: .utf8)!
                        self.emitMessage(to: EVENT_MOBILE_TO_DESKTOP, name: .MobileConnectionSuccess)
                        self.socketErrorsAlert?.dismiss(animated: true, completion: nil)
                        if let url = self.webView?.url , !url.absoluteString.contains("easydisplay.info") {
                            self.webviewLoadUrl(url: self.pairingSuccessPageURL)
                        }
                        
                        
                    }
                    
                    return
                }
                
                self.runMessages(messages: msgs)
            }

        }
        
        
        socket.on(EVENT_DESKTOP_TO_MOBILE)  {data, ack in
            print("\(EVENT_DESKTOP_TO_MOBILE) :\n\n", data)
            SVProgressHUD.showInfo(withStatus: "Request Received.")
            if let msgs = self.extractMessages(data: data){
                self.runMessages(messages: msgs)
            }

        }
        
        
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
    case MobileToBackground = "mobile-to-backgound"
    case MobileIsForeground = "mobile-is-foreground"
    case NewSyncRequired = "new-sync-required"
    case ConnectionFailure = "connection-failure";
}



struct Message : Codable {
    
    let name: MessageName
    let dataString: String
    let dataNumber: Double
    
    init( name: MessageName, dataString: String, dataNumber: Double) {
        self.dataString = dataString
        self.dataNumber = dataNumber
        self.name = name
    }
    
}




