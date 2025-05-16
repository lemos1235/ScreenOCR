import Cocoa
import Carbon

/**
 负责注册和管理全局快捷键
 */
class HotkeyManager {
    // 定义管理的热键ID
    private var hotKeyID = 0
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
enum KeyCode {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case escape
    
    var carbonKeyCode: Int {
        switch self {
        case .a: return 0
        case .b: return 11
        case .c: return 8
        case .d: return 2
        case .e: return 14
        case .f: return 3
        case .g: return 5
        case .h: return 4
        case .i: return 34
        case .j: return 38
        case .k: return 40
        case .l: return 37
        case .m: return 46
        case .n: return 45
        case .o: return 31
        case .p: return 35
        case .q: return 12
        case .r: return 15
        case .s: return 1
        case .t: return 17
        case .u: return 32
        case .v: return 9
        case .w: return 13
        case .x: return 7
        case .y: return 16
        case .z: return 6
        case .escape: return 53
        }
    }
}

/**
 修饰键映射
 */
enum ModifierKey {
    case command
    case shift
    case option
    case control
    
    var carbonFlag: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .shift: return UInt32(shiftKey)
        case .option: return UInt32(optionKey)
        case .control: return UInt32(controlKey)
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