import Foundation
import Cocoa
import ServiceManagement

/// 应用设置模型，用于管理和持久化用户设置
class AppSettings {
    // 单例实例
    static let shared = AppSettings()
    
    // UserDefaults键
    private let startAtLoginKey = "startAtLogin"
    private let clickToScreenshotKey = "clickToScreenshot"
    private let captureHotkeyModifiersKey = "captureHotkeyModifiers"
    private let captureHotkeyKeyCodeKey = "captureHotkeyKeyCode"
    private let clipboardModeKey = "clipboardMode"
    private let playSoundOnCopyKey = "playSoundOnCopy"
    private let selectedLanguageKey = "selectedLanguage"
    
    // 登录时启动
    var startAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: startAtLoginKey) }
        set {
            // Helper 应用的 Bundle ID
            let helperBundleID = "club.lemos.Screen-OCR-Helper"

            UserDefaults.standard.set(newValue, forKey: startAtLoginKey)
            if #available(macOS 13.0, *) {
                do {
                    if startAtLogin {
                        try SMAppService.loginItem(identifier: helperBundleID).register()
                    } else {
                        try SMAppService.loginItem(identifier: helperBundleID).unregister()
                    }
                } catch {
                    print("无法设置登录项: \(error)")
                }
            } else {
                let result = SMLoginItemSetEnabled(helperBundleID as CFString, startAtLogin)
                if !result {
                    print("使用 SMLoginItemSetEnabled 设置登录项失败")
                }
            }
        }
    }
    
    // 左键点击菜单栏图标时直接触发截图
    var clickToScreenshot: Bool {
        get { UserDefaults.standard.bool(forKey: clickToScreenshotKey) }
        set { UserDefaults.standard.set(newValue, forKey: clickToScreenshotKey) }
    }
    
    // 截图快捷键修饰键
    var captureHotkeyModifiers: [ModifierKey] {
        get {
            if let modifiersData = UserDefaults.standard.data(forKey: captureHotkeyModifiersKey),
               let modifiers = try? JSONDecoder().decode([Int].self, from: modifiersData) {
                return modifiers.compactMap { ModifierKey(rawValue: $0) }
            }
            return [.option] // 默认为Option键
        }
        set {
            let modifierRawValues = newValue.map { $0.rawValue }
            if let data = try? JSONEncoder().encode(modifierRawValues) {
                UserDefaults.standard.set(data, forKey: captureHotkeyModifiersKey)
            }
        }
    }
    
    // 截图快捷键键码
    var captureHotkeyKeyCode: KeyCode {
        get {
            let rawValue = UserDefaults.standard.integer(forKey: captureHotkeyKeyCodeKey)
            return KeyCode(rawValue: rawValue) ?? .o // 默认为O键
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: captureHotkeyKeyCodeKey)
        }
    }
    
    // 剪贴板模式（截图后直接复制到剪贴板）
    var clipboardMode: Bool {
        get { UserDefaults.standard.bool(forKey: clipboardModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: clipboardModeKey) }
    }
    
    // 复制时播放声音
    var playSoundOnCopy: Bool {
        get { UserDefaults.standard.bool(forKey: playSoundOnCopyKey) }
        set { UserDefaults.standard.set(newValue, forKey: playSoundOnCopyKey) }
    }
    
    // 选择的OCR语言
    var selectedLanguage: String {
        get { UserDefaults.standard.string(forKey: selectedLanguageKey) ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: selectedLanguageKey) }
    }
    
    // 初始化，设置默认值
    private init() {
        if UserDefaults.standard.object(forKey: clickToScreenshotKey) == nil {
            UserDefaults.standard.set(true, forKey: clickToScreenshotKey)
        }
        
        if UserDefaults.standard.object(forKey: clipboardModeKey) == nil {
            UserDefaults.standard.set(false, forKey: clipboardModeKey)
        }
        
        if UserDefaults.standard.object(forKey: playSoundOnCopyKey) == nil {
            UserDefaults.standard.set(true, forKey: playSoundOnCopyKey)
        }
        
        if UserDefaults.standard.object(forKey: captureHotkeyKeyCodeKey) == nil {
            UserDefaults.standard.set(KeyCode.o.rawValue, forKey: captureHotkeyKeyCodeKey)
        }
        
        if UserDefaults.standard.data(forKey: captureHotkeyModifiersKey) == nil {
            let defaultModifiers = [ModifierKey.option.rawValue]
            if let data = try? JSONEncoder().encode(defaultModifiers) {
                UserDefaults.standard.set(data, forKey: captureHotkeyModifiersKey)
            }
        }
    }
}
