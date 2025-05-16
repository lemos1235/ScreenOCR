import Cocoa
import SwiftUI
import Combine
import CoreMedia
import CoreImage
import os.log
import Foundation

/**
 负责处理屏幕截图相关的功能
 */
class ScreenCaptureService: NSObject {
    // 截图结果回调
    typealias CaptureCompletion = (CGImage?) -> Void
    
    // 当前的截图完成回调
    private var currentCompletion: CaptureCompletion?
    
    // 截图窗口
    private var overlayWindow: NSWindow?
    private var selectionView: SelectionOverlayView?
    
    // 用于取消监听Esc键的订阅
    private var escKeySubscription: AnyCancellable?
    
    // 本地事件监视器
    private var localEventMonitor: Any?
    
    // 用于存储异步任务
    private var activeTasks: [Task<Void, Never>] = []
    
    override init() {
        super.init()
    }
    
    /**
     开始截图过程
     - Parameter completion: 截图完成后的回调
     */
    func startCapture(completion: @escaping CaptureCompletion) {
        // 存储回调
        currentCompletion = completion
        
        // 检查屏幕录制权限
        checkScreenCapturePermission { [weak self] hasPermission in
            guard let self = self, hasPermission else {
                // 没有权限时调用回调返回nil
                completion(nil)
                return
            }
            
            // 创建覆盖窗口
            self.createOverlayWindow()
        }
    }
    
    /**
     取消当前的截图过程
     */
    func cancelCapture() {
        cleanUp()
        currentCompletion?(nil)
        currentCompletion = nil
    }
    
    // MARK: - Private Methods
    
    /**
     检查屏幕录制权限
     */
    private func checkScreenCapturePermission(completion: @escaping (Bool) -> Void) {
        // 对于CGWindowListCreateImage，我们仍然需要权限，但不会显示录制指示器
        switch CGPreflightScreenCaptureAccess() {
        case true:
            // 已经有权限
            completion(true)
        case false:
            // 请求权限
            CGRequestScreenCaptureAccess()
            
            // 提示用户
            let alert = NSAlert()
            alert.messageText = "需要屏幕录制权限"
            alert.informativeText = "此应用需要屏幕录制权限才能进行截图。请在系统偏好设置的安全性与隐私中启用此权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "去设置")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 打开系统偏好设置
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
            
            completion(false)
        }
    }
    
    /**
     创建覆盖整个屏幕的窗口
     */
    private func createOverlayWindow() {
        // 获取主屏幕
        guard let mainScreen = NSScreen.main else { return }
        
        // 创建窗口
        let window = NSWindow(
            contentRect: mainScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: mainScreen
        )
        
        // 设置窗口属性
        window.level = .screenSaver // 在大多数内容之上
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isMovable = false
        window.hasShadow = false
        
        // 创建选区视图
        var selectionView = SelectionOverlayView()
        selectionView.onSelectionComplete = { [weak self] selectedRect in
           self?.captureSelectedArea(selectedRect)
        }
        selectionView.onSelectionCancel = { [weak self] in
           self?.cancelCapture()
        }
        
        // 保存引用
        self.selectionView = selectionView
        self.overlayWindow = window
        
        // 设置窗口内容
        window.contentView = NSHostingView(rootView: selectionView)
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        
        // 确保应用处于活跃状态
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /**
     对选定区域进行截图
     */
    private func captureSelectedArea(_ rect: CGRect) {
        // 转换为屏幕坐标
        guard NSScreen.main != nil else {
            cleanUp()
            currentCompletion?(nil)
            return
        }
        
        // 关闭遮罩窗口，避免捕获到自己的UI
        overlayWindow?.orderOut(nil)
        
        // 短暂延迟确保窗口已关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // 获取选择区域的屏幕坐标
            let screenRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height
            )
            
            // 使用Core Graphics进行截图
            let task = Task {
                do {
                    let image = try await self.captureScreenshot(in: screenRect)
                    
                    // 在主线程上执行UI更新和回调
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        // 清理UI
                        self.cleanUp()
                        
                        // 调用回调
                        self.currentCompletion?(image)
                        self.currentCompletion = nil
                    }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        // 清理UI
                        self.cleanUp()
                        
                        // 截图失败
                        self.currentCompletion?(nil)
                        self.currentCompletion = nil
                    }
                }
            }
            
            // 存储任务以便在清理时取消
            self.activeTasks.append(task)
        }
    }
    
    /**
     使用Core Graphics捕获屏幕截图
     */
    private func captureScreenshot(in rect: CGRect) async throws -> CGImage? {
        print("矩形:", rect)
        
        // 使用Core Graphics API捕获屏幕而不是ScreenCaptureKit
        // 这种方法不会在顶部菜单栏显示录制指示器
        let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
        return cgImage
    }
    
    /**
     清理资源
     */
    private func cleanUp() {
        // 取消所有异步任务
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        
        // 先移除事件监听
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        // 先释放 SwiftUI 视图引用
        selectionView = nil
        
        // 关闭窗口并释放引用
        overlayWindow?.contentView = nil  // 先清空内容视图
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}
