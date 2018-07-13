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

class ViewController: UIViewController, WKUIDelegate {

    var webView: WKWebView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        guard let webView = webView else {
            return
        }
        webView.uiDelegate = self
        view.addSubview(webView)
        webView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(view)
            make.left.equalTo(view)
            make.bottom.equalTo(view)
            make.right.equalTo(view)
        }
        
        let myURL = URL(string: "https://devdocs.io/")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
        
    }


}

