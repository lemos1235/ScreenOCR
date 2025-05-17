import Cocoa
import SwiftUI
import Combine
import Vision
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var captureService: ScreenCaptureService!
    private var hotkeyManager: HotkeyManager!
    private var floatingWindowManager: FloatingWindowManager!
    
    // 当前选择的OCR语言
    private var selectedLanguages: [String] = []
    
    // 语言菜单项
    private var languageMenuItem: NSMenuItem!
    
    // 登录启动菜单项
    private var startAtLoginMenuItem: NSMenuItem!
    
    // UserDefaults键
    private let selectedLanguageKey = "selectedLanguage"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化截图服务
        captureService = ScreenCaptureService()
        
        // 初始化浮动窗口管理器
        floatingWindowManager = FloatingWindowManager()
        
        // 初始化快捷键管理器
        hotkeyManager = HotkeyManager()
        hotkeyManager.registerHotkey(key: .o, modifiers: [.option]) { [weak self] in
            guard let self = self else { return }
            self.startScreenCapture()
        }
        
        // 设置菜单栏图标
        setupStatusBarItem()
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarIcon")
            button.image?.size = NSSize(width: 18, height: 18)
            
            // 设置按钮行为
            button.target = self
            button.action = #selector(statusBarButtonClicked)
            
            // 同时监听左键和右键事件
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        setupStatusBarMenu()
    }
    
    private func setupStatusBarMenu() {
        statusMenu = NSMenu()
        
        // 确保菜单使用系统主题样式
        statusMenu.autoenablesItems = true
        
        // 添加截图子菜单
        let captureMenuItem = NSMenuItem(
            title: "Capture",
            action: #selector(startScreenCapture),
            keyEquivalent: "o"
        )
        captureMenuItem.keyEquivalentModifierMask = [.option]
        statusMenu.addItem(captureMenuItem)

        // 添加语言选择子菜单
        languageMenuItem = NSMenuItem(title: "OCR Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        
        // 添加自动检测选项
        let autoItem = NSMenuItem(title: "Automatic", action: #selector(selectLanguage(_:)), keyEquivalent: "")
        autoItem.representedObject = "auto"
        
        // 添加自动检测的图标
        autoItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Automatic")
        
        languageMenu.addItem(autoItem)
        
        // 添加常用语言
        // 添加语言菜单项（按照截图中显示的顺序排列）
        addLanguageMenuItem(to: languageMenu, title: "English", code: "en-US")
        addLanguageMenuItem(to: languageMenu, title: "French", code: "fr-FR")
        addLanguageMenuItem(to: languageMenu, title: "Italian", code: "it-IT")
        addLanguageMenuItem(to: languageMenu, title: "German", code: "de-DE")
        addLanguageMenuItem(to: languageMenu, title: "Spanish", code: "es-ES")
        addLanguageMenuItem(to: languageMenu, title: "Portuguese", code: "pt-BR")
        addLanguageMenuItem(to: languageMenu, title: "Chinese (Simplified)", code: "zh-Hans")
        addLanguageMenuItem(to: languageMenu, title: "Chinese (Traditional)", code: "zh-Hant")
        addLanguageMenuItem(to: languageMenu, title: "Korean", code: "ko-KR")
        addLanguageMenuItem(to: languageMenu, title: "Japanese", code: "ja-JP")
        addLanguageMenuItem(to: languageMenu, title: "Ukrainian", code: "uk-UA")
        addLanguageMenuItem(to: languageMenu, title: "Russian", code: "ru-RU")
        
        languageMenuItem.submenu = languageMenu
        statusMenu.addItem(languageMenuItem)
        
        // 从UserDefaults加载上次选择的语言
        loadSavedLanguage(languageMenu)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // 添加启动登录菜单项
        startAtLoginMenuItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        startAtLoginMenuItem.state = isLoginItemEnabled() ? .on : .off
        statusMenu.addItem(startAtLoginMenuItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    // 从UserDefaults加载上次选择的语言
    private func loadSavedLanguage(_ languageMenu: NSMenu) {
        let savedLanguage = UserDefaults.standard.string(forKey: selectedLanguageKey) ?? "auto"
        
        // 设置当前选中的语言
        for item in languageMenu.items {
            if let itemCode = item.representedObject as? String, itemCode == savedLanguage {
                item.state = .on
                
                // 更新selectedLanguages数组
                if savedLanguage == "auto" {
                    selectedLanguages = []
                } else {
                    selectedLanguages = [savedLanguage]
                }
                break
            } else {
                item.state = .off
            }
        }
        
        // 如果没有找到匹配项，默认选择"auto"
        if selectedLanguages.isEmpty && savedLanguage != "auto" {
            if let autoItem = languageMenu.items.first(where: { ($0.representedObject as? String) == "auto" }) {
                autoItem.state = .on
            }
        }
    }
    
    // 添加语言菜单项
    private func addLanguageMenuItem(to menu: NSMenu, title: String, code: String) {
        let item = NSMenuItem(title: title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
        item.representedObject = code
        
        // 添加国旗图标
        let flagImage = getFlagImage(for: code)
        if let flagImage = flagImage {
            item.image = flagImage
        }
        
        menu.addItem(item)
    }
    
    // 获取国旗图片
    private func getFlagImage(for languageCode: String) -> NSImage? {
        // 提取国家/地区代码
        var countryCode = ""
        if languageCode.contains("-") {
            countryCode = String(languageCode.split(separator: "-")[1]).uppercased()
        }
        
        // 特殊处理中文简体和繁体
        if languageCode == "zh-Hans" || languageCode == "zh-Hant"  {
            countryCode = "CN" // 中国
        } else if languageCode == "auto" {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Automatic")
        }
        
        // 创建国旗emoji字符
        let base: UInt32 = 127397 // Unicode码点基数，用于转换ASCII字母为区域指示符
        var emoji = ""
        
        for scalar in countryCode.unicodeScalars {
            emoji.append(String(UnicodeScalar(base + scalar.value)!))
        }
        
        // 创建NSImage
        let fontSize: CGFloat = 16.0
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize)
        ]
        
        let imageSize = NSSize(width: fontSize + 4, height: fontSize)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        emoji.draw(at: NSPoint(x: 0, y: 0), withAttributes: attrs)
        image.unlockFocus()
        
        return image
    }
    
    // 选择OCR语言
    @objc private func selectLanguage(_ sender: NSMenuItem) {
        // 重置所有菜单项状态
        if let languageMenu = languageMenuItem.submenu {
            for item in languageMenu.items {
                item.state = .off
            }
        }
        
        // 设置选中状态
        sender.state = .on
        
        // 获取语言代码
        if let languageCode = sender.representedObject as? String {
            if languageCode == "auto" {
                // 自动检测
                selectedLanguages = []
            } else {
                // 特定语言
                selectedLanguages = [languageCode]
            }
            
            // 保存选择到UserDefaults
            UserDefaults.standard.set(languageCode, forKey: selectedLanguageKey)
        }
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            // 右键点击时显示菜单，正确定位在状态栏下方
            if let button = statusItem.button {
                let statusItemFrame = button.window?.frame ?? NSRect.zero
                statusMenu.popUp(positioning: statusMenu.item(at: 0),
                                 at: NSPoint(x: statusItemFrame.origin.x,
                                             y: statusItemFrame.origin.y - 5),
                                 in: nil)
            }
        } else {
            // 左键点击直接截图
            startScreenCapture()
        }
    }
    
    @objc private func startScreenCapture() {
        // 启动截图选区模式
        captureService.startCapture { [weak self] image in
            guard let self = self, let capturedImage = image else { return }
            // 创建新的浮动窗口显示截图并执行OCR识别
            let nsimage = NSImage(cgImage: capturedImage, size: NSSize(width: capturedImage.width, height: capturedImage.height))
            self.floatingWindowManager.createFloatingWindow(with: nsimage, languages: self.selectedLanguages)
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - 登录启动相关方法
    
    // 检查是否设置为登录启动
    private func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            // macOS 13及以上使用新API
            return SMAppService.mainApp.status == .enabled
        } else {
            // 旧版macOS使用传统方法检查登录项
            let bundleID = Bundle.main.bundleIdentifier!
            return (LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL])?.isEmpty == false
        }
    }
    
    // 切换登录启动状态
    @objc private func toggleStartAtLogin() {
        let isEnabled = isLoginItemEnabled()
        
        if #available(macOS 13.0, *) {
            // macOS 13及以上使用新API
            do {
                if isEnabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
                // 更新菜单项状态
                startAtLoginMenuItem.state = isLoginItemEnabled() ? .on : .off
            } catch {
                print("无法切换登录项状态: \(error)")
            }
        } else {
            // 旧版macOS使用传统方法
            if let bundleURL = Bundle.main.bundleURL.absoluteURL as CFURL? {
                let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue()
                
                if isEnabled {
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
                } else {
                    // 添加登录项
                    LSSharedFileListInsertItemURL(loginItemsRef!, kLSSharedFileListItemLast.takeRetainedValue(), nil, nil, bundleURL, nil, nil)
                }
                
                // 更新菜单项状态
                startAtLoginMenuItem.state = isLoginItemEnabled() ? .on : .off
            }
        }
    }
}
