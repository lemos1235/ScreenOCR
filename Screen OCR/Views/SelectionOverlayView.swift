import SwiftUI

/**
 用于创建矩形选区的覆盖视图
 */
struct SelectionOverlayView: View {
    // 选区完成时的回调
    var onSelectionComplete: ((CGRect) -> Void)?
    
    // 取消选区的回调
    var onSelectionCancel: (() -> Void)?
    
    // 背景截图
    var backgroundImage: NSImage?
    
    // 当前选区状态
    @State private var selectionState: SelectionState = .notStarted
    
    // 选区起始点
    @State private var startPoint: CGPoint = .zero
    
    // 选区当前点
    @State private var currentPoint: CGPoint = .zero
    
    // 鼠标当前位置（用于显示坐标）
    @State private var mousePosition: CGPoint = .zero
    
    // 键盘事件监听器
    @State private var localKeyMonitor: Any?
    
    @State private var globalKeyMonitor: Any?
    
    // 焦点状态
    @FocusState private var isFocused: Bool
    
    // 计算当前选区矩形
    private var selectedRect: CGRect {
        let minX = min(startPoint.x, currentPoint.x)
        let minY = min(startPoint.y, currentPoint.y)
        let width = abs(startPoint.x - currentPoint.x)
        let height = abs(startPoint.y - currentPoint.y)
        
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景截图
                if let backgroundImage = backgroundImage {
                    Image(nsImage: backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                
                // 提示文本
                if selectionState == .notStarted {
                    VStack {
                        Text("Drag to select area")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.black.opacity(0.75))
                                    .shadow(radius: 8)
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .padding(.top, 80)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.3), value: selectionState)
                }
                
                // 选区遮罩和边框
                if selectionState != .notStarted {
                    // 选区区域透明，周围是半透明遮罩
                    SelectionMaskView(
                        selectedRect: selectedRect,
                        screenSize: geometry.size
                    )
                    
                    // 选区边框
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: selectedRect.width, height: selectedRect.height)
                        .position(x: selectedRect.midX, y: selectedRect.midY)
                }
                
                // 坐标提示
                CoordinateTooltip(
                    position: mousePosition,
                    selectedRect: selectionState == .selecting ? selectedRect : nil,
                    screenSize: geometry.size
                )
            }
            .contentShape(Rectangle())
            .focusable()
            .focused($isFocused)
            .gesture(dragGesture(in: geometry.size))
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    mousePosition = location
                case .ended:
                    break
                }
            }
            .onAppear {
                setupKeyboardMonitoring()
                // 请求焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
            .onDisappear {
                cleanupKeyboardMonitoring()
            }
        }
    }
    
    // 鼠标拖拽手势
    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // 更新鼠标位置
                mousePosition = value.location
                
                switch selectionState {
                case .notStarted:
                    // 开始选择
                    selectionState = .selecting
                    startPoint = value.startLocation
                    currentPoint = value.location
                case .selecting:
                    // 更新当前位置
                    currentPoint = value.location
                case .completed:
                    // 已完成状态不做任何处理
                    break
                }
            }
            .onEnded { value in
                if selectionState == .selecting {
                    // 完成选择
                    selectionState = .completed
                    // 调用回调，通知选区完成
                    if selectedRect.width > 5 && selectedRect.height > 5 {
                        onSelectionComplete?(selectedRect)
                    }
                }
            }
    }
    
    // 设置键盘监听
    private func setupKeyboardMonitoring() {
        // 本地事件监听器（当应用有焦点时）
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC 键
                onSelectionCancel?()
                return nil
            }
            return event
        }
        
        // 全局事件监听器（即使应用失去焦点也能工作）
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC 键
                DispatchQueue.main.async {
                    onSelectionCancel?()
                }
            }
        }
    }
    
    // 清理键盘监听
    private func cleanupKeyboardMonitoring() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
    }
}

/**
 创建选区蒙版视图（选区区域透明，其余区域半透明黑色）
 */
struct SelectionMaskView: View {
    var selectedRect: CGRect
    var screenSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // 原有的遮罩逻辑（无背景图像时）
            // 绘制整个屏幕的半透明蒙版
            let fullScreenPath = Path(CGRect(origin: .zero, size: size))
            context.fill(fullScreenPath, with: .color(.black.opacity(0.4)))
            
            // 在选区区域创建透明的"挖空"区域
            if selectedRect.width > 0 && selectedRect.height > 0 {
                let selectionPath = Path(selectedRect)
                context.blendMode = .destinationOut // 使绘制区域透明
                context.fill(selectionPath, with: .color(.white))
            }
        }
    }
}

/**
 坐标提示组件
 */
private struct TooltipSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct CoordinateTooltip: View {
    let position: CGPoint
    let selectedRect: CGRect?
    let screenSize: CGSize
    
    @State private var tooltipSize: CGSize = .zero
    
    private var tooltipPosition: CGPoint {
        let screenEdgeMargin: CGFloat = 15
        let horizontalOffset: CGFloat = 20
        let verticalOffset: CGFloat = 20
        
        var tooltipOriginX = position.x + horizontalOffset
        var tooltipOriginY = position.y + verticalOffset
        
        if tooltipOriginX + tooltipSize.width + screenEdgeMargin > screenSize.width {
            tooltipOriginX = position.x - horizontalOffset - tooltipSize.width
        }
        
        if tooltipOriginY + tooltipSize.height + screenEdgeMargin > screenSize.height {
            tooltipOriginY = position.y - verticalOffset - tooltipSize.height
        }
        
        tooltipOriginX = max(screenEdgeMargin,
                             min(tooltipOriginX, screenSize.width - tooltipSize.width - screenEdgeMargin))
        
        tooltipOriginY = max(screenEdgeMargin,
                             min(tooltipOriginY, screenSize.height - tooltipSize.height - screenEdgeMargin))
        return CGPoint(x: tooltipOriginX + tooltipSize.width / 2,
                       y: tooltipOriginY + tooltipSize.height / 2)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("X: \(Int(position.x))")
            Text("Y: \(Int(position.y))")
            if let rect = selectedRect, rect.width > 0 || rect.height > 0 {
                Text("W: \(Int(rect.width))")
                    .foregroundColor(.cyan)
                Text("H: \(Int(rect.height))")
                    .foregroundColor(.cyan)
            }
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.75))
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
        )
        .overlay(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: TooltipSizeKey.self, value: proxy.size)
            }
                .allowsHitTesting(false)
        )
        .onPreferenceChange(TooltipSizeKey.self) { newSize in
            if self.tooltipSize != newSize {
                self.tooltipSize = newSize
            }
        }
        .opacity(tooltipSize == .zero ? 0 : 1)
        .position(tooltipPosition)
    }
}

/**
 选区状态枚举
 */
enum SelectionState {
    case notStarted  // 未开始选择
    case selecting   // 正在选择
    case completed   // 选择完成
}

// SwiftUI预览
struct SelectionOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        SelectionOverlayView()
    }
}
