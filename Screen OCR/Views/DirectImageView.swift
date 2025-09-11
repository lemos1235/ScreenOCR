import Cocoa
import SwiftUI
import VisionKit

/**
 直接图像显示视图，无标题栏，带阴影边框，总是显示在最上层，支持OCR功能
 */
class DirectImageView: NSView, ImageAnalysisOverlayViewDelegate {
    // MARK: - Properties
    private var imageView: NSImageView!
    private var image: NSImage
    private var imageWindow: NSWindow?
    private var languages: [String]
    
    // 图像的原始尺寸和位置
    private let imageRect: CGRect
    
    // Live Text 交互
    @available(macOS 13.0, *)
    private var imageAnalysisOverlay: ImageAnalysisOverlayView?
    
    // 键盘事件监听器
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    
    // MARK: - Initialization
    init(image: NSImage, imageRect: CGRect, languages: [String] = []) {
        self.image = image
        self.imageRect = imageRect
        self.languages = languages
        
        // 计算视图的完整frame，包括菜单栏高度
        let menuBarHeight: CGFloat = 40 + 12 // 容器高度 + 间距
        let fullFrame = CGRect(
            x: 0,
            y: 0,
            width: imageRect.width,
            height: imageRect.height + menuBarHeight
        )
        
        super.init(frame: fullFrame)
        setupView()
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView() {
        // 设置视图属性
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        // 添加阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowOffset = NSSize(width: 0, height: -4)
        layer?.shadowRadius = 12
        layer?.masksToBounds = false
        
        // 创建图像视图（frame 将在 setupMenuButton 中设置）
        imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
        
        // Live Text 交互将在 setupMenuButton 后设置
    }
    
    private func setupWindow() {
        // 计算菜单栏区域高度
        let menuBarHeight: CGFloat = 40 + 12 // 容器高度 + 间距
        
        // 获取主屏幕信息用于坐标转换
        guard let mainScreen = NSScreen.main else { return }
        let screenFrame = mainScreen.frame
        
        // 将 SwiftUI 坐标（左上角为原点）转换为 macOS 窗口坐标（左下角为原点）
        let windowY = screenFrame.height - imageRect.origin.y - imageRect.height - menuBarHeight
        
        // 创建包含菜单栏高度的窗口矩形
        let windowRect = CGRect(
            x: imageRect.origin.x,
            y: windowY, // 使用转换后的 y 坐标
            width: imageRect.width,
            height: imageRect.height + menuBarHeight
        )
        
        // 创建无边框窗口
        let window = CustomDirectImageWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口属性
        window.level = .floating  // 总是显示在最上层
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false  // 我们使用自定义阴影
        window.isMovable = true
        window.acceptsMouseMovedEvents = true
        
        // 设置内容视图
        window.contentView = self
        
        // 保存窗口引用
        self.imageWindow = window
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        
        // 添加底部菜单按钮
        setupMenuButton()
    }
    
    private func setupMenuButton() {
        // 创建底部菜单按钮容器（透明背景）
        let buttonContainer = NSView()
        buttonContainer.wantsLayer = true
        buttonContainer.layer?.backgroundColor = NSColor.clear.cgColor
        
        // 创建按钮
        let copyTextButton = createIconButton(
             systemImage: "square.on.square",
            action: #selector(copyText),
            tooltip: "复制文本"
        )
        
        let closeButton = createIconButton(
            systemImage: "xmark",
            action: #selector(closeImage),
            tooltip: "关闭"
        )
        
        // 设置容器布局
        let buttonSize: CGFloat = 28
        let containerHeight: CGFloat = 40
        let buttonSpacing: CGFloat = 16
        let buttonCount: CGFloat = 2 // 实际按钮数量
        
        let totalWidth = buttonSize * buttonCount + buttonSpacing * (buttonCount - 1)
        let containerFrame = CGRect(
            x: (bounds.width - totalWidth) / 2,
            y: 6,
            width: totalWidth,
            height: containerHeight
        )
        
        buttonContainer.frame = containerFrame
        
        // 布局按钮
        let buttonY = (containerHeight - buttonSize) / 2
        
        copyTextButton.frame = CGRect(x: 0, y: buttonY, width: buttonSize, height: buttonSize)
        closeButton.frame = CGRect(x: buttonSize + buttonSpacing, y: buttonY, width: buttonSize, height: buttonSize)
        
        // 添加按钮到容器
        buttonContainer.addSubview(copyTextButton)
        buttonContainer.addSubview(closeButton)
        
        // 添加容器到主视图
        addSubview(buttonContainer)
        
        // 设置图像视图位置 - 占据上部分区域，保持原始图像尺寸
        let menuBarHeight: CGFloat = containerHeight + 12
        imageView.frame = CGRect(
            x: 0, 
            y: menuBarHeight, 
            width: imageRect.width, 
            height: imageRect.height
        )
        
        // 设置 Live Text 交互
        if #available(macOS 13.0, *) {
            setupImageAnalysisOverlay()
        }
    }
    
    // 创建图标按钮的辅助方法
    private func createIconButton(systemImage: String, action: Selector, tooltip: String) -> NSButton {
        let button = HoverButton()
        
        // 设置图标
        if let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: tooltip) {
            button.image = image
        }
        
        // 设置按钮样式
        button.isBordered = false
        button.imageScaling = .scaleProportionallyUpOrDown
        button.target = self
        button.action = action
        button.toolTip = tooltip
        
        // 设置视觉效果
        button.wantsLayer = true
        button.layer?.cornerRadius = 14 // 圆形按钮
        button.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        
        // 设置图标大小
        button.imageScaling = .scaleProportionallyDown
        
        return button
    }
    
    @objc private func copyText() {
        if #available(macOS 13.0, *), let overlay = imageAnalysisOverlay {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            
            // 获取所有识别的文本
            if let analysis = overlay.analysis {
                pasteboard.setString(analysis.transcript, forType: .string)
            }
        } else {
            // 在较老的系统上，使用传统的OCR方法
            let ocrService = OCRService()
            ocrService.performOCR(on: image, languages: languages) { results in
                let recognizedText = results.map { $0.text }.joined(separator: "\n")
                
                DispatchQueue.main.async {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(recognizedText, forType: .string)
                }
            }
        }
    }
    
    @objc func closeImage() {
        imageWindow?.close()
        imageWindow = nil
    }
    
    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        // 允许拖动窗口
        imageWindow?.performDrag(with: event)
    }
    
    // MARK: - OCR 功能
    
    // 设置图像分析叠加层
    @available(macOS 13.0, *)
    private func setupImageAnalysisOverlay() {
        let overlay = ImageAnalysisOverlayView()
        imageAnalysisOverlay = overlay
        
        // 设置叠加层
        overlay.autoresizingMask = [.width, .height]
        overlay.frame = imageView.bounds
        overlay.trackingImageView = imageView
        
        // 配置交互行为
        overlay.preferredInteractionTypes = [.textSelection]
        overlay.isSupplementaryInterfaceHidden = true
        
        // 设置代理
        overlay.delegate = self
        
        // 添加到图像视图
        imageView.addSubview(overlay)
        
        // 开始图像分析
        configureImageAnalysis()
    }
    
    // 配置图像分析功能
    @available(macOS 13.0, *)
    private func configureImageAnalysis() {
        guard let overlay = imageAnalysisOverlay else { return }
        
        let analyzer = ImageAnalyzer()
        var configuration = ImageAnalyzer.Configuration([.text])
        if !languages.isEmpty {
            configuration.locales = languages
        }
        
        Task {
            do {
                let analysis = try await analyzer.analyze(image, orientation: .up, configuration: configuration)
                await MainActor.run {
                    overlay.analysis = analysis
                }
            } catch {
                await MainActor.run {
                    print("图像分析失败：\(error)")
                }
            }
        }
    }
    
    // MARK: - ImageAnalysisOverlayViewDelegate
    @available(macOS 13.0, *)
    func textSelectionDidChange(_ overlayView: ImageAnalysisOverlayView) {
        // 可以在这里处理文本选择变化
        if #available(macOS 14.0, *) {
            if overlayView.hasActiveTextSelection {
                // 处理文本选择
            }
        }
    }
}

/**
 自定义按钮类，支持悬停效果
 */
class HoverButton: NSButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTracking()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }
    
    private func setupTracking() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // 悬停时增加透明度
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9).cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // 恢复原始透明度
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // 移除旧的追踪区域
        trackingAreas.forEach { removeTrackingArea($0) }
        
        // 添加新的追踪区域
        setupTracking()
    }
}

/**
 自定义窗口类，支持键盘事件
 */
class CustomDirectImageWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

/**
 直接图像窗口管理器
 */
class DirectImageWindowManager: NSObject {
    // 当前显示的图像窗口
    private var currentImageView: DirectImageView?
    
    /**
     直接显示图像在截图区域
     - Parameter image: 要显示的图像
     - Parameter rect: 图像在屏幕上的位置和大小
     - Parameter languages: OCR识别的语言，默认自动检测
     */
    func showImage(_ image: NSImage, at rect: CGRect, languages: [String] = []) {
        // 关闭已有的图像显示
        closeCurrentImage()
        
        // 创建新的图像视图
        currentImageView = DirectImageView(image: image, imageRect: rect, languages: languages)
    }
    
    /**
     关闭当前显示的图像
     */
    func closeCurrentImage() {
        currentImageView?.closeImage()
        currentImageView = nil
    }
}
