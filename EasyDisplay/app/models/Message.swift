//
//  Message.swift
//  EasyDisplay
//
//  Created by Mohammed Tillawy on 10/22/18.
//  Copyright © 2018 MOH TILLAWY. All rights reserved.
//

import Foundation



enum MessageName: String, Codable
{
    case Unkown = "unknown"
    case OpenURL = "open_url"
    case EvaluateJS = "evaluate_js"
    case EvaluateJsOutput = "evaluate_js_output"
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



