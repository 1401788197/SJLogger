import UIKit

// MARK: - 悬浮窗
/// 小圆圈悬浮窗，显示未读日志数量，可拖动，点击打开日志列表，长按清除当前日志
class SJFloatingWindow: UIView {
    private static let diameter: CGFloat = 36
    
    // MARK: - 属性
    
    private var panGesture: UIPanGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    private var longPressGesture: UILongPressGestureRecognizer!
    private var initialCenter: CGPoint = .zero
    
    // MARK: - UI组件
    
    private let circleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = SJFloatingWindow.diameter / 2
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 5
        view.layer.shadowOpacity = 0.35
        return view
    }()
    
    private let countLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.text = "0"
        return label
    }()
    
    // MARK: - 初始化
    
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter))
        setupUI()
        setupGestures()
        observeLogUpdates()
        observeWindowChanges()
        updateCount()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        // 设置背景色
        circleView.backgroundColor = SJLoggerConfig.shared.floatingWindowColor
        
        addSubview(circleView)
        circleView.addSubview(countLabel)
        
        circleView.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            circleView.topAnchor.constraint(equalTo: topAnchor),
            circleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            circleView.trailingAnchor.constraint(equalTo: trailingAnchor),
            circleView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            countLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),
            countLabel.leadingAnchor.constraint(equalTo: circleView.leadingAnchor, constant: 4),
            countLabel.trailingAnchor.constraint(equalTo: circleView.trailingAnchor, constant: -4)
        ])
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
        
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.8
        addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - 显示和隐藏
    
    func show() {
        // 移除旧的，重新添加
        self.removeFromSuperview()
        
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        
        window.addSubview(self)
        
        // 确保悬浮窗在最上层
        bringToFront()
        
        // 初始位置：右下角
        let x = window.bounds.width - Self.diameter - 10
        let y = window.bounds.height - 160
        self.frame.origin = CGPoint(x: x, y: y)
        
        // 动画显示
        self.alpha = 0
        self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    func hide() {
        UIView.animate(withDuration: 0.2) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
    
    // MARK: - 手势处理
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let window = superview else { return }
        
        let translation = gesture.translation(in: window)
        
        switch gesture.state {
        case .began:
            initialCenter = center
            UIView.animate(withDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
            
        case .changed:
            center = CGPoint(x: initialCenter.x + translation.x,
                           y: initialCenter.y + translation.y)
            
        case .ended, .cancelled:
            // 吸附到边缘
            snapToEdge()
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
            
        default:
            break
        }
    }
    
    @objc private func handleTap() {
        // 点击动画
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
        
        // 打开日志列表
        SJLogger.shared.showLogList()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 缩放动画
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
        
        SJLoggerStorage.shared.clearCurrentLogs()
        showClearedFeedback()
    }
    
    private func showClearedFeedback() {
        countLabel.text = "0"
        let originalColor = circleView.backgroundColor
        circleView.backgroundColor = .systemGreen
        countLabel.text = "✓"
        UIView.animate(withDuration: 0.18, animations: {
            self.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
        }) { _ in
            UIView.animate(withDuration: 0.18, delay: 0.45) {
                self.transform = .identity
                self.circleView.backgroundColor = originalColor
                self.countLabel.text = "0"
            }
        }
    }
    
    // MARK: - 吸附到边缘
    
    private func snapToEdge() {
        guard let window = superview else { return }
        
        let screenWidth = window.bounds.width
        let screenHeight = window.bounds.height
        let margin: CGFloat = 10
        
        var newCenter = center
        
        // 水平方向吸附
        if center.x < screenWidth / 2 {
            newCenter.x = frame.width / 2 + margin
        } else {
            newCenter.x = screenWidth - frame.width / 2 - margin
        }
        
        // 垂直方向限制
        let minY = frame.height / 2 + margin + (window.safeAreaInsets.top)
        let maxY = screenHeight - frame.height / 2 - margin - (window.safeAreaInsets.bottom)
        newCenter.y = max(minY, min(maxY, center.y))
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.center = newCenter
        }
    }
    
    // MARK: - 保持置顶
    
    private func observeWindowChanges() {
        // 监听应用进入前台
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(bringToFront),
                                              name: UIApplication.willEnterForegroundNotification,
                                              object: nil)
        
        // 监听应用变为活跃状态
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(bringToFront),
                                              name: UIApplication.didBecomeActiveNotification,
                                              object: nil)
    }
    
    @objc private func bringToFront() {
        guard let window = self.superview else { return }
        window.bringSubviewToFront(self)
    }
    
    // 重写didMoveToSuperview，每次添加到父视图时自动置顶
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            bringToFront()
        }
    }
    
    // MARK: - 更新徽章
    
    private func observeLogUpdates() {
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(updateCount),
                                              name: SJLoggerStorage.logsDidUpdateNotification,
                                              object: nil)
    }
    
    @objc private func updateCount() {
        SJLoggerStorage.shared.getAllLogs { [weak self] logs in
            guard let self = self else { return }
            
            let count = logs.count
            self.countLabel.text = count > 99 ? "99+" : "\(count)"
        }
    }
}
