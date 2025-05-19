import SwiftUI

/**
 用于创建矩形选区的覆盖视图
 */
struct SelectionOverlayView: View {
    // 选区完成时的回调
    var onSelectionComplete: ((CGRect) -> Void)?
    // 取消选区的回调
    var onSelectionCancel: (() -> Void)?
    
    // 当前选区状态
    @State private var selectionState: SelectionState = .notStarted
    
    // 选区起始点和当前点
    @State private var startPoint: CGPoint = .zero
    @State private var currentPoint: CGPoint = .zero
    
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
                // 半透明背景
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                
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
                                    .fill(Color.black.opacity(0.65))
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
                
                // 选区
                if selectionState != .notStarted {
                    // 选区区域透明，周围是半透明遮罩
                    SelectionMaskView(selectedRect: selectedRect, screenSize: geometry.size)
                    
                    // 选区边框
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: selectedRect.width, height: selectedRect.height)
                        .position(x: selectedRect.midX, y: selectedRect.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geometry.size))
            .onAppear {
                NSCursor.crosshair.push() // 设置鼠标为十字光标
                
                // 添加键盘事件监听
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    // 检测Esc键 (keyCode 53)
                    if event.keyCode == 53 {
                        onSelectionCancel?()
                        return nil // 消费此事件
                    }
                    return event
                }
            }
            .onDisappear {
                NSCursor.pop() // 恢复鼠标光标
            }
        }
    }
    
    // 鼠标拖拽手势
    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
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
}

/**
 创建选区蒙版视图（选区区域透明，其余区域半透明黑色）
 */
struct SelectionMaskView: View {
    var selectedRect: CGRect
    var screenSize: CGSize
    
    var body: some View {
        Canvas { context, size in
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
