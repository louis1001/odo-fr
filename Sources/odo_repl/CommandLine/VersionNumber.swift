//
//  VersionNumber.swift
//  
//
//  Created by Luis Gonzalez on 27/1/23.
//

import odolib

func printVersion(long: Bool) {
    let logo = """
          ###############
       #####################
     #######           ••••••
     ######             ••••••
     ######             ••   •
     ######             ••••••
     ########         •••••••
       #####################
          ###############
    """
    let versionString = """
          odo(-lang) \(Odo.versionNumber)
     Luis Gonzalez (louis1001)
             2019-2022
    """
    
    if long {
        print(logo)
        print(versionString)
    } else {
        print(versionString)
    }
}
