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



let PAIRING_REQUIRED_URL = "https://www.easydisplay.info/ios-app-pairing-required"
let PAIRING_SUCCESS_URL = "https://www.easydisplay.info/ios-app-pairing-success"


let INVALID_TOKEN = "invalid-token";

let K_DEFAULTS_CONNECTION = "K_DEFAULTS_CONNECTION"
let K_DEFAULTS_LAST_USED_URL = "K_DEFAULTS_LAST_USED_URL"


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
        
        
//        let template = try GRMustacheTemplate(from: "{{name}}")
//        let rendering = template.rend

    }


    
    func lastUsedUrl() -> String?{
        let str = UserDefaults.standard.string(forKey: K_DEFAULTS_LAST_USED_URL)
        return str
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        SVProgressHUD.dismiss()
        activityIndicatorView?.isHidden = true
        buttonAddress?.setTitle(webView.url?.absoluteString, for: .normal)
        saveLastUsedUrl(urlString: webView.url?.absoluteString)
    }
    
    func saveLastUsedUrl(urlString: String?){
        if (urlString?.contains("easydisplay.info") == true){
            return
        }
        UserDefaults.standard.set(urlString, forKey: K_DEFAULTS_LAST_USED_URL)
        UserDefaults.standard.synchronize()
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
            let title = "Time to pair with desktop app"
            let message = "Please open the desktop app and use the camera to scan QR Code?"
            let alert = UIAlertController(title: title , message:message , preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Open Camera", style: .default, handler: { (action) in
               self.loadCamera()
            }))
            present(alert, animated: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
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
        webConfiguration.applicationNameForUserAgent = "EasyDisplay"
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        guard let webView = webView else {
            return
        }
        webView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 11_0 like Mac OS X) AppleWebKit/604.1.34 (KHTML, like Gecko) Version/11.0 Mobile/15A5341f Safari/604.1"
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
        webviewLoadUrl(url: PAIRING_REQUIRED_URL)
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
                    print("EvaluateJS js: \n\t" , js)
                    if let str = obj as? String {
                        print("evaluateJavaScript result: \n\n\t" , str, "\n\n")
                        self.emitMessage(to: EVENT_MOBILE_TO_DESKTOP, name: .EvaluateJsOutput, dataString: str)
                    }
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
        self.alertControllerSocketError?.dismiss(animated: true, completion: nil)
        
        alertContollerResetPairing = UIAlertController(title: "Something went wrong", message: "Would you like to restart the pairing process?", preferredStyle: .alert)
        alertContollerResetPairing?.addAction(UIAlertAction(title: "Reset", style: .default, handler: { (a: UIAlertAction) in
            self.resetAndShowCamera()
        }))
        alertContollerResetPairing?.addAction(UIAlertAction(title: "No, wait.", style: .default, handler: nil))
        present(alertContollerResetPairing!, animated: true, completion: nil)
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
    
    var alertControllerSocketError: UIAlertController?
    var alertContollerResetPairing: UIAlertController?
    
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

            
            self.alertControllerSocketError = UIAlertController(title: "Error", message: message , preferredStyle: .alert)
            self.alertControllerSocketError?.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(self.alertControllerSocketError!, animated: true, completion: nil)
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
                        self.alertControllerSocketError?.dismiss(animated: true, completion: nil)
                        self.alertContollerResetPairing?.dismiss(animated: true, completion: nil)
//                        if let url = self.webView?.url , !url.absoluteString.contains("easydisplay.info") {}
                        self.webviewLoadUrl(url: self.lastUsedUrl() ?? PAIRING_SUCCESS_URL)
                        
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

