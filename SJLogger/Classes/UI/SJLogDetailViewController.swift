import UIKit

// MARK: - 日志详情视图控制器
/// 显示单个日志的详细信息
public class SJLogDetailViewController: UIViewController {
    
    // MARK: - 属性
    
    private let log: SJLoggerModel
    
    // MARK: - UI组件
    
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.backgroundColor = .systemBackground
        return scroll
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.distribution = .fill
        return stack
    }()
    
    private lazy var copyButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"),
                              style: .plain,
                              target: self,
                              action: #selector(copyLog))
    }()
    
    private lazy var shareButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"),
                              style: .plain,
                              target: self,
                              action: #selector(shareLog))
    }()
    
    // MARK: - 初始化
    
    public init(log: SJLoggerModel) {
        self.log = log
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadLogDetails()
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        title = "日志详情"
        view.backgroundColor = .systemBackground
        
        // 导航栏按钮 - 添加间距适配UINavigation-SXFixSpace
        if needsNavigationBarSpacing() {
            let rightSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            rightSpacer.width = -8
            navigationItem.rightBarButtonItems = [rightSpacer, shareButton, copyButton]
        } else {
            navigationItem.rightBarButtonItems = [shareButton, copyButton]
        }
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    // MARK: - 加载详情
    
    private func loadLogDetails() {
        // 基本信息
        addSection(title: "基本信息", items: [
            ("类型", log.type.rawValue),
            ("URL", log.url),
            ("方法", log.method?.rawValue ?? "-"),
            ("状态码", log.statusCode != nil ? "\(log.statusCode!)" : "-"),
            ("开始时间", formatDate(log.startTime)),
            ("结束时间", log.endTime != nil ? formatDate(log.endTime!) : "-"),
            ("耗时", log.duration != nil ? "\(Int(log.duration!))ms" : "-"),
            ("响应大小", formatBytes(log.responseSize))
        ])
        
        // 错误信息
        if let error = log.error {
            addSection(title: "错误信息", content: error, color: .systemRed)
        }
        
        // 请求头
        if let headers = log.requestHeaders, !headers.isEmpty {
            let headersText = headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            addSection(title: "请求头", content: headersText)
        }
        
        // 请求体
        if let body = log.requestBodyString {
            let formattedBody = formatJSONIfPossible(body)
            addSection(title: "请求体", content: formattedBody, copyable: true, isJSON: body.isJSON)
        }
        
        // 响应头
        if let headers = log.responseHeaders, !headers.isEmpty {
            let headersText = headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            addSection(title: "响应头", content: headersText)
        }
        
        // 响应体
        if let body = log.responseBodyString {
            let formattedBody = formatJSONIfPossible(body)
            addSection(title: "响应体", content: formattedBody, copyable: true, isJSON: body.isJSON)
        }
        
        // TCP信息
        if let tcpInfo = log.tcpInfo {
            addSection(title: "TCP信息", content: tcpInfo)
        }
    }
    
    // MARK: - 添加区块
    
    private func addSection(title: String, items: [(String, String)]) {
        let sectionView = createSectionView(title: title)
        
        for (key, value) in items {
            let itemView = createItemView(key: key, value: value)
            sectionView.addArrangedSubview(itemView)
        }
        
        contentStackView.addArrangedSubview(sectionView)
    }
    
    private func addSection(title: String, content: String, color: UIColor = .label, copyable: Bool = false, isJSON: Bool = false) {
        let sectionView = createSectionView(title: title)
        
        let textView = UITextView()
        textView.text = content
        textView.font = .monospacedSystemFont(ofSize: isJSON ? 11 : 12, weight: .regular)
        textView.textColor = color
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        
        // JSON语法高亮（简单实现）
        if isJSON {
            textView.textColor = .systemGreen
        }
        
        if copyable {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyContent(_:)))
            textView.addGestureRecognizer(tapGesture)
        }
        
        sectionView.addArrangedSubview(textView)
        contentStackView.addArrangedSubview(sectionView)
    }
    
    private func createSectionView(title: String) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        
        stack.addArrangedSubview(titleLabel)
        
        return stack
    }
    
    private func createItemView(key: String, value: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        
        let keyLabel = UILabel()
        keyLabel.text = key
        keyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        keyLabel.textColor = .secondaryLabel
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 13)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0
        
        container.addSubview(keyLabel)
        container.addSubview(valueLabel)
        
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            keyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            keyLabel.widthAnchor.constraint(equalToConstant: 80),
            
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func copyLog() {
        let text = log.generateLogText()
        UIPasteboard.general.string = text
        showToast("已复制到剪贴板")
    }
    
    @objc private func shareLog() {
        let text = log.generateLogText()
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = shareButton
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func copyContent(_ gesture: UITapGestureRecognizer) {
        guard let textView = gesture.view as? UITextView else { return }
        UIPasteboard.general.string = textView.text
        showToast("已复制到剪贴板")
    }
    
    // MARK: - 辅助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    // MARK: - JSON格式化
    
    private func formatJSONIfPossible(_ string: String) -> String {
        // 尝试格式化JSON
        if let prettyJSON = string.prettyJSON {
            return prettyJSON
        }
        return string
    }
    
    /// 检测是否需要添加导航栏间距
    private func needsNavigationBarSpacing() -> Bool {
        guard let navBar = navigationController?.navigationBar else { return false }
        let defaultMargin: CGFloat = 16
        return navBar.layoutMargins.left < defaultMargin || navBar.layoutMargins.right < defaultMargin
    }
}
