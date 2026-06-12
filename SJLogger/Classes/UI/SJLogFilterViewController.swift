import UIKit

// MARK: - 高级筛选视图控制器
/// 组合筛选：类型 / 方法 / 状态码段 / 慢请求 / 仅失败
public class SJLogFilterViewController: UIViewController {
    
    private var query: SJLogQuery
    public var onApply: ((SJLogQuery) -> Void)?
    
    private lazy var customNavigationBar: SJCustomNavigationBar = {
        return SJCustomNavigationBar(title: "高级筛选")
    }()
    private lazy var resetButton: UIButton = {
        return SJCustomNavigationBar.textButton(title: "重置", target: self, action: #selector(reset))
    }()
    private lazy var applyButton: UIButton = {
        return SJCustomNavigationBar.textButton(title: "应用", target: self, action: #selector(apply))
    }()
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    
    private let allTypes: [SJLogType] = [.http, .https, .websocket, .tcp, .udp]
    private let allMethods: [SJHTTPMethod] = [.get, .post, .put, .delete, .patch]
    private let allBuckets: [SJStatusBucket] = SJStatusBucket.allCases
    
    private var typeButtons: [SJLogType: UIButton] = [:]
    private var methodButtons: [SJHTTPMethod: UIButton] = [:]
    private var bucketButtons: [SJStatusBucket: UIButton] = [:]
    private var onlyFailedSwitch = UISwitch()
    private var slowSwitch = UISwitch()
    private var slowValueLabel = UILabel()
    
    public init(query: SJLogQuery) {
        self.query = query
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "高级筛选"
        view.backgroundColor = .systemGroupedBackground
        customNavigationBar.setLeftButtons([resetButton])
        customNavigationBar.setRightButtons([applyButton])
        setupLayout()
        buildSections()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func setupLayout() {
        view.addSubview(customNavigationBar)
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        stack.axis = .vertical
        stack.spacing = 20
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        customNavigationBar.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customNavigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func buildSections() {
        // 类型
        stack.addArrangedSubview(makeSection(title: "类型", buttons: allTypes.map { type in
            let btn = makeChip(title: type.rawValue, selected: query.types.contains(type))
            typeButtons[type] = btn
            btn.addAction(UIAction { [weak self] _ in
                self?.toggleType(type, button: btn)
            }, for: .touchUpInside)
            return btn
        }))
        
        // 方法
        stack.addArrangedSubview(makeSection(title: "请求方法", buttons: allMethods.map { method in
            let btn = makeChip(title: method.rawValue, selected: query.methods.contains(method))
            methodButtons[method] = btn
            btn.addAction(UIAction { [weak self] _ in
                self?.toggleMethod(method, button: btn)
            }, for: .touchUpInside)
            return btn
        }))
        
        // 状态码段
        stack.addArrangedSubview(makeSection(title: "状态码", buttons: allBuckets.map { bucket in
            let btn = makeChip(title: bucket.rawValue, selected: query.statusBuckets.contains(bucket))
            bucketButtons[bucket] = btn
            btn.addAction(UIAction { [weak self] _ in
                self?.toggleBucket(bucket, button: btn)
            }, for: .touchUpInside)
            return btn
        }))
        
        // 仅失败
        onlyFailedSwitch.isOn = query.onlyFailed
        onlyFailedSwitch.addTarget(self, action: #selector(onlyFailedChanged), for: .valueChanged)
        stack.addArrangedSubview(makeSwitchRow(title: "仅显示失败请求", control: onlyFailedSwitch))
        
        // 慢请求
        slowSwitch.isOn = query.minDurationMs != nil
        slowSwitch.addTarget(self, action: #selector(slowChanged), for: .valueChanged)
        let threshold = query.minDurationMs ?? SJLoggerConfig.shared.slowRequestThresholdMs
        slowValueLabel.text = "≥ \(Int(threshold))ms"
        slowValueLabel.font = .systemFont(ofSize: 13)
        slowValueLabel.textColor = .secondaryLabel
        let slowRow = makeSwitchRow(title: "仅显示慢请求", control: slowSwitch)
        if let inner = slowRow.arrangedSubviews.first as? UIStackView {
            inner.insertArrangedSubview(slowValueLabel, at: 1)
        }
        stack.addArrangedSubview(slowRow)
    }
    
    // MARK: - 交互
    
    private func toggleType(_ type: SJLogType, button: UIButton) {
        let selected = !query.types.contains(type)
        if selected { query.types.insert(type) } else { query.types.remove(type) }
        styleChip(button, selected: selected)
    }
    
    private func toggleMethod(_ method: SJHTTPMethod, button: UIButton) {
        let selected = !query.methods.contains(method)
        if selected { query.methods.insert(method) } else { query.methods.remove(method) }
        styleChip(button, selected: selected)
    }
    
    private func toggleBucket(_ bucket: SJStatusBucket, button: UIButton) {
        let selected = !query.statusBuckets.contains(bucket)
        if selected { query.statusBuckets.insert(bucket) } else { query.statusBuckets.remove(bucket) }
        styleChip(button, selected: selected)
    }
    
    @objc private func onlyFailedChanged() { query.onlyFailed = onlyFailedSwitch.isOn }
    
    @objc private func slowChanged() {
        if slowSwitch.isOn {
            query.minDurationMs = SJLoggerConfig.shared.slowRequestThresholdMs
            slowValueLabel.text = "≥ \(Int(SJLoggerConfig.shared.slowRequestThresholdMs))ms"
        } else {
            query.minDurationMs = nil
        }
    }
    
    @objc private func reset() {
        let path = query.path
        query = SJLogQuery()
        query.path = path
        dismiss(animated: true) { [weak self] in
            self?.onApply?(self!.query)
        }
    }
    
    @objc private func apply() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.onApply?(self.query)
        }
    }
    
    // MARK: - 构建辅助
    
    private func makeSection(title: String, buttons: [UIButton]) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        
        let flow = SJFlowLayoutView()
        buttons.forEach { flow.addItem($0) }
        
        let v = UIStackView(arrangedSubviews: [titleLabel, flow])
        v.axis = .vertical
        v.spacing = 10
        return v
    }
    
    private func makeChip(title: String, selected: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        btn.layer.cornerRadius = 15
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        styleChip(btn, selected: selected)
        return btn
    }
    
    private func styleChip(_ btn: UIButton, selected: Bool) {
        if selected {
            btn.backgroundColor = SJLoggerConfig.shared.floatingWindowColor
            btn.setTitleColor(.white, for: .normal)
        } else {
            btn.backgroundColor = .secondarySystemGroupedBackground
            btn.setTitleColor(.label, for: .normal)
        }
    }
    
    private func makeSwitchRow(title: String, control: UISwitch) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, spacer, control])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        let container = UIStackView(arrangedSubviews: [row])
        container.axis = .vertical
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 10
        return container
    }
}

// MARK: - 简单流式布局容器
/// 让chip按钮自动换行排列
class SJFlowLayoutView: UIView {
    private var items: [UIView] = []
    private let hSpacing: CGFloat = 8
    private let vSpacing: CGFloat = 8
    
    func addItem(_ view: UIView) {
        items.append(view)
        addSubview(view)
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }
    
    private var lastLayoutWidth: CGFloat = -1
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout(width: bounds.width, apply: true)
        if bounds.width != lastLayoutWidth {
            lastLayoutWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let w = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 32
        return CGSize(width: UIView.noIntrinsicMetric, height: layout(width: w, apply: false))
    }
    
    @discardableResult
    private func layout(width: CGFloat, apply: Bool) -> CGFloat {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for item in items {
            let size = item.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + vSpacing
                rowHeight = 0
            }
            if apply {
                item.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            }
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
        }
        return y + rowHeight
    }
}
