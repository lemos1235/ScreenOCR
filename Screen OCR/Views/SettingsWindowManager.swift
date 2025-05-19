import Cocoa
import SwiftUI

/**
 负责管理设置窗口
 */
class SettingsWindowManager: NSObject {
    private var settingsWindow: NSWindow?
    private var hotkeyManager: HotkeyManager?
    
    init(hotkeyManager: HotkeyManager? = nil) {
        self.hotkeyManager = hotkeyManager
        super.init()
    }
    
    /**
     显示设置窗口
     */
    func showSettingsWindow() {
        // 如果窗口已经存在，则显示并聚焦
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 创建窗口内容视图
        let contentView = SettingsView()
            .environmentObject(SettingsViewModel(hotkeyManager: hotkeyManager))
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口属性
        window.center()
        window.title = "Preferences"
        window.contentView = NSHostingView(rootView: contentView)
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        
        // 设置窗口代理，处理关闭事件
        window.delegate = self
        
        // 保存并显示窗口
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /**
     隐藏设置窗口，用于在应用会话期间临时隐藏
     */
    func hideSettingsWindow() {
        settingsWindow?.orderOut(nil)
    }
    
    /**
     检查设置窗口是否可见
     */
    var isSettingsWindowVisible: Bool {
        return settingsWindow?.isVisible ?? false
    }
    
    /**
     在使用全局快捷键前临时隐藏设置窗口，之后可以恢复
     */
    func prepareForGlobalHotkey() {
        // 如果设置窗口可见，暂时隐藏它
        if let window = settingsWindow, window.isVisible {
            window.orderOut(nil)
        }
    }
    
    /**
     在应用需要显示自己的窗口时使用，例如通过点击菜单栏图标
     */
    func restoreWindowsForAppActivation() {
        // 如果设置窗口存在且之前是可见的，现在重新显示它
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - NSWindowDelegate
extension SettingsWindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindow {
            settingsWindow = nil
        }
    }
}

// MARK: - SettingsViewModel
class SettingsViewModel: ObservableObject {
    @Published var startAtLogin: Bool {
        didSet {
            AppSettings.shared.startAtLogin = startAtLogin
        }
    }
    
    @Published var clickToScreenshot: Bool {
        didSet {
            AppSettings.shared.clickToScreenshot = clickToScreenshot
        }
    }
    
    @Published var clipboardMode: Bool {
        didSet {
            if oldValue != clipboardMode {
                AppSettings.shared.clipboardMode = clipboardMode
                // 发送剪贴板模式变更通知
                NotificationCenter.default.post(name: Notification.Name("ClipboardModeChanged"), object: nil)
            }
        }
    }
    
    @Published var playSoundOnCopy: Bool {
        didSet {
            AppSettings.shared.playSoundOnCopy = playSoundOnCopy
        }
    }
    
    @Published var selectedLanguage: String {
        didSet {
            AppSettings.shared.selectedLanguage = selectedLanguage
        }
    }
    
    @Published var selectedKeyCode: KeyCode {
        didSet {
            AppSettings.shared.captureHotkeyKeyCode = selectedKeyCode
            updateHotkey()
        }
    }
    
    @Published var selectedModifiers: [ModifierKey] {
        didSet {
            AppSettings.shared.captureHotkeyModifiers = selectedModifiers
            updateHotkey()
        }
    }
    
    var modifierOptions: [ModifierKey] = ModifierKey.allCases
    var keyOptions: [KeyCode] = KeyCode.allCases
    
    var languageOptions: [(title: String, code: String)] = [
        ("Automatic", "auto"),
        ("English", "en-US"),
        ("French", "fr-FR"),
        ("Italian", "it-IT"),
        ("German", "de-DE"),
        ("Spanish", "es-ES"),
        ("Portuguese", "pt-BR"),
        ("Chinese (Simplified)", "zh-Hans"),
        ("Chinese (Traditional)", "zh-Hant"),
        ("Korean", "ko-KR"),
        ("Japanese", "ja-JP"),
        ("Ukrainian", "uk-UA"),
        ("Russian", "ru-RU")
    ]
    
    var appVersion: String {
        guard let infoDictionary = Bundle.main.infoDictionary,
              let version = infoDictionary["CFBundleShortVersionString"] as? String,
              let build = infoDictionary["CFBundleVersion"] as? String else {
            return "Version Unknown"
        }
        return "Version \(version) (Build \(build))"
    }
    
    private var hotkeyManager: HotkeyManager?
    private var clipboardModeObserver: NSObjectProtocol?
    private var isUpdatingFromNotification = false
    
    init(hotkeyManager: HotkeyManager? = nil) {
        self.hotkeyManager = hotkeyManager
        self.startAtLogin = AppSettings.shared.startAtLogin
        self.clickToScreenshot = AppSettings.shared.clickToScreenshot
        self.clipboardMode = AppSettings.shared.clipboardMode
        self.playSoundOnCopy = AppSettings.shared.playSoundOnCopy
        self.selectedLanguage = AppSettings.shared.selectedLanguage
        self.selectedKeyCode = AppSettings.shared.captureHotkeyKeyCode
        self.selectedModifiers = AppSettings.shared.captureHotkeyModifiers
        
        // 监听剪贴板模式变更通知
        clipboardModeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("ClipboardModeChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.isUpdatingFromNotification else { return }
            self.isUpdatingFromNotification = true
            self.clipboardMode = AppSettings.shared.clipboardMode
            self.isUpdatingFromNotification = false
        }
    }
    
    deinit {
        if let observer = clipboardModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func updateHotkey() {
        // 无论是否有hotkeyManager，都发送通知让外部更新快捷键
        NotificationCenter.default.post(name: Notification.Name("HotkeySettingsChanged"), object: nil)
    }
} 
