import Cocoa
import SwiftUI
import Foundation

/**
 OCR内容视图，包含图像和文本区域
 */
class OCRContentView: NSView {
    // 图像视图
    private var imageView: NSImageView!
    
    // 文本视图
    private var textView: NSTextView!
    
    // 滚动视图
    private var scrollView: NSScrollView!
    
    // 文本区域最小宽度
    private let minTextWidth: CGFloat = 210

    // 图像区域最小宽度
    private let minImageWidth: CGFloat = 210
    
    // 最小高度
    private let minBoxHeight: CGFloat = 110
    
    // 文本区域最大宽度
    private var maxTextWidth: CGFloat
    
    // 初始化方法
    override init(frame frameRect: NSRect) {
        maxTextWidth = frameRect.width * 0.4
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        maxTextWidth = minTextWidth
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // 计算文本区域宽度
        let textWidth = max(minTextWidth, maxTextWidth)
        // 计算图像视图宽度
        let imageWidth = max(minImageWidth, bounds.width - textWidth)
        // 计算高度
        let height = max(minBoxHeight, bounds.height)

        // 创建图像视图（左侧）
        imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: imageWidth, height: height))
        imageView.imageScaling = .scaleProportionallyDown
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)
        
        // 创建文本滚动区域（右侧）
        scrollView = NSScrollView(frame: NSRect(x: imageWidth, y: 0, width: textWidth, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        // 只设置高度自动调整，宽度我们会手动控制
        scrollView.autoresizingMask = [.height]
        
        // 创建文本视图
        // 计算文本视图宽度，减去滚动条宽度
        let scrollWidth = NSScroller.scrollerWidth(for: .regular, scrollerStyle: NSScroller.preferredScrollerStyle)
        let adjustedTextWidth = textWidth - scrollWidth
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: adjustedTextWidth, height: height))
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        
        // 把文本视图添加到滚动视图
        scrollView.documentView = textView
        addSubview(scrollView)
    }
    
    // 窗口大小变化时调整视图
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        updateLayout()
    }
    
    // 更新布局
    private func updateLayout() {
        // 计算左右区域宽度
        // 计算文本区域宽度
        let smallerTextWidth = min(bounds.width * 0.4, maxTextWidth)
        let textWidth = max(minTextWidth, smallerTextWidth)
        // 计算图像视图宽度
        let imageWidth = max(minImageWidth, bounds.width - textWidth)
        // 计算高度
        let height = max(minBoxHeight, bounds.height)
        
        // 调整图像视图宽度
        var imageFrame = imageView.frame
        imageFrame.size.width = imageWidth
        imageFrame.size.height = height
        imageView.frame = imageFrame
        
        // 调整滚动视图位置和宽度
        var scrollFrame = scrollView.frame
        scrollFrame.origin.x = imageWidth
        scrollFrame.size.width = textWidth
        scrollFrame.size.height = height
        scrollView.frame = scrollFrame
        
        // 调整文本视图宽度，减去滚动条宽度
        if let textContainer = textView.textContainer {
            let scrollWidth = NSScroller.scrollerWidth(for: .regular, scrollerStyle: NSScroller.preferredScrollerStyle)
            let adjustedWidth = textWidth - scrollWidth
            textContainer.containerSize = NSSize(width: adjustedWidth, height: CGFloat.greatestFiniteMagnitude)
        }
    }
    
    // 配置视图
    func configure(with image: NSImage, ocrResults: [OCRResult]) {
        // 设置图像
        imageView.image = image
        
        // 设置文本
        textView.string = ocrResults.map { $0.text }.joined(separator: "\n")
    }
} 
