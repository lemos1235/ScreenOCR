import Cocoa
import SwiftUI
import Foundation
import VisionKit

/**
 OCR内容视图，包含图像和文本区域
 */
class OCRContentView: NSView, ImageAnalysisOverlayViewDelegate {
    // MARK: - Constants
    private enum Constants {
        static let minTextWidth: CGFloat = 210
        static let minImageWidth: CGFloat = 210
        static let defaultTextRatio: CGFloat = 0.4
        static let systemFontSize: CGFloat = 13
        static let ambiguousTitleBarHeight: CGFloat = 28.0
    }
    
    // MARK: - UI Components
    // 图像视图
    private var imageView: NSImageView!
    
    // 文本视图
    private var textView: NSTextView!
    
    // 滚动视图
    private var scrollView: NSScrollView!
    
    // Live Text 交互
    @available(macOS 13.0, *)
    private var imageAnalysisOverlay: ImageAnalysisOverlayView?
    
    // MARK: - Properties
    // OCR 支持的语言
    private var locales: [String]?
    
    // 窗口初始化宽度
    private var initialWidth: CGFloat
    
    // 窗口初始化高度
    private var initialHeight: CGFloat
    
    // MARK: - Initialization
    init(frame frameRect: NSRect, image: NSImage? = nil, locales: [String]? = nil) {
        initialWidth = frameRect.width
        initialHeight = frameRect.height
        self.locales = locales
        super.init(frame: frameRect)
        setupView()
        if let image = image {
            setImage(image)
        }
    }
    
    required init?(coder: NSCoder) {
        initialWidth = 0
        initialHeight = 0
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        setupImageView()
        setupTextView()
        
        // 设置 Live Text 交互
        if #available(macOS 13.0, *) {
            setupImageAnalysisOverlay()
        }
    }
    
    private func setupImageView() {
        // 计算图像视图宽度和高度
        let (imageWidth, _, _, height) = calculateDimensions()
        
        // 创建图像视图（左侧）
        imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: imageWidth, height: height))
        // imageView.imageScaling = .scaleProportionallyDown
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)
    }
    
    private func setupTextView() {
        // 计算文本区域宽度和高度
        let (imageWidth, textFrameWidth, textWidth, height) = calculateDimensions()
        
        // 创建文本滚动区域（右侧）
        scrollView = NSScrollView(frame: NSRect(x: imageWidth, y: 0, width: textFrameWidth, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        // 只设置高度自动调整，宽度我们会手动控制
        scrollView.autoresizingMask = [.height]
        
        // 创建文本视图
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: textWidth, height: height))
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: Constants.systemFontSize)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        
        // 把文本视图添加到滚动视图
        scrollView.documentView = textView
        addSubview(scrollView)
    }
    
    // MARK: - Layout
    // 窗口大小变化时调整视图
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        updateLayout()
    }
    
    // 更新布局
    private func updateLayout() {
        // 计算尺寸
        let (imageWidth, textFrameWidth, textWidth, height) = calculateDimensions()
        
        // 调整图像视图宽度
        var imageFrame = imageView.frame
        imageFrame.size.width = imageWidth
        imageFrame.size.height = height
        imageView.frame = imageFrame
        
        // 更新分析叠加层尺寸
        if #available(macOS 13.0, *), let overlay = imageAnalysisOverlay {
            overlay.frame = imageView.bounds
        }
        
        // 调整滚动视图位置和宽度
        var scrollFrame = scrollView.frame
        scrollFrame.origin.x = imageWidth
        scrollFrame.size.width = textFrameWidth
        scrollFrame.size.height = height
        scrollView.frame = scrollFrame
        
        // 调整文本视图宽度，减去滚动条宽度
        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
        }
    }
    
    // 计算图像和文本区域尺寸
    private func calculateDimensions() -> (imageWidth: CGFloat, textFrameWidth: CGFloat, textWidth: CGFloat, height: CGFloat) {
        // 计算文本区域宽度
        let textFrameWidth = max(Constants.minTextWidth, min(bounds.width, initialWidth) * Constants.defaultTextRatio)
        // 计算文本区域宽度
        let textWidth = textFrameWidth - NSScroller.scrollerWidth(for: .regular, scrollerStyle: NSScroller.preferredScrollerStyle)
        // 计算图像区域宽度
        let imageWidth = max(Constants.minImageWidth, bounds.width - textFrameWidth)
        // 计算高度
        let height = max(initialHeight, bounds.height) - Constants.ambiguousTitleBarHeight
        return (imageWidth, textFrameWidth, textWidth, height)
    }
    
    // MARK: - Image Analysis
    // 设置图像
    public func setImage(_ image: NSImage) {
        imageView.image = image
        if #available(macOS 13.0, *) {
            configureImageAnalysis(with: image)
        }
    }
    
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
    }
    
    // 配置图像分析功能
    @available(macOS 13.0, *)
    private func configureImageAnalysis(with image: NSImage) {
        guard let overlay = imageAnalysisOverlay else { return }
        
        let analyzer = ImageAnalyzer()
        var configuration = ImageAnalyzer.Configuration([.text])
        if let locales = locales {
            configuration.locales = locales
        }
        
        Task {
            do {
                let analysis = try await analyzer.analyze(image, orientation: .up, configuration: configuration)
                await MainActor.run {
                    // 更新文本视图
                    self.textView.string = analysis.transcript
                    overlay.analysis = analysis
                }
            } catch {
                await MainActor.run {
                    print("分析失败：\(error)")
                    // 错误处理可添加用户提示或日志
                    self.textView.string = "图像分析失败：\(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Text Selection
    // ImageAnalysisOverlayViewDelegate
    @available(macOS 13.0, *)
    func textSelectionDidChange(_ overlayView: ImageAnalysisOverlayView) {
        if #available(macOS 14.0, *) {
            // 自动选中相同的文本
            if overlayView.hasActiveTextSelection{
                let text = overlayView.text
                overlayView.selectedRanges.forEach { range in
                    let startInt = text.distance(from: text.startIndex, to: range.lowerBound)
                    let length = text.distance(from: range.lowerBound, to: range.upperBound)
                    let nsRange = NSRange(location: startInt, length: length)
                    textView.setSelectedRange(nsRange)
                    textView.scrollRangeToVisible(nsRange)
                }
            }
        }
    }
}
