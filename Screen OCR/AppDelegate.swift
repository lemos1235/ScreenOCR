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
    private var settingsWindowManager: SettingsWindowManager!
    
    // 当前选择的OCR语言
    private var selectedLanguages: [String] = []
    
    // 保存快捷键的注册ID，以便在更新时可以注销
    private var captureHotkeyID: Int?
    
    // UserDefaults观察者
    private var settingsObserver: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化截图服务
        captureService = ScreenCaptureService()
        
        // 初始化浮动窗口管理器
        floatingWindowManager = FloatingWindowManager()
        
        // 初始化快捷键管理器
        hotkeyManager = HotkeyManager()
        
        // 初始化设置窗口管理器
        settingsWindowManager = SettingsWindowManager(hotkeyManager: hotkeyManager)
        
        // 注册截图快捷键
        registerCaptureHotkey()
        
        // 从AppSettings加载OCR语言
        updateSelectedLanguages()
        
        // 监听快捷键设置变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: Notification.Name("HotkeySettingsChanged"),
            object: nil
        )
        
        // 监听剪贴板模式变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipboardModeChanged),
            name: Notification.Name("ClipboardModeChanged"),
            object: nil
        )
        
        // 设置菜单栏图标
        setupStatusBarItem()
    }
    
    // 注册截图快捷键
    private func registerCaptureHotkey() {
        // 先注销已有快捷键
        if let hotkeyID = captureHotkeyID {
            hotkeyManager.unregisterHotkey(id: hotkeyID)
            captureHotkeyID = nil
        }
        
        // 从设置获取快捷键
        let keyCode = AppSettings.shared.captureHotkeyKeyCode
        let modifiers = AppSettings.shared.captureHotkeyModifiers
        
        // 注册新快捷键
        let success = hotkeyManager.registerHotkey(key: keyCode, modifiers: modifiers) { [weak self] in
            guard let self = self else { return }
            self.startScreenCapture()
        }
        
        if success {
            // 保存ID以便后续注销
            captureHotkeyID = hotkeyManager.hotKeyID
        }
    }
    
    // 监听快捷键设置变更
    @objc private func hotkeySettingsChanged() {
        // 重新注册全局快捷键
        registerCaptureHotkey()
        // 更新菜单栏中的快捷键提示文本
        updateCaptureMenuItemShortcut()
    }
    
    // 更新菜单项的快捷键显示
    private func updateCaptureMenuItemShortcut() {
        if let captureMenuItem = statusMenu.items.first {
            // 获取当前设置的快捷键
            let keyCode = AppSettings.shared.captureHotkeyKeyCode
            // 设置快捷键文本
            captureMenuItem.keyEquivalent = keyCode.keyEquivalent
            
            // 设置修饰键
            let modifiers = AppSettings.shared.captureHotkeyModifiers
            var modifierMask: NSEvent.ModifierFlags = []
            
            for modifier in modifiers {
                switch modifier {
                case .command:
                    modifierMask.insert(.command)
                case .option:
                    modifierMask.insert(.option)
                case .control:
                    modifierMask.insert(.control)
                case .shift:
                    modifierMask.insert(.shift)
                }
            }
            
            captureMenuItem.keyEquivalentModifierMask = modifierMask
        }
    }
    
    // 更新选中的语言
    private func updateSelectedLanguages() {
        let languageCode = AppSettings.shared.selectedLanguage
        if languageCode == "auto" {
            selectedLanguages = []
        } else {
            selectedLanguages = [languageCode]
        }
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
        
        // 添加截图菜单项
        let captureMenuItem = NSMenuItem(
            title: "Capture",
            action: #selector(startScreenCapture),
            keyEquivalent: ""
        )
        statusMenu.addItem(captureMenuItem)
        
        // 更新快捷键显示
        updateCaptureMenuItemShortcut()
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // 添加剪贴板模式菜单项
        let clipboardModeItem = NSMenuItem(
            title: "Clipboard Mode",
            action: #selector(toggleClipboardMode),
            keyEquivalent: ""
        )
        clipboardModeItem.state = AppSettings.shared.clipboardMode ? .on : .off
        statusMenu.addItem(clipboardModeItem)
        
        // 添加偏好设置菜单项
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.keyEquivalentModifierMask = [.command]
        statusMenu.addItem(preferencesItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
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
            // 左键点击根据设置决定是否直接截图
            if AppSettings.shared.clickToScreenshot {
                startScreenCapture()
            } else {
                // 不直接截图时，也显示菜单
                if let button = statusItem.button {
                    let statusItemFrame = button.window?.frame ?? NSRect.zero
                    statusMenu.popUp(positioning: statusMenu.item(at: 0),
                                     at: NSPoint(x: statusItemFrame.origin.x,
                                                 y: statusItemFrame.origin.y - 5),
                                     in: nil)
                }
            }
        }
    }
    
    @objc private func startScreenCapture() {
        // 暂时隐藏设置窗口（如果可见），避免全局快捷键触发时激活它
        settingsWindowManager.prepareForGlobalHotkey()
        
        // 启动截图选区模式
        captureService.startCapture { [weak self] image in
            guard let self = self, let capturedImage = image else {
                return
            }
            
            // 更新语言设置
            self.updateSelectedLanguages()
            
            // 获取当前的剪贴板模式设置
            let isClipboardMode = AppSettings.shared.clipboardMode
            
            if isClipboardMode {
                // 剪贴板模式：直接进行OCR并复制到剪贴板
                let nsimage = NSImage(cgImage: capturedImage, size: NSSize(width: capturedImage.width, height: capturedImage.height))
                let ocrService = OCRService()
                ocrService.performOCR(on: nsimage, languages: self.selectedLanguages) { results in
                    // 提取文本
                    let recognizedText = results.map { $0.text }.joined(separator: "\n")
                    
                    // 复制到剪贴板
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(recognizedText, forType: .string)
                    
                    // 播放声音（如果启用）
                    if AppSettings.shared.playSoundOnCopy {
                        if let sound = NSSound(named: NSSound.Name("Frog")) {
                            sound.play()
                        }
                    }
                }
            } else {
                // 普通模式：创建浮动窗口
                let nsimage = NSImage(cgImage: capturedImage, size: NSSize(width: capturedImage.width, height: capturedImage.height))
                self.floatingWindowManager.createFloatingWindow(with: nsimage, languages: self.selectedLanguages)
            }
        }
    }
    
    @objc private func openPreferences() {
        // 从菜单手动打开设置时，可以激活应用窗口
        settingsWindowManager.restoreWindowsForAppActivation()
        settingsWindowManager.showSettingsWindow()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    // 切换剪贴板模式
    @objc private func toggleClipboardMode() {
        // 切换剪贴板模式设置
        AppSettings.shared.clipboardMode = !AppSettings.shared.clipboardMode
        
        // 发送剪贴板模式变更通知
        NotificationCenter.default.post(name: Notification.Name("ClipboardModeChanged"), object: nil)
        
        // 更新菜单项选中状态
        if let clipboardModeItem = statusMenu.items.first(where: { $0.action == #selector(toggleClipboardMode) }) {
            clipboardModeItem.state = AppSettings.shared.clipboardMode ? .on : .off
        }
    }
    
    // 监听剪贴板模式变更
    @objc private func clipboardModeChanged() {
        // 更新菜单项选中状态
        if let clipboardModeItem = statusMenu.items.first(where: { $0.action == #selector(toggleClipboardMode) }) {
            clipboardModeItem.state = AppSettings.shared.clipboardMode ? .on : .off
        }
    }
}
