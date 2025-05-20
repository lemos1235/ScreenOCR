//
//  AppDelegate.swift
//  Screen OCR Helper
//
//  Created by Alfred Jobs on 2025/5/20.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 延迟3秒后启动主应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.launchMainApp()
        }
    }
    
    private func launchMainApp() {
        // 使用bundleId启动主应用
        let bundleID = "club.lemos.Screen-OCR"
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.addsToRecentItems = false
            config.promptsUserIfNeeded = true
            
            NSWorkspace.shared.openApplication(at: appURL,
                                               configuration: config,
                                               completionHandler: { app, error in
                if let error = error {
                    print("启动Screen OCR失败: \(error.localizedDescription)")
                } else {
                    print("Screen OCR已成功启动")
                }
                
                // 完成后退出Helper
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    NSApp.terminate(nil)
                }
            })
        } else {
            print("找不到Screen OCR应用，Bundle ID: \(bundleID)")
            // 找不到应用时也需要退出Helper
            NSApp.terminate(nil)
        }
    }
}
