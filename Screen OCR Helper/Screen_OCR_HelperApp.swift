//
//  Screen_OCR_HelperApp.swift
//  Screen OCR Helper
//
//  Created by Alfred Jobs on 2025/5/20.
//

import SwiftUI

@main
struct Screen_OCR_HelperApp: App {
    // 使用 AppDelegate 处理启动逻辑
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            // 空视图，因为这是一个纯后台应用
            EmptyView()
        }
    }
}
