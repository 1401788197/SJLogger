import UIKit

// MARK: - 日志详情视图控制器
/// 显示单个日志的详细信息
public class SJLogDetailViewController: UIViewController {
    
    // MARK: - 属性
    
    private var log: SJLoggerModel
    private let updatesFromStorage: Bool
    private var refreshGeneration = 0
    
    // MARK: - UI组件
    
    private lazy var customNavigationBar: SJCustomNavigationBar = {
        return SJCustomNavigationBar(title: "日志详情")
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.backgroundColor = .systemBackground
        return scroll
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.distribution = .fill
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }()
    
    private lazy var copyButton: UIButton = {
        return SJCustomNavigationBar.iconButton(systemName: "doc.on.doc",
                                                target: self,
                                                action: #selector(copyLog))
    }()
    
    private lazy var shareButton: UIButton = {
        return SJCustomNavigationBar.iconButton(systemName: "square.and.arrow.up",
                                                target: self,
                                                action: #selector(shareLog))
    }()
    
    private lazy var exportButton: UIButton = {
        return SJCustomNavigationBar.iconButton(systemName: "arrow.down.doc",
                                                target: self,
                                                action: #selector(exportButtonTapped))
    }()
    
    // MARK: - 初始化
    
    public init(log: SJLoggerModel, updatesFromStorage: Bool = true) {
        self.log = log
        self.updatesFromStorage = updatesFromStorage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.tintColor = SJLoggerConfig.shared.floatingWindowColor
        setupUI()
        loadLogDetails()
        if updatesFromStorage {
            NotificationCenter.default.addObserver(self, selector: #selector(refreshLog),
                                                   name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
            refreshLog()
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func refreshLog() {
        refreshGeneration += 1
        let generation = refreshGeneration
        SJLoggerStorage.shared.getLog(byId: log.id) { [weak self] latest in
            guard let self = self, generation == self.refreshGeneration, let latest = latest else { return }
            guard latest.statusCode != self.log.statusCode || latest.endTime != self.log.endTime
                || latest.responseBody != self.log.responseBody || latest.error != self.log.error
                || latest.errorDomain != self.log.errorDomain || latest.errorCode != self.log.errorCode
                || latest.cancellationSource != self.log.cancellationSource
                || latest.requestHeaders != self.log.requestHeaders || latest.responseHeaders != self.log.responseHeaders
                || latest.requestBody != self.log.requestBody else { return }
            let offset = self.scrollView.contentOffset
            self.log = latest
            self.contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.loadLogDetails()
            self.view.layoutIfNeeded()
            self.scrollView.setContentOffset(offset, animated: false)
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        title = "日志详情"
        view.backgroundColor = .systemBackground
        
        customNavigationBar.setLeftButtons([
            SJCustomNavigationBar.iconButton(systemName: "chevron.left", target: self, action: #selector(backAction))
        ])
        copyButton.accessibilityLabel = "复制日志"
        shareButton.accessibilityLabel = "分享日志"
        exportButton.accessibilityLabel = "导出 cURL 或 HAR"
        exportButton.removeTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
        exportButton.showsMenuAsPrimaryAction = true
        exportButton.menu = UIMenu(title: "导出", children: [
            UIAction(title: "复制为 cURL", image: UIImage(systemName: "terminal")) { [weak self] _ in
                guard let self = self else { return }
                UIPasteboard.general.string = SJLogExporter.curl(for: self.log)
                self.showToast("已复制 cURL 命令")
            },
            UIAction(title: "导出 HAR 文件", image: UIImage(systemName: "doc")) { [weak self] _ in
                guard let self = self else { return }
                SJLogFileSharing.present(contents: SJLogExporter.har(for: [self.log]), format: .har,
                                         from: self, sourceView: self.exportButton)
            }
        ])
        customNavigationBar.setRightButtons([shareButton, exportButton, copyButton])
        
        view.addSubview(customNavigationBar)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        customNavigationBar.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            customNavigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
    
    // MARK: - 加载详情
    
    private func loadLogDetails() {
        // HTTP 200 也可能业务失败，优先展示服务端返回的业务结果。
        if let result = log.businessResult {
            addSection(title: result.isSuccess ? "业务成功" : "业务失败",
                       content: "业务码: \(result.code)\n业务说明: \(result.message.isEmpty ? "服务端未提供说明" : result.message)",
                       color: result.isSuccess ? .systemGreen : .systemRed, copyable: true)
        }
        // 基本信息
        addSection(title: "基本信息", items: [
            ("类型", log.type.rawValue),
            ("URL", log.url),
            ("方法", log.method?.rawValue ?? "-"),
            ("HTTP 状态码", log.statusCode != nil ? "\(log.statusCode!)" : "-"),
            ("开始时间", formatDate(log.startTime)),
            ("结束时间", log.endTime != nil ? formatDate(log.endTime!) : "-"),
            ("耗时", log.duration != nil ? "\(Int(log.duration!))ms" : "-"),
            ("响应大小", formatBytes(log.responseSize))
        ])
        
        // 保留诊断信息；取消用中性样式，不当作接口失败。
        var errorDetails: [String] = []
        if let error = log.error { errorDetails.append(error) }
        if let domain = log.errorDomain { errorDetails.append("错误域: \(domain)") }
        if let code = log.errorCode { errorDetails.append("错误码: \(code)") }
        if log.isCancelled {
            errorDetails.append("取消来源: \(log.cancellationSource ?? "未记录")")
            errorDetails.append("具体业务原因未知，可能由调用方或系统取消。")
        }
        if !errorDetails.isEmpty {
            addSection(title: log.isCancelled ? "已取消" : "错误信息",
                       content: errorDetails.joined(separator: "\n"),
                       color: log.isCancelled ? .secondaryLabel : .systemRed)
        }
        
        // 请求头
        if let headers = log.requestHeaders, !headers.isEmpty {
            let headersText = headers.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            addSection(title: "请求头", content: headersText)
        }
        
        // 请求体
        if let body = log.requestBodyString {
            let formattedBody = formatJSONIfPossible(body)
            addSection(title: "请求体", content: formattedBody, copyable: true, isJSON: body.isJSON)
        }
        
        // 响应头
        if let headers = log.responseHeaders, !headers.isEmpty {
            let headersText = headers.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
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
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        
        // JSON语法高亮
        if isJSON {
            textView.attributedText = SJSyntaxHighlighter.highlight(content, fontSize: 12)
        } else {
            textView.text = content
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.textColor = color
        }
        
        textView.isSelectable = true
        if copyable {
            let copy = UIButton(type: .system)
            copy.setTitle("复制\(title)", for: .normal)
            copy.contentHorizontalAlignment = .trailing
            copy.addAction(UIAction { [weak self] _ in
                UIPasteboard.general.string = content
                self?.showToast("已复制\(title)")
            }, for: .touchUpInside)
            sectionView.addArrangedSubview(copy)
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
    
    @objc private func backAction() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func exportButtonTapped() {}

    @objc private func copyLog() {
        let text = log.generateLogText()
        UIPasteboard.general.string = text
        showToast("已复制到剪贴板")
    }
    
    @objc private func shareLog() {
        SJLogFileSharing.present(contents: log.generateLogText(), from: self, sourceView: shareButton)
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
}
