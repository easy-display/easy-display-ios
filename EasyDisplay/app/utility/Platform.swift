//
//  Platform.swift
//  EasyDisplay
//
//  Created by Mohammed Tillawy on 9/13/18.
//  Copyright © 2018 MOH TILLAWY. All rights reserved.
//
// source: https://gist.github.com/samuelbeek/466981c098969a870d2c
//

struct Platform
{
    static let isSimulator: Bool = {
        var isSim = false
        #if arch(i386) || arch(x86_64)
        isSim = true
        #endif
        return isSim
    }()
}

