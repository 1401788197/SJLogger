import UIKit

// MARK: - 自定义导航栏
/// SJLogger 内部使用的顶部栏，避免宿主工程的 UINavigationBar 全局修改影响布局。
class SJCustomNavigationBar: UIView {
    private let leftStack = UIStackView()
    private let rightStack = UIStackView()
    private let titleLabel = UILabel()
    private static let iconButtonSize = CGSize(width: 30, height: 38)
    private static let iconPointSize: CGFloat = 18
    
    init(title: String) {
        super.init(frame: .zero)
        setupUI()
        setTitle(title)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func setTitle(_ title: String) {
        titleLabel.text = title
        titleLabel.isHidden = title.isEmpty
    }
    
    func setLeftButtons(_ buttons: [UIButton]) {
        setButtons(buttons, in: leftStack)
    }
    
    func setRightButtons(_ buttons: [UIButton]) {
        setButtons(buttons, in: rightStack)
    }
    
    static func iconButton(systemName: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        setIcon(systemName, for: button)
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.imageView?.contentMode = .scaleAspectFit
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(target, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: iconButtonSize.width),
            button.heightAnchor.constraint(equalToConstant: iconButtonSize.height)
        ])
        return button
    }
    
    static func setIcon(_ systemName: String, for button: UIButton, color: UIColor = SJLoggerConfig.shared.floatingWindowColor) {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
        let image = UIImage(systemName: systemName, withConfiguration: symbolConfig)
        if #available(iOS 15.0, *) {
            var configuration = button.configuration ?? .plain()
            configuration.image = image
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            configuration.baseForegroundColor = color
            button.configuration = configuration
        } else {
            button.setImage(image, for: .normal)
        }
        button.tintColor = color
    }
    
    static func textButton(title: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.title = title
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
            configuration.baseForegroundColor = SJLoggerConfig.shared.floatingWindowColor
            button.configuration = configuration
        } else {
            button.setTitle(title, for: .normal)
            button.setTitleColor(SJLoggerConfig.shared.floatingWindowColor, for: .normal)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        }
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        [leftStack, rightStack].forEach {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.spacing = 3
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        
        addSubview(leftStack)
        addSubview(rightStack)
        addSubview(titleLabel)
        
        [leftStack, rightStack, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),
            
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8)
        ])
    }
    
    private func setButtons(_ buttons: [UIButton], in stack: UIStackView) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buttons.forEach { stack.addArrangedSubview($0) }
    }
}

// MARK: - 主题/配色
/// 统一的颜色与样式工具
public enum SJTheme {
    
    /// 日志类型对应主色
    static func color(for type: SJLogType) -> UIColor {
        switch type {
        case .http, .https: return .systemBlue
        case .tcp: return .systemPurple
        case .udp: return .systemOrange
        case .websocket: return .systemGreen
        }
    }
    
    /// HTTP方法对应主色
    static func color(for method: SJHTTPMethod) -> UIColor {
        switch method {
        case .get: return .systemBlue
        case .post: return .systemGreen
        case .put, .patch: return .systemOrange
        case .delete: return .systemRed
        default: return .systemGray
        }
    }
    
    /// 状态码对应颜色
    static func color(forStatus code: Int?) -> UIColor {
        guard let code = code else { return .systemGray }
        switch code {
        case 200...299: return .systemGreen
        case 300...399: return .systemTeal
        case 400...499: return .systemOrange
        case 500...599: return .systemRed
        case 101, 1000: return .systemGreen   // WebSocket
        default: return .systemGray
        }
    }
}

// MARK: - 胶囊徽标
/// 带内边距的圆角徽标，用于方法/类型/状态码等
class SJBadgeLabel: UIView {
    
    private let label = UILabel()
    private let hInset: CGFloat = 6
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 5
        layer.masksToBounds = true
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hInset),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -hInset),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    /// 设置文本与主色（背景为主色淡化）
    func setText(_ text: String, color: UIColor) {
        label.text = text
        label.textColor = color
        backgroundColor = color.withAlphaComponent(0.15)
        isHidden = text.isEmpty
    }
    
    /// 实心样式（白字+实色背景）
    func setSolidText(_ text: String, color: UIColor) {
        label.text = text
        label.textColor = .white
        backgroundColor = color
        isHidden = text.isEmpty
    }
}

// MARK: - 带内边距的Label
class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}

// MARK: - 顶部统计条
/// 展示总数 / 成功率 / 平均耗时 / 总流量
class SJStatsBar: UIView {
    
    private let stack = UIStackView()
    private let totalItem = StatItem(title: "总数")
    private let rateItem = StatItem(title: "成功率")
    private let avgItem = StatItem(title: "平均耗时")
    private let sizeItem = StatItem(title: "总流量")
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        [totalItem, rateItem, avgItem, sizeItem].forEach { stack.addArrangedSubview($0) }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func update(with logs: [SJLoggerModel]) {
        let total = logs.count
        let success = logs.filter { $0.isSuccess }.count
        let rate = total > 0 ? Int((Double(success) / Double(total) * 100).rounded()) : 0
        let durations = logs.compactMap { $0.duration }
        let avg = durations.isEmpty ? 0 : Int(durations.reduce(0, +) / Double(durations.count))
        let totalSize = logs.reduce(0) { $0 + $1.responseSize }
        
        totalItem.setValue("\(total)", color: .label)
        rateItem.setValue("\(rate)%", color: rate >= 90 ? .systemGreen : (rate >= 60 ? .systemOrange : .systemRed))
        avgItem.setValue("\(avg)ms", color: .label)
        sizeItem.setValue(ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .binary), color: .label)
    }
    
    private class StatItem: UIView {
        private let valueLabel = UILabel()
        private let titleLabel = UILabel()
        init(title: String) {
            super.init(frame: .zero)
            valueLabel.font = .systemFont(ofSize: 15, weight: .bold)
            valueLabel.textColor = .label
            valueLabel.textAlignment = .center
            valueLabel.text = "-"
            titleLabel.font = .systemFont(ofSize: 10)
            titleLabel.textColor = .secondaryLabel
            titleLabel.textAlignment = .center
            titleLabel.text = title
            let v = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
            v.axis = .vertical
            v.spacing = 1
            addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                v.centerXAnchor.constraint(equalTo: centerXAnchor),
                v.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        func setValue(_ text: String, color: UIColor) {
            valueLabel.text = text
            valueLabel.textColor = color
        }
    }
}

// MARK: - 横向分类标签栏
class SJChipsBar: UIView {
    
    var onSelect: ((Int) -> Void)?
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    private var selectedIndex = 0
    
    init(titles: [String]) {
        super.init(frame: .zero)
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        scrollView.addSubview(stack)
        stack.axis = .horizontal
        stack.spacing = 8
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -2),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -12),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -4)
        ])
        for (i, title) in titles.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.tag = i
            btn.layer.cornerRadius = 14
            btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)
            btn.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
            buttons.append(btn)
            stack.addArrangedSubview(btn)
        }
        updateStyles()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    @objc private func tap(_ sender: UIButton) {
        selectedIndex = sender.tag
        updateStyles()
        onSelect?(selectedIndex)
    }
    
    private func updateStyles() {
        for (i, btn) in buttons.enumerated() {
            if i == selectedIndex {
                btn.backgroundColor = SJLoggerConfig.shared.floatingWindowColor
                btn.setTitleColor(.white, for: .normal)
            } else {
                btn.backgroundColor = .secondarySystemBackground
                btn.setTitleColor(.label, for: .normal)
            }
        }
    }
}
