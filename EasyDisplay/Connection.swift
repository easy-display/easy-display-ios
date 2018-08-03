//
//  Connection.swift
//  EasyDisplay
//
//  Created by Mohammed Tillawy on 7/31/18.
//  Copyright © 2018 MOH TILLAWY. All rights reserved.
//

import Foundation


enum SchemeEnum: String, Codable
{
    case Http = "http"
    case Https = "https"
}

let namespace = "/mobile/0.1"

struct Connection: Codable {
    
    let host: String
    let scheme: SchemeEnum
    let version: String
    let token: String
    
    init(host: String, scheme: String, token: String, version: String ){
        self.host = host
        self.token = token
        self.version = version
        var p1 = SchemeEnum.Https
        if let p2 = SchemeEnum(rawValue: scheme){
            p1 = p2
        }
        self.scheme = p1
    }
    
}
