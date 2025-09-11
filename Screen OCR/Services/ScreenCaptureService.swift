import Cocoa
import SwiftUI
import CoreImage
import os.log
import Foundation

/**
 负责处理屏幕截图相关的功能
 */
class ScreenCaptureService: NSObject {
    // 截图结果回调
    typealias CaptureCompletion = (CGImage?, CGRect?) -> Void
    
    // 当前的截图完成回调
    private var currentCompletion: CaptureCompletion?
    
    // 截图窗口
    private var overlayWindow: NSWindow?
    private var selectionView: SelectionOverlayView?
    
    // 保存截图前的活动应用，用于截图后恢复
    private var previousActiveApp: NSRunningApplication?
    
    // 全屏截图，用于显示在选区界面背景
    private var fullScreenshot: NSImage?
    
    // UserDefaults键
    private let isFirstLaunchKey = "isFirstLaunch"
    
    override init() {
        super.init()
    }
    
    /**
     开始截图过程
     - Parameter completion: 截图完成后的回调
     */
    func startCapture(completion: @escaping CaptureCompletion) {
        // 保存当前活动应用
        previousActiveApp = NSWorkspace.shared.frontmostApplication
        
        // 存储回调
        currentCompletion = completion
        
        // 检查屏幕录制权限
        checkScreenCapturePermission { [weak self] hasPermission in
            guard let self = self, hasPermission else {
                // 没有权限时调用回调返回nil
                completion(nil, nil)
                // 恢复之前的活动应用
                self?.previousActiveApp?.activate(options: .activateIgnoringOtherApps)
                return
            }
            
            // 先进行全屏截图，然后创建覆盖窗口
            self.captureFullScreen { [weak self] fullScreenImage in
                guard let self = self else { return }
                self.fullScreenshot = fullScreenImage
                
                // 创建覆盖窗口
                DispatchQueue.main.async {
                    self.createOverlayWindow()
                }
            }
        }
    }
    
    /**
     取消当前的截图过程
     */
    func cancelCapture() {
        cleanUp()
        currentCompletion?(nil, nil)
        currentCompletion = nil
        
        // 恢复之前的活动应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.previousActiveApp?.activate(options: .activateIgnoringOtherApps)
            self?.previousActiveApp = nil
        }
    }
    
    // MARK: - Private Methods
    
    /**
     捕获全屏截图
     */
    private func captureFullScreen(completion: @escaping (NSImage?) -> Void) {
        guard let mainScreen = NSScreen.main else {
            completion(nil)
            return
        }
        
        let screenRect = mainScreen.frame
        
        // 使用Core Graphics进行全屏截图
        let cgImage = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
        
        guard let cgImage = cgImage else {
            completion(nil)
            return
        }
        
        // 转换为NSImage
        let nsImage = NSImage(cgImage: cgImage, size: screenRect.size)
        completion(nsImage)
    }
    
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
            // 检查是否是首次启动
            let isFirstLaunch = UserDefaults.standard.object(forKey: isFirstLaunchKey) == nil
            
            // 如果是首次启动，标记为非首次启动并直接请求权限
            if isFirstLaunch {
                UserDefaults.standard.set(false, forKey: isFirstLaunchKey)
                CGRequestScreenCaptureAccess()
                completion(false)
                return
            }
            
            // 非首次启动，显示提示
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
        selectionView.backgroundImage = fullScreenshot // 设置背景截图
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
        window.orderFront(nil)
        window.makeKey()

    }
    
    /**
     对选定区域进行截图
     */
    private func captureSelectedArea(_ rect: CGRect) {
        // 检查是否有全屏截图
        guard let fullScreenImage = fullScreenshot else {
            cleanUp()
            currentCompletion?(nil, nil)
            // 恢复之前的活动应用
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.previousActiveApp?.activate(options: .activateIgnoringOtherApps)
                self?.previousActiveApp = nil
            }
            return
        }
        
        // 获取主屏幕信息
        guard let mainScreen = NSScreen.main else {
            cleanUp()
            currentCompletion?(nil, nil)
            // 恢复之前的活动应用
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.previousActiveApp?.activate(options: .activateIgnoringOtherApps)
                self?.previousActiveApp = nil
            }
            return
        }
        
        // 关闭遮罩窗口
        overlayWindow?.orderOut(nil)
        
        // 直接从全屏截图中裁剪选定区域
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // 将选区坐标转换为图像坐标
            let imageRect = self.convertSelectionRectToImageRect(
                selectionRect: rect,
                screenFrame: mainScreen.frame,
                image: fullScreenImage
            )
            
            // 从全屏截图中裁剪选定区域
            let croppedImage = self.cropImage(fullScreenImage, toRect: imageRect)
            
            // 清理UI
            self.cleanUp()
            
            // 保存之前活动应用的引用
            let app = self.previousActiveApp
            
            // 调用回调，包含截图区域信息
            self.currentCompletion?(croppedImage, rect)
            self.currentCompletion = nil
            
            // 恢复之前的活动应用
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                app?.activate(options: .activateIgnoringOtherApps)
                self.previousActiveApp = nil
            }
        }
    }
    
    /**
     将选区坐标转换为图像坐标
     */
    private func convertSelectionRectToImageRect(
        selectionRect: CGRect,
        screenFrame: CGRect,
        image: NSImage
    ) -> CGRect {
        // 获取图像的CGImage来获得实际像素尺寸
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return selectionRect
        }
        
        // 获取图像的实际像素尺寸
        let imagePixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // 获取屏幕的逻辑尺寸
        let screenSize = screenFrame.size
        
        // 计算缩放比例
        // 这里使用实际像素尺寸与屏幕逻辑尺寸的比例
        let scaleX = imagePixelSize.width / screenSize.width
        let scaleY = imagePixelSize.height / screenSize.height
        
        // 转换选区坐标到图像坐标
        // SwiftUI 的坐标系是左上角为原点，与图像坐标系一致
        let imageRect = CGRect(
            x: selectionRect.minX * scaleX,
            y: selectionRect.minY * scaleY,
            width: selectionRect.width * scaleX,
            height: selectionRect.height * scaleY
        )
        
        // 确保坐标在图像范围内
        let clampedRect = CGRect(
            x: max(0, min(imageRect.minX, imagePixelSize.width)),
            y: max(0, min(imageRect.minY, imagePixelSize.height)),
            width: min(imageRect.width, imagePixelSize.width - imageRect.minX),
            height: min(imageRect.height, imagePixelSize.height - imageRect.minY)
        )
        return clampedRect
    }
    
    /**
     从NSImage中裁剪指定区域
     */
    private func cropImage(_ image: NSImage, toRect rect: CGRect) -> CGImage? {
        // 获取NSImage的CGImage表示
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // 确保裁剪区域在图像范围内
        let imageRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let clampedRect = rect.intersection(imageRect)
        
        // 如果裁剪区域为空，返回nil
        guard !clampedRect.isEmpty else {
            return nil
        }
        
        // 裁剪图像
        return cgImage.cropping(to: clampedRect)
    }
    
    /**
     清理资源
     */
    private func cleanUp() {
        // 清理全屏截图
        fullScreenshot = nil
        
        // 先释放 SwiftUI 视图引用
        selectionView = nil
        
        // 关闭窗口并释放引用
        overlayWindow?.contentView = nil  // 先清空内容视图
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}
