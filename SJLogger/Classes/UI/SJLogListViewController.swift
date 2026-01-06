import UIKit

// MARK: - 日志列表视图控制器
/// 显示所有网络日志的列表界面
public class SJLogListViewController: UIViewController {
    
    // MARK: - UI组件
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(SJLogCell.self, forCellReuseIdentifier: "SJLogCell")
        table.rowHeight = 90
        table.separatorStyle = .none
        table.backgroundColor = .systemGroupedBackground
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        return table
    }()
    
    private lazy var searchBar: UISearchBar = {
        let search = UISearchBar()
        search.delegate = self
        search.placeholder = "搜索URL、方法、内容..."
        search.searchBarStyle = .minimal
        search.backgroundImage = UIImage()
        return search
    }()
    
    private lazy var filterButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
                              style: .plain,
                              target: self,
                              action: #selector(showFilterOptions))
    }()
    
    private lazy var clearButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "trash"),
                              style: .plain,
                              target: self,
                              action: #selector(clearAllLogs))
    }()
    
    private lazy var exportButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"),
                              style: .plain,
                              target: self,
                              action: #selector(exportLogs))
    }()
    
    private lazy var selectButton: UIBarButtonItem = {
        return UIBarButtonItem(title: "选择",
                              style: .plain,
                              target: self,
                              action: #selector(toggleSelectionMode))
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "📭\n\n暂无日志\n开始使用应用后，网络请求将显示在这里"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.isHidden = true
        return label
    }()
    
    // MARK: - 数据
    
    private var allLogs: [SJLoggerModel] = []
    private var filteredLogs: [SJLoggerModel] = []
    private var isSearching = false
    private var currentFilter: LogFilter = .all
    
    // 记住筛选条件
    private static var savedFilter: LogFilter = .all
    private static var savedSearchText: String = ""
    
    // 多选模式
    private var isSelectionMode = false
    private var selectedLogs: Set<String> = [] // 存储选中的log ID
    
    // 动态边距适配
    private var contentInset: UIEdgeInsets {
        // 检测是否有UINavigation-SXFixSpace等导航栏扩展
        let leftInset = navigationController?.navigationBar.layoutMargins.left ?? 16
        let rightInset = navigationController?.navigationBar.layoutMargins.right ?? 16
        return UIEdgeInsets(top: 0, left: max(leftInset - 16, 0), bottom: 0, right: max(rightInset - 16, 0))
    }
    
    // MARK: - 生命周期
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        restoreFilterState()
        loadLogs()
        observeLogUpdates()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 动态调整内边距
        updateContentInsets()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 布局变化时更新内边距
        updateContentInsets()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        title = "Logger"
        view.backgroundColor = .systemBackground
        
        // 导航栏按钮 - 添加固定间距避免UINavigation-SXFixSpace导致的贴边问题
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close,
                                          target: self,
                                          action: #selector(closeAction))
        
        // 检测是否需要添加间距
        if needsNavigationBarSpacing() {
            let leftSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            leftSpacer.width = -8 // 负值向内缩进
            navigationItem.leftBarButtonItems = [leftSpacer, closeButton, selectButton]
            
            let rightSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            rightSpacer.width = -8
            navigationItem.rightBarButtonItems = [rightSpacer, exportButton, clearButton, filterButton]
        } else {
            navigationItem.leftBarButtonItems = [closeButton, selectButton]
            navigationItem.rightBarButtonItems = [exportButton, clearButton, filterButton]
        }
        
        // 添加子视图
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        
        // 布局
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40)
        ])
    }
    
    // MARK: - 数据加载
    
    private func loadLogs() {
        SJLoggerStorage.shared.getAllLogs { [weak self] logs in
            self?.allLogs = logs
            self?.applyFilter()
        }
    }
    
    private func observeLogUpdates() {
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(logsDidUpdate),
                                              name: SJLoggerStorage.logsDidUpdateNotification,
                                              object: nil)
    }
    
    @objc private func logsDidUpdate() {
        loadLogs()
    }
    
    private func applyFilter() {
        var logs = allLogs
        
        // 应用过滤器
        switch currentFilter {
        case .all:
            break
        case .success:
            logs = logs.filter { $0.isSuccess }
        case .failed:
            logs = logs.filter { !$0.isSuccess || $0.error != nil }
        case .httpOrHttps:
            logs = logs.filter { $0.type == .http || $0.type == .https }
        case .type(let type):
            logs = logs.filter { $0.type == type }
        }
        
        filteredLogs = logs
        updateUI()
        
        // 保存筛选条件
        Self.savedFilter = currentFilter
    }
    
    // MARK: - 状态恢复
    
    private func restoreFilterState() {
        // 恢复筛选条件
        currentFilter = Self.savedFilter
        
        // 恢复搜索文本
        if !Self.savedSearchText.isEmpty {
            searchBar.text = Self.savedSearchText
            isSearching = true
        }
    }
    
    // MARK: - 动态边距适配
    
    private func updateContentInsets() {
        let inset = contentInset
        
        // 更新tableView的内边距
        if inset.left > 0 || inset.right > 0 {
            tableView.contentInset = UIEdgeInsets(top: 0, left: inset.left, bottom: 0, right: inset.right)
            tableView.scrollIndicatorInsets = tableView.contentInset
        }
    }
    
    /// 检测是否需要添加导航栏间距
    /// 当使用UINavigation-SXFixSpace等库时，导航栏按钮会贴边，需要手动调整
    private func needsNavigationBarSpacing() -> Bool {
        // 检测导航栏的layoutMargins是否被修改
        guard let navBar = navigationController?.navigationBar else { return false }
        
        // 如果左边距小于默认值（通常是16），说明被第三方库修改了
        let defaultMargin: CGFloat = 16
        return navBar.layoutMargins.left < defaultMargin || navBar.layoutMargins.right < defaultMargin
    }
    
    private func updateUI() {
        emptyLabel.isHidden = !filteredLogs.isEmpty
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func closeAction() {
        dismiss(animated: true)
    }
    
    @objc private func showFilterOptions() {
        let alert = UIAlertController(title: "过滤日志", message: nil, preferredStyle: .actionSheet)
        
        // 添加当前选中标记
        let addAction: (String, LogFilter) -> Void = { [weak self] title, filter in
            guard let self = self else { return }
            let isSelected = self.isFilterEqual(self.currentFilter, filter)
            let actionTitle = isSelected ? "✓ \(title)" : title
            let action = UIAlertAction(title: actionTitle, style: .default) { _ in
                self.currentFilter = filter
                self.applyFilter()
            }
            alert.addAction(action)
        }
        
        addAction("全部", .all)
        addAction("成功请求", .success)
        addAction("失败请求", .failed)
        addAction("HTTP/HTTPS", .httpOrHttps)
        addAction("WebSocket", .type(.websocket))
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = filterButton
        }
        
        present(alert, animated: true)
    }
    
    private func isFilterEqual(_ filter1: LogFilter, _ filter2: LogFilter) -> Bool {
        switch (filter1, filter2) {
        case (.all, .all), (.success, .success), (.failed, .failed), (.httpOrHttps, .httpOrHttps):
            return true
        case (.type(let type1), .type(let type2)):
            return type1 == type2
        default:
            return false
        }
    }
    
    @objc private func clearAllLogs() {
        let alert = UIAlertController(title: "清除所有日志",
                                     message: "确定要清除所有日志吗？此操作不可恢复。",
                                     preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { _ in
            SJLoggerStorage.shared.clearAllLogs()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func toggleSelectionMode() {
        isSelectionMode.toggle()
        selectedLogs.removeAll()
        
        if isSelectionMode {
            selectButton.title = "取消"
            tableView.allowsMultipleSelection = true
            // 进入编辑模式，停止监听日志更新
            NotificationCenter.default.removeObserver(self, name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
        } else {
            selectButton.title = "选择"
            tableView.allowsMultipleSelection = false
            // 退出编辑模式，恢复监听日志更新
            observeLogUpdates()
            // 刷新数据
            loadLogs()
        }
        
        tableView.reloadData()
    }
    
    @objc private func exportLogs() {
        // 如果在编辑模式，导出选中的日志
        if isSelectionMode {
            guard !selectedLogs.isEmpty else {
                let alert = UIAlertController(title: "提示", message: "请至少选择一条日志", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                present(alert, animated: true)
                return
            }
            
            // 获取选中的日志
            let logsToExport = filteredLogs.filter { selectedLogs.contains($0.id) }
            performExport(logsToExport)
            
            // 退出编辑模式
            toggleSelectionMode()
        } else {
            // 普通模式，导出全部
            performExport(filteredLogs)
        }
    }
    
    private func performExport(_ logs: [SJLoggerModel]) {
        guard !logs.isEmpty else {
            let alert = UIAlertController(title: "提示", message: "没有日志可导出", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        // 生成日志文本
        var text = "========== SJLogger 日志导出 ==========\n"
        text += "导出时间: \(formatDate(Date()))\n"
        text += "日志数量: \(logs.count)\n"
        text += "========================================\n\n"
        
        for (index, log) in logs.enumerated() {
            text += "[\(index + 1)/\(logs.count)]\n"
            text += log.generateLogText()
            text += "\n========================================\n\n"
        }
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = exportButton
        }
        
        present(activityVC, animated: true)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - UITableViewDataSource
extension SJLogListViewController: UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredLogs.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SJLogCell", for: indexPath) as! SJLogCell
        let log = filteredLogs[indexPath.row]
        
        // 配置Cell，传入选中状态和是否显示勾选图标
        let isSelected = selectedLogs.contains(log.id)
        cell.configure(with: log, isSelected: isSelected, showCheckmark: isSelectionMode)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SJLogListViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let log = filteredLogs[indexPath.row]
        
        if isSelectionMode {
            // 多选模式：切换选中状态
            if selectedLogs.contains(log.id) {
                selectedLogs.remove(log.id)
            } else {
                selectedLogs.insert(log.id)
            }
            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            // 普通模式：打开详情
            tableView.deselectRow(at: indexPath, animated: true)
            let detailVC = SJLogDetailViewController(log: log)
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let log = filteredLogs[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { _, _, completion in
            SJLoggerStorage.shared.removeLog(byId: log.id)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        let shareAction = UIContextualAction(style: .normal, title: "分享") { [weak self] _, _, completion in
            self?.shareLog(log)
            completion(true)
        }
        shareAction.backgroundColor = .systemBlue
        shareAction.image = UIImage(systemName: "square.and.arrow.up")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, shareAction])
    }
    
    private func shareLog(_ log: SJLoggerModel) {
        let text = log.generateLogText()
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension SJLogListViewController: UISearchBarDelegate {
    
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // 保存搜索文本
        Self.savedSearchText = searchText
        
        if searchText.isEmpty {
            isSearching = false
            applyFilter()
        } else {
            isSearching = true
            SJLoggerStorage.shared.searchLogs(keyword: searchText) { [weak self] logs in
                self?.filteredLogs = logs
                self?.updateUI()
            }
        }
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // 点击搜索按钮时收起键盘
        searchBar.resignFirstResponder()
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        isSearching = false
        applyFilter()
    }
}

// MARK: - 过滤器枚举
enum LogFilter {
    case all
    case success
    case failed
    case httpOrHttps
    case type(SJLogType)
}
