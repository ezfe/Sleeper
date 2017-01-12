//
//  AppDelegate.swift
//  Sleeper
//
//  Created by Ezekiel Elin on 12/14/16.
//  Copyright © 2016 Ezekiel Elin. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        return true
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handle(shortcutItem: shortcutItem)
    }
    
    func handle(shortcutItem: UIApplicationShortcutItem) {
        print("Handling...")
        
        let delegate = UIApplication.shared.delegate as! AppDelegate
        let vc = delegate.window!.rootViewController as! ViewController
        
        switch shortcutItem.type {
        case "com.ezekielelin.sleeper.sleep":
            vc.sleepButtonPress()
            break
        case "com.ezekielelin.sleeper.wake":
            vc.wakeButtonPress()
            break
        default:
            print("No action defined...")
        }
    }
}

