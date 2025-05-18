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
            UserDefaults.standard.set(newValue, forKey: startAtLoginKey)
            updateLoginItemStatus()
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
    
    // 私有初始化方法
    private init() {
        // 设置默认值
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
    
    // MARK: - 登录启动项相关
    
    /// 更新登录项状态
    private func updateLoginItemStatus() {
        if #available(macOS 13.0, *) {
            do {
                if startAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("无法设置登录项: \(error)")
            }
        } else {
            // 旧版macOS使用传统方法
            if let bundleURL = Bundle.main.bundleURL.absoluteURL as CFURL? {
                let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue()
                
                if startAtLogin {
                    // 添加登录项
                    LSSharedFileListInsertItemURL(loginItemsRef!, kLSSharedFileListItemLast.takeRetainedValue(), nil, nil, bundleURL, nil, nil)
                } else {
                    // 移除登录项
                    if let loginItems = LSSharedFileListCopySnapshot(loginItemsRef!, nil)?.takeRetainedValue() as? [LSSharedFileListItem] {
                        let bundleID = Bundle.main.bundleIdentifier!
                        for loginItem in loginItems {
                            if let itemURL = LSSharedFileListItemCopyResolvedURL(loginItem, 0, nil)?.takeRetainedValue() as URL?,
                               let itemBundleID = Bundle(url: itemURL)?.bundleIdentifier,
                               itemBundleID == bundleID {
                                LSSharedFileListItemRemove(loginItemsRef!, loginItem)
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// 检查登录项是否启用
    func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            let bundleID = Bundle.main.bundleIdentifier!
            return (LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL])?.isEmpty == false
        }
    }
} 
