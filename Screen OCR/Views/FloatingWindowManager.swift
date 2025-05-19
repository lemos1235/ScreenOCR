import Cocoa
import SwiftUI

/**
 负责管理截图显示的浮动窗口
 */
class FloatingWindowManager: NSObject {
    // 窗口最小尺寸
    private let minWindowWidth: CGFloat = 420
    private let minWindowHeight: CGFloat = 110
    private let ambiguousTitleBarHeight: CGFloat = 28.0
    
    // 存储活跃的浮动窗口（现在只保留一个）
    private var floatingWindow: NSWindow?
    
    // 窗口可见性状态
    private var isWindowVisible = true
    
    /**
     创建一个新的浮动窗口显示截图
     - Parameter image: 要显示的截图
     - Parameter languages: 要识别的语言，默认自动检测
     */
    func createFloatingWindow(with image: NSImage, languages: [String] = []) {
        // 关闭已有窗口
        closeAllWindows()
        
        // 计算窗口大小和位置
        let windowSize = calculateOptimalWindowSize(for: image)
        let windowPosition = calculateWindowPosition(size: windowSize)
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(origin: windowPosition, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口属性
        window.level = .floating  // 浮动在普通窗口之上
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.windowBackgroundColor
        
        // 设置窗口的最小尺寸约束
        window.minSize = NSSize(width: minWindowWidth, height: minWindowHeight + ambiguousTitleBarHeight)
        
        // 设置窗口代理以处理关闭事件
        let windowController = FloatingWindowController(window: window)
        windowController.onWindowClose = { [weak self] _ in
            self?.floatingWindow = nil
        }
        
        // 创建OCR图像视图
        let contentView = OCRContentView(frame: NSRect(origin: .zero, size: windowSize),
                                         image: image, locales: languages)
        
        // 设置内容视图
        window.contentView = contentView
        
        // 保存并显示窗口
        self.floatingWindow = window
        window.makeKeyAndOrderFront(nil)
        
        // 确保应用处于活跃状态
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /**
     切换浮动窗口的可见性
     */
    func toggleVisibility() {
        isWindowVisible.toggle()
        
        if let window = floatingWindow {
            if isWindowVisible {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderOut(nil)
            }
        }
    }
    
    /**
     关闭所有浮动窗口
     */
    func closeAllWindows() {
        floatingWindow?.close()
        floatingWindow = nil
    }
    
    // MARK: - Private Methods
    
    /**
     计算显示图像的最佳窗口大小
     */
    private func calculateOptimalWindowSize(for image: NSImage) -> NSSize {
        let screenSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let maxWidth = screenSize.width * 0.8
        let maxHeight = screenSize.height * 0.6
        
        let imageSize = image.size
        
        
        
        // 如果图像足够小，直接使用图像大小，但要确保不低于最小尺寸
        if imageSize.width <= maxWidth && imageSize.height <= maxHeight {
            return NSSize(
                width: max(imageSize.width, minWindowWidth),
                height: max(imageSize.height, minWindowHeight) + ambiguousTitleBarHeight
            )
        }
        
        // 否则，保持宽高比例进行缩放，并确保不低于最小尺寸
        let widthRatio = maxWidth / imageSize.width
        let heightRatio = maxHeight / imageSize.height
        let ratio = min(widthRatio, heightRatio)
        
        return NSSize(
            width: max(imageSize.width * ratio, minWindowWidth),
            height: max(imageSize.height * ratio, minWindowHeight) + ambiguousTitleBarHeight
        )
    }
    
    /**
     计算窗口位置（居中）
     */
    private func calculateWindowPosition(size: NSSize) -> NSPoint {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return NSPoint(x: 100, y: 100)
        }
        
        return NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2
        )
    }
}

/**
 用于监听窗口关闭事件的窗口控制器
 */
class FloatingWindowController: NSWindowController, NSWindowDelegate {
    var onWindowClose: ((NSWindow) -> Void)?
    
    override init(window: NSWindow?) {
        super.init(window: window)
        window?.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            onWindowClose?(window)
        }
    }
}
