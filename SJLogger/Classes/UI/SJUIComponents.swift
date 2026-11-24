import UIKit

// MARK: - 自定义导航栏
/// SJLogger 内部使用的顶部栏，避免宿主工程的 UINavigationBar 全局修改影响布局。
class SJCustomNavigationBar: UIView {
    private let leftStack = UIStackView()
    private let rightStack = UIStackView()
    private let titleLabel = UILabel()
    private let centerContainer = UIView()
    private var customCenterView: UIView?
    private static let iconButtonSize = CGSize(width: 32, height: 44)
    private static let iconPointSize: CGFloat = 18
    
    init(title: String) {
        super.init(frame: .zero)
        setupUI()
        setTitle(title)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func setTitle(_ title: String) {
        titleLabel.text = title
        titleLabel.isHidden = title.isEmpty || customCenterView != nil
    }

    func setCenterView(_ view: UIView?) {
        customCenterView?.removeFromSuperview()
        customCenterView = view
        centerContainer.isHidden = view == nil
        titleLabel.isHidden = view != nil || (titleLabel.text ?? "").isEmpty

        guard let view = view else { return }
        centerContainer.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: centerContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: centerContainer.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor)
        ])
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
        addSubview(centerContainer)
        
        [leftStack, rightStack, titleLabel, centerContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        centerContainer.isHidden = true
        
        let availableCenter = UILayoutGuide()
        addLayoutGuide(availableCenter)
        NSLayoutConstraint.activate([
            availableCenter.leadingAnchor.constraint(equalTo: leftStack.trailingAnchor, constant: 8),
            availableCenter.trailingAnchor.constraint(equalTo: rightStack.leadingAnchor, constant: -8),
            heightAnchor.constraint(equalToConstant: 52),
            
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),

            centerContainer.centerXAnchor.constraint(equalTo: availableCenter.centerXAnchor),
            centerContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 8),
            centerContainer.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),
            centerContainer.heightAnchor.constraint(equalToConstant: 32)
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

    override var intrinsicContentSize: CGSize {
        let size = label.intrinsicContentSize
        return CGSize(width: size.width + hInset * 2, height: size.height)
    }
    
    /// 设置文本与主色（背景为主色淡化）
    func setText(_ text: String, color: UIColor) {
        label.text = text
        label.textColor = color
        backgroundColor = color.withAlphaComponent(0.15)
        isHidden = text.isEmpty
        invalidateIntrinsicContentSize()
    }
    
    /// 实心样式（白字+实色背景）
    func setSolidText(_ text: String, color: UIColor) {
        label.text = text
        label.textColor = .white
        backgroundColor = color
        isHidden = text.isEmpty
        invalidateIntrinsicContentSize()
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

// MARK: - 列表内统计摘要
/// 默认只占一行，点击后展开平均耗时和流量等次要信息。
class SJStatsBar: UIView {
    var onPreferredHeightChange: ((CGFloat) -> Void)?

    private let summaryLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
    private let separator = UIView()
    private var isExpanded = false

    var preferredHeight: CGFloat { isExpanded ? 68 : 44 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        isAccessibilityElement = true
        accessibilityTraits = .button

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 1
        summaryLabel.adjustsFontSizeToFitWidth = true
        summaryLabel.minimumScaleFactor = 0.75

        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .tertiaryLabel
        detailLabel.numberOfLines = 1
        detailLabel.isHidden = true

        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        separator.backgroundColor = .separator

        let labels = UIStackView(arrangedSubviews: [summaryLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 5
        labels.alignment = .leading

        addSubview(labels)
        addSubview(chevron)
        addSubview(separator)
        [labels, chevron, separator].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            labels.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -10),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleExpanded)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(with logs: [SJLoggerModel]) {
        let total = logs.count
        let success = logs.filter { $0.isSuccess }.count
        let failed = logs.filter { $0.isFailure }.count
        let cancelled = logs.filter { $0.isCancelled }.count
        let resolved = success + failed
        let rate = resolved > 0 ? Int((Double(success) / Double(resolved) * 100).rounded()) : 0
        let durations = logs.compactMap { $0.duration }
        let average = durations.isEmpty ? 0 : Int(durations.reduce(0, +) / Double(durations.count))
        let totalSize = logs.reduce(0) { $0 + $1.responseSize }
        let size = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .binary)

        summaryLabel.text = "共 \(total) 条 · 成功 \(success) · 失败 \(failed) · 取消 \(cancelled)"
        detailLabel.text = "成功率 \(rate)% · 平均 \(average)ms · 流量 \(size)"
        accessibilityLabel = "共 \(total) 条，成功 \(success) 条，失败 \(failed) 条，取消 \(cancelled) 条，成功率 \(rate)%，平均耗时 \(average) 毫秒，流量 \(size)"
        accessibilityHint = isExpanded ? "轻点收起统计详情" : "轻点展开统计详情"
    }

    @objc private func toggleExpanded() {
        isExpanded.toggle()
        detailLabel.isHidden = !isExpanded
        chevron.transform = isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
        accessibilityHint = isExpanded ? "轻点收起统计详情" : "轻点展开统计详情"
        onPreferredHeightChange?(preferredHeight)
    }
}

// MARK: - 域名与快捷筛选栏
class SJCompactFilterBar: UIView {
    var onSelect: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let domainButton = UIButton(type: .system)
    private var filterButtons: [UIButton] = []
    private var selectedIndex = 0

    init(titles: [String]) {
        super.init(frame: .zero)
        backgroundColor = .systemBackground

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInsetAdjustmentBehavior = .never

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6

        configureDomainButton()
        stack.addArrangedSubview(domainButton)
        titles.enumerated().forEach { index, title in
            let button = makeFilterButton(title: title, index: index)
            filterButtons.append(button)
            stack.addArrangedSubview(button)
        }

        addSubview(scrollView)
        scrollView.addSubview(stack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -3),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            stack.heightAnchor.constraint(equalToConstant: 34),
            domainButton.widthAnchor.constraint(lessThanOrEqualToConstant: 140)
        ])
        updateStyles()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setDomain(title: String, menu: UIMenu) {
        var configuration = domainButton.configuration ?? .plain()
        configuration.title = "\(title) ⌄"
        domainButton.configuration = configuration
        domainButton.menu = menu
        domainButton.accessibilityLabel = "当前域名，\(title)"
        domainButton.accessibilityHint = "轻点切换域名"
    }

    func setFilterTitles(_ titles: [String]) {
        for (index, title) in titles.enumerated() where index < filterButtons.count {
            filterButtons[index].configuration?.title = title
        }
    }

    func setSelectedIndex(_ index: Int) {
        guard filterButtons.indices.contains(index) else { return }
        selectedIndex = index
        updateStyles()
    }

    private func configureDomainButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "globe")
        configuration.imagePadding = 4
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = .systemFont(ofSize: 13, weight: .medium)
            return result
        }
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        configuration.baseForegroundColor = .label
        domainButton.configuration = configuration
        domainButton.backgroundColor = .secondarySystemBackground
        domainButton.layer.cornerRadius = 14
        domainButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        domainButton.titleLabel?.lineBreakMode = .byTruncatingMiddle
        domainButton.showsMenuAsPrimaryAction = true
        domainButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }

    private func makeFilterButton(title: String, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = .systemFont(ofSize: 13, weight: .medium)
            return result
        }
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.tag = index
        button.layer.cornerRadius = 14
        button.addTarget(self, action: #selector(tapFilter(_:)), for: .touchUpInside)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    @objc private func tapFilter(_ sender: UIButton) {
        selectedIndex = sender.tag
        updateStyles()
        onSelect?(selectedIndex)
    }

    private func updateStyles() {
        for (index, button) in filterButtons.enumerated() {
            if index == selectedIndex {
                button.backgroundColor = SJLoggerConfig.shared.floatingWindowColor
                button.configuration?.baseForegroundColor = .white
            } else {
                button.backgroundColor = .secondarySystemBackground
                button.configuration?.baseForegroundColor = .label
            }
        }
    }
}

// MARK: - 文件附件分享
/// 分享入口统一传入文件 URL，避免系统将日志当作长文本发送。
enum SJLogFileSharing {
    static func present(contents: String, format: SJLogExporter.FileFormat = .text,
                        from presenter: UIViewController, sourceView: UIView,
                        onPresented: (() -> Void)? = nil) {
        guard presenter.presentedViewController == nil else { return }
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try SJLogExporter.writeFile(contents: contents, format: format) }
            DispatchQueue.main.async { [weak presenter, weak sourceView] in
                guard let presenter = presenter, let sourceView = sourceView,
                      presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else { return }
                switch result {
                case .success(let url):
                    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    activity.popoverPresentationController?.sourceView = sourceView
                    activity.popoverPresentationController?.sourceRect = sourceView.bounds
                    activity.completionWithItemsHandler = { [weak presenter] _, _, _, error in
                        guard let presenter = presenter, let error = error else { return }
                        // 等待分享面板退出后再显示失败原因。
                        DispatchQueue.main.async {
                            showError(error, from: presenter)
                        }
                    }
                    presenter.present(activity, animated: true, completion: onPresented)
                case .failure(let error):
                    showError(error, from: presenter)
                }
            }
        }
    }

    private static func showError(_ error: Error, from presenter: UIViewController) {
        guard presenter.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "导出文件失败", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        presenter.present(alert, animated: true)
    }
}
