//
//  AppDelegate.swift
//  SJLogger
//
//  Created by Hicreate on 01/05/2026.
//  Copyright (c) 2026 Hicreate. All rights reserved.
//

import UIKit
import SJLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // 启动SJLogger
        SJLogger.shared.start { config in
            // 配置日志记录
            config.isEnabled = true
            config.maxLogCount = 500
            config.logRequestBody = true
            config.logResponseBody = true
            config.showFloatingWindow = true
            config.printToConsole = false
            
            // 添加需要监控的URL模式（可选，不设置则监控所有）
            // config.addMonitoredURL(pattern: "api.example.com")
            
            // 添加需要忽略的URL模式
            // config.addIgnoredURL(pattern: ".*\\.png$")
            // config.addIgnoredURL(pattern: ".*\\.jpg$")
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

