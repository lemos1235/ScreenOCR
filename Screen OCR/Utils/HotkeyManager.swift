import Cocoa
import Carbon

/**
 负责注册和管理全局快捷键
 */
class HotkeyManager {
    // 定义管理的热键ID
    private(set) var hotKeyID = 0
    private var hotKeyRefs: [Int: EventHotKeyRef] = [:]
    private var hotKeyHandlers: [Int: () -> Void] = [:]
    
    init() {
        // 注册热键事件处理器
        installEventHandler()
    }
    
    deinit {
        // 清理已注册的所有热键
        unregisterAllHotkeys()
    }
    
    /**
     注册全局热键
     - Parameters:
        - key: 键盘按键
        - modifiers: 修饰键（如Command、Option等）
        - handler: 热键触发时执行的闭包
     - Returns: 是否成功注册
     */
    func registerHotkey(key: KeyCode, modifiers: [ModifierKey], handler: @escaping () -> Void) -> Bool {
        // 生成唯一ID
        let id = generateHotkeyID()
        
        // 转换修饰键为Carbon API格式
        var carbonModifiers: UInt32 = 0
        for modifier in modifiers {
            carbonModifiers |= modifier.carbonFlag
        }
        
        // 创建热键引用
        var hotKeyRef: EventHotKeyRef?
        let keyCode = key.carbonKeyCode
        
        // 热键ID结构
        var hotKeyID = EventHotKeyID(signature: OSType(fourCharCode("SCRN")), id: UInt32(id))
        
        // 注册热键
        let status = RegisterEventHotKey(UInt32(keyCode),
                                        carbonModifiers,
                                        hotKeyID,
                                        GetApplicationEventTarget(),
                                        0,
                                        &hotKeyRef)
        
        // 检查注册是否成功
        guard status == noErr, let hotKeyRef = hotKeyRef else {
            NSLog("Failed to register hotkey with keycode \(keyCode) and modifiers \(modifiers)")
            return false
        }
        
        // 存储热键引用和处理器
        hotKeyRefs[id] = hotKeyRef
        hotKeyHandlers[id] = handler
        
        return true
    }
    
    /**
     注销指定ID的热键
     */
    func unregisterHotkey(id: Int) {
        guard let hotKeyRef = hotKeyRefs[id] else { return }
        
        let status = UnregisterEventHotKey(hotKeyRef)
        if status != noErr {
            NSLog("Failed to unregister hotkey with id \(id)")
            return
        }
        
        hotKeyRefs.removeValue(forKey: id)
        hotKeyHandlers.removeValue(forKey: id)
    }
    
    /**
     注销所有已注册的热键
     */
    func unregisterAllHotkeys() {
        for id in hotKeyRefs.keys {
            unregisterHotkey(id: id)
        }
    }
    
    // MARK: - Private Methods
    
    /**
     生成唯一热键ID
     */
    private func generateHotkeyID() -> Int {
        hotKeyID += 1
        return hotKeyID
    }
    
    /**
     安装事件处理器
     */
    private func installEventHandler() {
        // 创建事件处理器
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // 安装事件处理器
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                // 转换userData为HotkeyManager实例
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                // 获取热键ID
                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                
                if status == noErr {
                    // 查找并执行对应的处理器
                    let id = Int(hotkeyID.id)
                    if let handler = manager.hotKeyHandlers[id] {
                        handler()
                    }
                }
                
                return OSStatus(noErr)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
    }
}

// MARK: - 键盘按键和修饰键枚举

/**
 常用键盘按键映射
 */
enum KeyCode: Int, CaseIterable, Codable {
    case a = 0, b = 11, c = 8, d = 2, e = 14, f = 3, g = 5, h = 4, i = 34, j = 38
    case k = 40, l = 37, m = 46, n = 45, o = 31, p = 35, q = 12, r = 15, s = 1
    case t = 17, u = 32, v = 9, w = 13, x = 7, y = 16, z = 6
    
    var carbonKeyCode: Int {
        return self.rawValue
    }
    
    var displayName: String {
        return self.description.uppercased()
    }
    
    var keyEquivalent: String {
        return self.description
    }
    
    var description: String {
        switch self {
        case .a: return "a"
        case .b: return "b"
        case .c: return "c"
        case .d: return "d"
        case .e: return "e"
        case .f: return "f"
        case .g: return "g"
        case .h: return "h"
        case .i: return "i"
        case .j: return "j"
        case .k: return "k"
        case .l: return "l"
        case .m: return "m"
        case .n: return "n"
        case .o: return "o"
        case .p: return "p"
        case .q: return "q"
        case .r: return "r"
        case .s: return "s"
        case .t: return "t"
        case .u: return "u"
        case .v: return "v"
        case .w: return "w"
        case .x: return "x"
        case .y: return "y"
        case .z: return "z"
        }
    }
}

/**
 修饰键映射
 */
enum ModifierKey: Int, CaseIterable, Codable {
    case command = 0
    case shift = 1
    case option = 2
    case control = 3
    
    var carbonFlag: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .shift: return UInt32(shiftKey)
        case .option: return UInt32(optionKey)
        case .control: return UInt32(controlKey)
        }
    }
    
    var displayName: String {
        switch self {
        case .command: return "⌘"
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }
}

// 辅助函数：将四个字符转换为OSType
private func fourCharCode(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for char in string.utf16 {
        result = (result << 8) + UInt32(char)
    }
    return result
} 
