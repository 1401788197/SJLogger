import UIKit

// MARK: - 日志列表视图控制器
/// 显示所有网络日志的列表界面
public class SJLogListViewController: UIViewController {
    
    // MARK: - UI组件
    
    private lazy var customNavigationBar: SJCustomNavigationBar = {
        return SJCustomNavigationBar(title: listTitle)
    }()
    
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
    
    private lazy var statsBar: SJStatsBar = {
        return SJStatsBar()
    }()
    
    private lazy var segmentedControl: UISegmentedControl = {
        let seg = UISegmentedControl(items: ["请求", "接口"])
        seg.selectedSegmentIndex = 0
        seg.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        return seg
    }()
    
    private lazy var chipsBar: SJChipsBar = {
        let bar = SJChipsBar(titles: ["全部", "成功", "失败", "HTTP", "WebSocket"])
        bar.onSelect = { [weak self] index in
            self?.quickFilter = SJQuickFilter(rawValue: index) ?? .all
            self?.applyQuery(reload: true)
        }
        return bar
    }()
    
    private lazy var newLogsBanner: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = SJLoggerConfig.shared.floatingWindowColor
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        btn.layer.cornerRadius = 14
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 4
        btn.layer.shadowOpacity = 0.2
        btn.isHidden = true
        btn.addTarget(self, action: #selector(applyPendingLogs), for: .touchUpInside)
        return btn
    }()
    
    private lazy var filterButton: UIButton = {
        return SJCustomNavigationBar.iconButton(systemName: "line.3.horizontal.decrease.circle",
                                                target: self,
                                                action: #selector(showFilterOptions))
    }()
    
    private lazy var liveButton: UIButton = {
        return SJCustomNavigationBar.iconButton(systemName: "pause.circle",
                                                target: self,
                                                action: #selector(toggleRefreshMode))
    }()
    
    private lazy var clearButton: UIButton = {
        return SJCustomNavigationBar.iconButton(systemName: "trash",
                                                target: self,
                                                action: #selector(clearCurrentLogs))
    }()
    
    private lazy var exportButton: UIButton = {
        return SJCustomNavigationBar.iconButton(systemName: "square.and.arrow.up",
                                                target: self,
                                                action: #selector(exportLogs))
    }()
    
    private lazy var settingsButton: UIButton = {
        return SJCustomNavigationBar.iconButton(systemName: "gearshape",
                                                target: self,
                                                action: #selector(showSettings))
    }()
    
    private lazy var selectButton: UIButton = {
        return SJCustomNavigationBar.textButton(title: "选择",
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
    
    /// 接口分组子控制器（仅在「接口」分段显示）
    private lazy var endpointsVC: SJEndpointListViewController = {
        let vc = SJEndpointListViewController()
        vc.onSelectPath = { [weak self] path in
            let detail = SJLogListViewController(fixedPath: path)
            self?.navigationController?.pushViewController(detail, animated: true)
        }
        return vc
    }()
    
    // MARK: - 数据
    
    /// 固定路径模式（从接口分组下钻进来时设置），非nil时只看该接口
    private let fixedPath: String?
    private let snapshotLogs: [SJLoggerModel]?
    private let titleOverride: String?
    
    private var allLogs: [SJLoggerModel] = []
    private var filteredLogs: [SJLoggerModel] = []
    
    /// 高级筛选条件
    private var query = SJLogQuery()
    /// 快捷分类
    private var quickFilter: SJQuickFilter = .all
    
    /// 刷新模式（动态/固定）
    private var refreshMode: SJRefreshMode = SJLoggerConfig.shared.defaultRefreshMode
    /// 固定模式下暂存的新日志数量
    private var pendingCount = 0
    
    // 记住筛选条件
    private static var savedSearchText: String = ""
    
    // 多选模式
    private var isSelectionMode = false
    private var selectedLogs: Set<String> = [] // 存储选中的log ID
    
    private var listTitle: String {
        return titleOverride ?? fixedPath ?? "Logger"
    }
    
    private var isSnapshotMode: Bool {
        return snapshotLogs != nil
    }
    
    // MARK: - 初始化
    
    /// - Parameter fixedPath: 若指定，则只展示该接口路径下的请求（隐藏分段控件）
    public init(fixedPath: String? = nil) {
        self.fixedPath = fixedPath
        self.snapshotLogs = nil
        self.titleOverride = nil
        if fixedPath != nil {
            self.query.path = fixedPath
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    public init(title: String, logs: [SJLoggerModel]) {
        self.fixedPath = nil
        self.snapshotLogs = logs
        self.titleOverride = title
        self.refreshMode = .frozen
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.fixedPath = nil
        self.snapshotLogs = nil
        self.titleOverride = nil
        super.init(coder: coder)
    }
    
    // 动态边距适配
    private var contentInset: UIEdgeInsets {
        return .zero
    }
    
    // MARK: - 生命周期
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        restoreFilterState()
        loadLogs()
        if !isSnapshotMode {
            observeLogUpdates()
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        configureCustomNavigationBar()
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
        title = listTitle
        view.backgroundColor = .systemBackground
        
        configureCustomNavigationBar()
        
        let hidesSegments = fixedPath != nil || isSnapshotMode
        let hidesStats = fixedPath != nil
        segmentedControl.isHidden = hidesSegments
        statsBar.isHidden = hidesStats
        
        // 添加子视图
        view.addSubview(customNavigationBar)
        view.addSubview(statsBar)
        view.addSubview(segmentedControl)
        view.addSubview(chipsBar)
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        view.addSubview(newLogsBanner)
        
        [customNavigationBar, statsBar, segmentedControl, chipsBar, searchBar, tableView, emptyLabel, newLogsBanner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        let topGuide = customNavigationBar.bottomAnchor
        let statsHeight: CGFloat = hidesStats ? 0 : 44
        let segmentTopAnchor = hidesStats ? topGuide : statsBar.bottomAnchor
        let contentTopAnchor = hidesSegments ? segmentTopAnchor : segmentedControl.bottomAnchor
        
        NSLayoutConstraint.activate([
            customNavigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            statsBar.topAnchor.constraint(equalTo: topGuide),
            statsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statsBar.heightAnchor.constraint(equalToConstant: statsHeight),
            
            segmentedControl.topAnchor.constraint(equalTo: segmentTopAnchor, constant: hidesSegments ? 0 : 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: hidesSegments ? 0 : 30),
            
            chipsBar.topAnchor.constraint(equalTo: contentTopAnchor, constant: 8),
            chipsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chipsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chipsBar.heightAnchor.constraint(equalToConstant: 34),
            
            searchBar.topAnchor.constraint(equalTo: chipsBar.bottomAnchor, constant: 4),
            searchBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            
            newLogsBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newLogsBanner.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            newLogsBanner.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        updateLiveButton()
    }
    
    private func configureCustomNavigationBar() {
        customNavigationBar.setTitle(shouldHideRootTitle ? "" : listTitle)
        let isPushed = navigationController?.viewControllers.first !== self
        let closeButton = SJCustomNavigationBar.iconButton(systemName: isPushed ? "chevron.left" : "xmark",
                                                           target: self,
                                                           action: isPushed ? #selector(backAction) : #selector(closeAction))
        
        var leftItems: [UIButton] = [closeButton]
        var rightItems: [UIButton] = isSnapshotMode ? [filterButton, exportButton] : [liveButton, filterButton, exportButton]
        
        if fixedPath == nil && !isSnapshotMode {
            leftItems.append(selectButton)
            rightItems.append(contentsOf: [clearButton, settingsButton])
        }
        
        customNavigationBar.setLeftButtons(leftItems)
        customNavigationBar.setRightButtons(rightItems)
    }
    
    private var shouldHideRootTitle: Bool {
        return fixedPath == nil && !isSnapshotMode
    }
    
    // MARK: - 数据加载
    
    private func loadLogs() {
        if let snapshotLogs = snapshotLogs {
            allLogs = snapshotLogs
            applyQuery(reload: true)
            updateStats()
            return
        }
        
        SJLoggerStorage.shared.getAllLogs { [weak self] logs in
            guard let self = self else { return }
            self.allLogs = logs
            self.applyQuery(reload: true)
            self.updateStats()
        }
    }
    
    private func observeLogUpdates() {
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(logsDidUpdate),
                                              name: SJLoggerStorage.logsDidUpdateNotification,
                                              object: nil)
    }
    
    @objc private func logsDidUpdate() {
        // 固定模式：不打断当前查看，只累计提示
        if refreshMode == .frozen && !isSelectionMode {
            SJLoggerStorage.shared.getAllLogs { [weak self] logs in
                guard let self = self else { return }
                let newCount = max(0, logs.count - self.allLogs.count)
                if newCount > 0 {
                    self.pendingCount += newCount
                    self.allLogs = logs  // 后台更新数据源，但不刷新可见列表
                    self.updateNewLogsBanner()
                    self.updateStats()
                }
            }
            return
        }
        // 动态模式：实时刷新
        loadLogs()
    }
    
    /// 合并当前query+快捷分类，刷新展示
    private func applyQuery(reload: Bool) {
        var q = query
        // 合并快捷分类
        switch quickFilter {
        case .all: break
        case .success: q.statusBuckets.insert(.success)
        case .failed: q.onlyFailed = true
        case .http: q.types.formUnion([.http, .https])
        case .websocket: q.types.insert(.websocket)
        }
        filteredLogs = q.apply(to: allLogs)
        pendingCount = 0
        updateNewLogsBanner()
        if reload { updateUI() }
        updateFilterBadge()
    }
    
    // MARK: - 状态恢复
    
    private func restoreFilterState() {
        if fixedPath == nil, !isSnapshotMode, !Self.savedSearchText.isEmpty {
            searchBar.text = Self.savedSearchText
            query.keyword = Self.savedSearchText
        }
    }
    
    // MARK: - 统计 / 提示条 / Live按钮
    
    private func updateStats() {
        guard fixedPath == nil else { return }
        statsBar.update(with: allLogs)
    }
    
    private func updateNewLogsBanner() {
        if pendingCount > 0 && refreshMode == .frozen {
            newLogsBanner.isHidden = false
            newLogsBanner.setTitle("  ↑ \(pendingCount) 条新请求  ", for: .normal)
        } else {
            newLogsBanner.isHidden = true
        }
    }
    
    private func updateLiveButton() {
        if refreshMode == .live {
            SJCustomNavigationBar.setIcon("pause.circle", for: liveButton, color: .systemGreen)
        } else {
            SJCustomNavigationBar.setIcon("play.circle.fill", for: liveButton, color: .systemOrange)
        }
    }
    
    private func updateFilterBadge() {
        let imageName = query.hasAdvancedFilter
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        SJCustomNavigationBar.setIcon(imageName, for: filterButton)
    }
    
    @objc private func applyPendingLogs() {
        pendingCount = 0
        updateNewLogsBanner()
        applyQuery(reload: true)
        if !filteredLogs.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }
    
    @objc private func toggleRefreshMode() {
        refreshMode = (refreshMode == .live) ? .frozen : .live
        updateLiveButton()
        if refreshMode == .live {
            applyPendingLogs()
        }
        let msg = refreshMode == .live ? "动态模式：新请求实时显示" : "固定模式：新请求暂存，不打断查看"
        showToast(msg)
    }
    
    @objc private func segmentChanged() {
        let showEndpoints = segmentedControl.selectedSegmentIndex == 1
        chipsBar.isHidden = showEndpoints
        if showEndpoints {
            addChild(endpointsVC)
            endpointsVC.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(endpointsVC.view)
            NSLayoutConstraint.activate([
                endpointsVC.view.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
                endpointsVC.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                endpointsVC.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                endpointsVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            endpointsVC.didMove(toParent: self)
            endpointsVC.setKeyword(searchBar.text ?? "")
        } else {
            endpointsVC.willMove(toParent: nil)
            endpointsVC.view.removeFromSuperview()
            endpointsVC.removeFromParent()
        }
    }
    
    @objc private func showSettings() {
        let vc = SJLoggerSettingsViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        present(nav, animated: true)
    }
    
    private func showToast(_ message: String) {
        let label = PaddingLabel()
        label.text = message
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.font = .systemFont(ofSize: 13)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
        UIView.animate(withDuration: 0.2, animations: { label.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.4) { label.alpha = 0 } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }
    
    // MARK: - 动态边距适配
    
    private func updateContentInsets() {
        let inset = contentInset
        tableView.contentInset = UIEdgeInsets(top: 8,
                                              left: inset.left,
                                              bottom: 8,
                                              right: inset.right)
        tableView.scrollIndicatorInsets = tableView.contentInset
    }
    
    private func updateUI() {
        emptyLabel.isHidden = !filteredLogs.isEmpty
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func closeAction() {
        dismiss(animated: true)
    }
    
    @objc private func backAction() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func showFilterOptions() {
        let vc = SJLogFilterViewController(query: query)
        vc.onApply = { [weak self] newQuery in
            guard let self = self else { return }
            var q = newQuery
            // 固定路径模式下强制保留path
            if let fp = self.fixedPath { q.path = fp }
            self.query = q
            self.applyQuery(reload: true)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        present(nav, animated: true)
    }
    
    @objc private func clearCurrentLogs() {
        let alert = UIAlertController(title: "清除当前日志",
                                     message: "确定要清除当前显示的内存日志吗？持久化日志不会被清除。",
                                     preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { _ in
            SJLoggerStorage.shared.clearCurrentLogs()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func toggleSelectionMode() {
        isSelectionMode.toggle()
        selectedLogs.removeAll()
        
        if isSelectionMode {
            selectButton.setTitle("取消", for: .normal)
            tableView.allowsMultipleSelection = true
            // 进入编辑模式，停止监听日志更新
            NotificationCenter.default.removeObserver(self, name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
        } else {
            selectButton.setTitle("选择", for: .normal)
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
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
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
        Self.savedSearchText = searchText
        query.keyword = searchText
        applyQuery(reload: true)
        // 接口分组同步搜索
        if segmentedControl.selectedSegmentIndex == 1 {
            endpointsVC.setKeyword(searchText)
        }
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        query.keyword = ""
        applyQuery(reload: true)
    }
}

// MARK: - 滚动自动固定
extension SJLogListViewController {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 用户开始浏览历史时，自动切到固定模式，避免被新日志打断
        guard SJLoggerConfig.shared.autoFreezeOnInteraction,
              refreshMode == .live,
              scrollView.contentOffset.y > 20 else { return }
        refreshMode = .frozen
        updateLiveButton()
    }
}

// MARK: - 快捷分类
enum SJQuickFilter: Int {
    case all = 0
    case success = 1
    case failed = 2
    case http = 3
    case websocket = 4
}
