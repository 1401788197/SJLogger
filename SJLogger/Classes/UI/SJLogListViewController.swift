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
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.separatorStyle = .none
        table.backgroundColor = .systemGroupedBackground
        table.keyboardDismissMode = .onDrag
        table.alwaysBounceVertical = true
        table.accessibilityIdentifier = "logger.requests"
        table.refreshControl = refreshControl
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        return table
    }()
    
    private lazy var searchBar: UISearchBar = {
        let search = UISearchBar()
        search.delegate = self
        search.placeholder = "搜索 URL、方法、Header、内容"
        search.searchBarStyle = .minimal
        search.backgroundImage = UIImage()
        search.setShowsCancelButton(true, animated: false)
        return search
    }()

    private let secondaryToolbar = UIView()
    private let statusToolbar = UIStackView()
    private let statusLabel = UILabel()
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshNow), for: .valueChanged)
        return control
    }()
    private lazy var refreshButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("刷新", for: .normal)
        button.addTarget(self, action: #selector(refreshNow), for: .touchUpInside)
        return button
    }()
    private lazy var resetFiltersButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重置筛选", for: .normal)
        button.accessibilityIdentifier = "logger.resetFilters"
        button.addTarget(self, action: #selector(resetFilters), for: .touchUpInside)
        return button
    }()
    private lazy var emptyState: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [emptyLabel, emptyActionButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.isHidden = true
        return stack
    }()
    private lazy var emptyActionButton: UIButton = {
        let button = UIButton(type: .system)
        button.configuration = .tinted()
        button.addTarget(self, action: #selector(emptyAction), for: .touchUpInside)
        return button
    }()
    
    private lazy var statsBar: SJStatsBar = {
        return SJStatsBar()
    }()
    
    private lazy var segmentedControl: UISegmentedControl = {
        let seg = UISegmentedControl(items: ["请求", "接口"])
        seg.selectedSegmentIndex = 0
        seg.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        let preferredWidth = seg.widthAnchor.constraint(equalToConstant: 168)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true
        return seg
    }()
    
    private lazy var compactFilterBar: SJCompactFilterBar = {
        let bar = SJCompactFilterBar(titles: ["全部", "失败", "慢请求"])
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
        let button = SJCustomNavigationBar.iconButton(systemName: "line.3.horizontal.decrease",
                                                target: self,
                                                action: #selector(showFilterOptions))
        button.accessibilityLabel = "筛选"
        return button
    }()
    
    private lazy var searchButton: UIButton = {
        let button = SJCustomNavigationBar.iconButton(systemName: "magnifyingglass",
                                                      target: self,
                                                      action: #selector(toggleSearch))
        button.accessibilityLabel = "搜索"
        return button
    }()
    
    private lazy var moreButton: UIButton = {
        let button = SJCustomNavigationBar.iconButton(systemName: "ellipsis",
                                                      target: self,
                                                      action: #selector(showMoreMenu))
        button.accessibilityLabel = "更多操作"
        button.showsMenuAsPrimaryAction = true
        return button
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "正在加载日志…"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.isHidden = false
        return label
    }()
    
    /// 接口分组子控制器（仅在「接口」分段显示）
    private lazy var endpointsVC: SJEndpointListViewController = {
        let vc = SJEndpointListViewController()
        vc.usesExternalData = true
        vc.onRefresh = { [weak self] in self?.refreshNow() }
        vc.onResetFilters = { [weak self] in self?.resetFilters() }
        vc.onSelectEndpoint = { [weak self] path, host in
            let detail = SJLogListViewController(fixedPath: path, host: host.isEmpty ? self?.selectedHost : host)
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
    /// 两页、统计和导出共用的已展示快照。
    private var displayedLogs: [SJLoggerModel] = []
    private var hasLoadedLogs = false
    private var reloadGeneration = 0
    private var shouldRevealPending = false
    private var scheduledReload: DispatchWorkItem?
    
    /// 高级筛选条件
    private var query = SJLogQuery()
    /// 快捷分类
    private var quickFilter: SJQuickFilter = .all
    /// nil 表示全部域名。
    private var selectedHost: String?
    
    /// 刷新模式（动态/固定）
    private var refreshMode: SJRefreshMode = SJLoggerConfig.shared.defaultRefreshMode
    /// 固定模式下暂存的新日志数量
    private var pendingCount = 0

    // 多选模式
    private var isSelectionMode = false
    private var selectedLogs: Set<String> = [] // 存储选中的log ID
    private var isSearchVisible = false
    private var isSecondaryToolbarCollapsed = false
    private var secondaryToolbarHeightConstraint: NSLayoutConstraint?
    
    private var listTitle: String {
        return titleOverride ?? fixedPath ?? "Logger"
    }
    
    private var isSnapshotMode: Bool {
        return snapshotLogs != nil
    }
    
    // MARK: - 初始化
    
    /// - Parameter fixedPath: 若指定，则只展示该接口路径下的请求（隐藏分段控件）
    public init(fixedPath: String? = nil, host: String? = nil) {
        self.selectedHost = host
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
        view.tintColor = SJLoggerConfig.shared.floatingWindowColor
        setupUI()
        if !isSnapshotMode {
            observeLogUpdates()
            NotificationCenter.default.addObserver(self, selector: #selector(logsDidUpdate),
                                                   name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        loadLogs()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        configureCustomNavigationBar()
        updateContentInsets()
        if hasLoadedLogs && !isSnapshotMode { loadLogs() }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContentInsets()
        updateStatsHeaderFrame()
    }
    
    deinit {
        scheduledReload?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        title = listTitle
        view.backgroundColor = .systemBackground

        configureCustomNavigationBar()

        secondaryToolbar.backgroundColor = .systemBackground
        secondaryToolbar.clipsToBounds = true
        searchBar.isHidden = true
        secondaryToolbar.addSubview(compactFilterBar)
        secondaryToolbar.addSubview(searchBar)

        view.addSubview(customNavigationBar)
        view.addSubview(secondaryToolbar)
        view.addSubview(tableView)
        statusToolbar.axis = .horizontal
        statusToolbar.alignment = .center
        statusToolbar.spacing = 10
        statusToolbar.isLayoutMarginsRelativeArrangement = true
        statusToolbar.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 12)
        statusToolbar.backgroundColor = .secondarySystemGroupedBackground
        statusLabel.text = "正在加载日志…"
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.8
        statusLabel.accessibilityIdentifier = "logger.status"
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [statusLabel, resetFiltersButton, refreshButton].forEach { statusToolbar.addArrangedSubview($0) }
        [resetFiltersButton, refreshButton].forEach {
            $0.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        view.addSubview(statusToolbar)
        view.addSubview(emptyState)
        view.addSubview(newLogsBanner)

        [customNavigationBar, secondaryToolbar, compactFilterBar, searchBar, tableView, statusToolbar, emptyState, newLogsBanner].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let toolbarHeight = secondaryToolbar.heightAnchor.constraint(equalToConstant: 40)
        secondaryToolbarHeightConstraint = toolbarHeight

        NSLayoutConstraint.activate([
            customNavigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            secondaryToolbar.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
            secondaryToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secondaryToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarHeight,

            compactFilterBar.topAnchor.constraint(equalTo: secondaryToolbar.topAnchor),
            compactFilterBar.leadingAnchor.constraint(equalTo: secondaryToolbar.leadingAnchor),
            compactFilterBar.trailingAnchor.constraint(equalTo: secondaryToolbar.trailingAnchor),
            compactFilterBar.bottomAnchor.constraint(equalTo: secondaryToolbar.bottomAnchor),

            searchBar.topAnchor.constraint(equalTo: secondaryToolbar.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: secondaryToolbar.safeAreaLayoutGuide.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: secondaryToolbar.safeAreaLayoutGuide.trailingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: secondaryToolbar.bottomAnchor),

            statusToolbar.topAnchor.constraint(equalTo: secondaryToolbar.bottomAnchor),
            statusToolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            statusToolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            statusToolbar.heightAnchor.constraint(equalToConstant: 40),

            tableView.topAnchor.constraint(equalTo: statusToolbar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyState.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            emptyState.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),

            newLogsBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newLogsBanner.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 8),
            newLogsBanner.heightAnchor.constraint(equalToConstant: 28)
        ])

        if fixedPath == nil {
            statsBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: statsBar.preferredHeight)
            tableView.tableHeaderView = statsBar
            statsBar.onPreferredHeightChange = { [weak self] height in
                self?.setStatsHeaderHeight(height)
            }
        }

        updateActionMenu()
        updateDomainMenu()
    }
    
    private func configureCustomNavigationBar() {
        let showsSegments = fixedPath == nil && !isSnapshotMode
        customNavigationBar.setCenterView(showsSegments ? segmentedControl : nil)
        customNavigationBar.setTitle(showsSegments ? "" : listTitle)
        let isPushed = navigationController.map { $0.viewControllers.first !== self } ?? false
        let closeButton = SJCustomNavigationBar.iconButton(systemName: isPushed ? "chevron.left" : "xmark",
                                                           target: self,
                                                           action: isPushed ? #selector(backAction) : #selector(closeAction))
        closeButton.accessibilityLabel = isPushed ? "返回" : "关闭"
        customNavigationBar.setLeftButtons([closeButton])
        customNavigationBar.setRightButtons([searchButton, filterButton, moreButton])
    }
    
    // MARK: - 数据加载
    
    private func loadLogs(revealPending: Bool = false) {
        guard !isSelectionMode else { return }
        shouldRevealPending = shouldRevealPending || revealPending
        if let snapshotLogs = snapshotLogs {
            allLogs = snapshotLogs
            displayedLogs = snapshotLogs
            hasLoadedLogs = true
            updateDomainMenu()
            applyQuery(reload: true)
            refreshControl.endRefreshing()
            return
        }
        reloadGeneration += 1
        let generation = reloadGeneration
        SJLoggerStorage.shared.getAllLogs { [weak self] logs in
            guard let self = self, generation == self.reloadGeneration else { return }
            self.allLogs = logs
            if self.shouldRevealPending || !self.hasLoadedLogs || self.refreshMode == .live || self.filteredLogs.isEmpty {
                self.displayedLogs = logs
            } else {
                // 保持顺序，同时更新响应并移除已删除的记录。
                let latest = Dictionary(logs.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
                self.displayedLogs = self.displayedLogs.compactMap { latest[$0.id] }
                if self.scopedLogs(from: self.displayedLogs).isEmpty { self.displayedLogs = logs }
            }
            self.shouldRevealPending = false
            self.hasLoadedLogs = true
            self.updateDomainMenu()
            self.applyQuery(reload: true)
            self.refreshControl.endRefreshing()
            self.endpointsVC.endRefreshing()
        }
    }

    private func observeLogUpdates() {
        NotificationCenter.default.addObserver(self, selector: #selector(logsDidUpdate),
                                               name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
    }

    @objc private func logsDidUpdate() {
        guard !isSnapshotMode, !isSelectionMode, scheduledReload == nil else { return }
        // 合并密集通知，持续流量下也每 0.1 秒最多刷新一次。
        let work = DispatchWorkItem { [weak self] in
            self?.scheduledReload = nil
            self?.loadLogs()
        }
        scheduledReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    private func applyQuery(reload: Bool) {
        filteredLogs = scopedLogs(from: displayedLogs)
        let displayedIDs = Set(displayedLogs.map(\.id))
        pendingCount = scopedLogs(from: allLogs).filter { !displayedIDs.contains($0.id) }.count
        selectedLogs.formIntersection(Set(filteredLogs.map(\.id)))
        updateNewLogsBanner()
        updateStats()
        updateQuickFilterCounts()
        updateFilterBadge()
        updateEndpointFiltersIfNeeded()
        updateActionMenu()
        if reload { updateUI() }
    }

    private var effectiveQuery: SJLogQuery {
        var q = query
        switch quickFilter {
        case .all: break
        case .failed: q.onlyFailed = true
        case .slow: q.minDurationMs = SJLoggerConfig.shared.slowRequestThresholdMs
        }
        return q
    }

    private func scopedLogs(from logs: [SJLoggerModel]) -> [SJLoggerModel] {
        let domainLogs = logs.filter { selectedHost == nil || $0.host == selectedHost }
        return effectiveQuery.apply(to: domainLogs)
    }
    
    // MARK: - 统计 / 提示条 / 操作状态
    
    private func updateStats() {
        guard fixedPath == nil else { return }
        statsBar.update(with: filteredLogs)
    }
    
    private func updateNewLogsBanner() {
        if pendingCount > 0 && refreshMode == .frozen && !isSelectionMode {
            newLogsBanner.isHidden = false
            newLogsBanner.setTitle("  ↑ \(pendingCount) 条新请求  ", for: .normal)
        } else {
            newLogsBanner.isHidden = true
        }
    }
    
    private func updateFilterBadge() {
        let imageName = query.hasAdvancedFilter
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease"
        SJCustomNavigationBar.setIcon(imageName, for: filterButton)
    }

    private func updateQuickFilterCounts() {
        let domainLogs = query.apply(to: displayedLogs.filter { selectedHost == nil || $0.host == selectedHost })
        let failed = domainLogs.filter { $0.isFailure }.count
        let slow = domainLogs.filter {
            ($0.duration ?? 0) >= SJLoggerConfig.shared.slowRequestThresholdMs
        }.count
        compactFilterBar.setFilterTitles([
            "全部 \(domainLogs.count)",
            "失败 \(failed)",
            "慢请求 \(slow)"
        ])
        compactFilterBar.setSelectedIndex(quickFilter.rawValue)
    }

    private func updateDomainMenu() {
        var counts: [String: Int] = [:]
        allLogs.map(\.host).filter { !$0.isEmpty }.forEach { counts[$0, default: 0] += 1 }
        let hosts = counts.keys.sorted {
            let lhsCount = counts[$0, default: 0]
            let rhsCount = counts[$1, default: 0]
            return lhsCount == rhsCount ? $0.localizedCaseInsensitiveCompare($1) == .orderedAscending : lhsCount > rhsCount
        }

        var actions: [UIMenuElement] = [
            UIAction(title: "全部域名", image: UIImage(systemName: "globe"),
                     state: selectedHost == nil ? .on : .off) { [weak self] _ in
                self?.selectDomain(nil)
            }
        ]
        actions.append(contentsOf: hosts.map { host in
            UIAction(title: "\(host)  \(counts[host, default: 0])",
                     state: selectedHost == host ? .on : .off) { [weak self] _ in
                self?.selectDomain(host)
            }
        })

        let title = selectedHost ?? "全部域名"
        compactFilterBar.setDomain(title: title,
                                   menu: UIMenu(title: "选择域名", options: .displayInline, children: actions))
        updateQuickFilterCounts()
    }

    private func selectDomain(_ host: String?) {
        selectedHost = host
        updateDomainMenu()
        applyQuery(reload: true)
        if !filteredLogs.isEmpty {
            tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
        }
    }

    private func updateEndpointFiltersIfNeeded() {
        guard endpointsVC.parent === self else { return }
        endpointsVC.display(logs: filteredLogs, hasActiveFilters: hasActiveFilters,
                            totalCount: allLogs.count)
    }

    private var hasActiveFilters: Bool {
        return !query.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || query.hasAdvancedFilter || quickFilter != .all || (selectedHost != nil && fixedPath == nil)
    }

    @objc private func resetFilters() {
        query = SJLogQuery()
        query.path = fixedPath
        quickFilter = .all
        if fixedPath == nil { selectedHost = nil }
        searchBar.text = ""
        searchBar.resignFirstResponder()
        setSearchVisible(false, animated: false, focus: false)
        setSecondaryToolbarCollapsed(false, animated: false)
        displayedLogs = allLogs
        updateDomainMenu()
        applyQuery(reload: true)
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
    }

    @objc private func refreshNow() {
        guard !isSelectionMode else {
            refreshControl.endRefreshing()
            endpointsVC.endRefreshing()
            return
        }
        scheduledReload?.cancel()
        scheduledReload = nil
        loadLogs(revealPending: true)
    }

    @objc private func emptyAction() {
        if hasActiveFilters { resetFilters() }
        else if !isSnapshotMode { showSettings() }
    }

    private func setStatsHeaderHeight(_ height: CGFloat) {
        guard tableView.tableHeaderView === statsBar else { return }
        var frame = statsBar.frame
        frame.size.height = height
        statsBar.frame = frame
        tableView.tableHeaderView = statsBar
    }

    private func updateStatsHeaderFrame() {
        guard tableView.tableHeaderView === statsBar else { return }
        let width = tableView.bounds.width
        guard width > 0, statsBar.frame.width != width else { return }
        statsBar.frame = CGRect(x: 0, y: 0, width: width, height: statsBar.preferredHeight)
        tableView.tableHeaderView = statsBar
    }

    private func updateActionMenu() {
        var primaryActions: [UIMenuElement] = []
        if !isSnapshotMode {
            let isLive = refreshMode == .live
            primaryActions.append(UIAction(title: isLive ? "暂停实时刷新" : "恢复实时刷新",
                                           image: UIImage(systemName: isLive ? "pause.circle" : "play.circle.fill")) { [weak self] _ in
                self?.toggleRefreshMode()
            })
        }
        if fixedPath == nil && !isSnapshotMode && segmentedControl.selectedSegmentIndex == 0 {
            primaryActions.append(UIAction(title: isSelectionMode ? "取消选择" : "选择日志",
                                           image: UIImage(systemName: isSelectionMode ? "xmark.circle" : "checkmark.circle")) { [weak self] _ in
                self?.toggleSelectionMode()
            })
        }
        if isSelectionMode {
            let allSelected = !filteredLogs.isEmpty && selectedLogs.count == filteredLogs.count
            primaryActions.append(UIAction(title: allSelected ? "取消全选" : "全选当前结果",
                                           image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.selectedLogs = allSelected ? [] : Set(self.filteredLogs.map(\.id))
                self.updateUI()
                self.updateActionMenu()
            })
        }
        primaryActions.append(UIAction(title: isSelectionMode ? "导出已选日志 (\(selectedLogs.count))" : "导出当前结果",
                                       image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.exportLogs()
        })

        var secondaryActions: [UIMenuElement] = []
        if fixedPath == nil && !isSnapshotMode {
            secondaryActions.append(UIAction(title: "设置", image: UIImage(systemName: "gearshape")) { [weak self] _ in
                self?.showSettings()
            })
            secondaryActions.append(UIAction(title: "清除当前日志", image: UIImage(systemName: "trash"),
                                             attributes: .destructive) { [weak self] _ in
                self?.clearCurrentLogs()
            })
        }

        var groups: [UIMenuElement] = [UIMenu(options: .displayInline, children: primaryActions)]
        if !secondaryActions.isEmpty {
            groups.append(UIMenu(options: .displayInline, children: secondaryActions))
        }
        moreButton.menu = UIMenu(children: groups)

        let color: UIColor = (!isSnapshotMode && refreshMode == .frozen) ? .systemOrange : SJLoggerConfig.shared.floatingWindowColor
        SJCustomNavigationBar.setIcon("ellipsis", for: moreButton, color: color)
        moreButton.accessibilityValue = (!isSnapshotMode && refreshMode == .frozen) ? "已暂停" : nil
    }

    @objc private func showMoreMenu() {}

    @objc private func toggleSearch() {
        if isSearchVisible {
            clearSearchAndHide()
        } else {
            setSearchVisible(true, animated: true, focus: true)
        }
    }

    private func clearSearchAndHide() {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        query.keyword = ""
        setSearchVisible(false, animated: true, focus: false)
        applyQuery(reload: true)
    }

    private func setSearchVisible(_ visible: Bool, animated: Bool, focus: Bool) {
        guard isSearchVisible != visible else {
            if visible && focus { searchBar.becomeFirstResponder() }
            return
        }
        if visible { setSecondaryToolbarCollapsed(false, animated: false) }
        isSearchVisible = visible

        let changes = {
            self.compactFilterBar.isHidden = visible
            self.searchBar.isHidden = !visible
            SJCustomNavigationBar.setIcon(visible ? "xmark.circle.fill" : "magnifyingglass", for: self.searchButton)
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.transition(with: secondaryToolbar, duration: 0.2, options: .transitionCrossDissolve, animations: changes)
        } else {
            changes()
        }
        if visible && focus {
            DispatchQueue.main.async { [weak self] in self?.searchBar.becomeFirstResponder() }
        }
    }

    private func setSecondaryToolbarCollapsed(_ collapsed: Bool, animated: Bool) {
        guard (!isSearchVisible && !hasActiveFilters) || !collapsed, isSecondaryToolbarCollapsed != collapsed else { return }
        isSecondaryToolbarCollapsed = collapsed
        secondaryToolbarHeightConstraint?.constant = collapsed ? 0 : 40
        let changes = {
            self.compactFilterBar.alpha = collapsed ? 0 : 1
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: changes)
        } else {
            changes()
        }
    }
    
    @objc private func applyPendingLogs() {
        displayedLogs = allLogs
        applyQuery(reload: true)
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: true)
        refreshNow()
    }

    @objc private func toggleRefreshMode() {
        guard !isSelectionMode else { return }
        refreshMode = (refreshMode == .live) ? .frozen : .live
        updateActionMenu()
        if refreshMode == .live { applyPendingLogs() }
        updateUI()
        let msg = refreshMode == .live ? "动态模式：新请求实时显示" : "固定模式：新请求暂存，不打断查看"
        showToast(msg)
    }
    
    @objc private func segmentChanged() {
        let showEndpoints = segmentedControl.selectedSegmentIndex == 1
        if showEndpoints {
            if isSelectionMode { toggleSelectionMode() }
            guard endpointsVC.parent == nil else { return }
            addChild(endpointsVC)
            endpointsVC.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(endpointsVC.view)
            NSLayoutConstraint.activate([
                endpointsVC.view.topAnchor.constraint(equalTo: statusToolbar.bottomAnchor),
                endpointsVC.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                endpointsVC.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                endpointsVC.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
            ])
            endpointsVC.didMove(toParent: self)
            updateEndpointFiltersIfNeeded()
            view.bringSubviewToFront(newLogsBanner)
        } else {
            endpointsVC.willMove(toParent: nil)
            endpointsVC.view.removeFromSuperview()
            endpointsVC.removeFromParent()
        }
        tableView.isHidden = showEndpoints
        updateUI()
        updateActionMenu()
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
        tableView.contentInset = UIEdgeInsets(top: 0,
                                              left: inset.left,
                                              bottom: 8,
                                              right: inset.right)
        tableView.scrollIndicatorInsets = tableView.contentInset
    }
    
    private func updateUI() {
        let endpointMode = segmentedControl.selectedSegmentIndex == 1
        emptyState.isHidden = !filteredLogs.isEmpty || endpointMode || !hasLoadedLogs
        emptyLabel.text = hasActiveFilters
            ? "没有匹配的请求\n已有 \(allLogs.count) 条日志，试试重置筛选"
            : (isSnapshotMode ? "没有持久化日志" : "暂无当前日志\n发起网络请求后自动显示\n历史日志可在设置中查看")
        emptyActionButton.setTitle(hasActiveFilters ? "重置筛选" : "查看设置与历史日志", for: .normal)
        emptyActionButton.isHidden = isSnapshotMode && !hasActiveFilters
        let mode = isSnapshotMode ? "历史快照" : (refreshMode == .live ? "实时" : "已暂停")
        statusLabel.text = !hasLoadedLogs ? "正在加载日志…" : (isSelectionMode
            ? "已选 \(selectedLogs.count) / \(filteredLogs.count) 条"
            : "\(mode) · 显示 \(filteredLogs.count) / \(allLogs.count) 条")
        statusLabel.textColor = !isSnapshotMode && refreshMode == .frozen ? .systemOrange : .secondaryLabel
        resetFiltersButton.isHidden = !hasActiveFilters
        resetFiltersButton.isEnabled = !isSelectionMode
        searchBar.isUserInteractionEnabled = !isSelectionMode
        updateNewLogsBanner()
        refreshButton.isHidden = isSnapshotMode || isSelectionMode
        segmentedControl.isEnabled = !isSelectionMode
        filterButton.isEnabled = !isSelectionMode
        searchButton.isEnabled = !isSelectionMode
        compactFilterBar.isUserInteractionEnabled = !isSelectionMode
        if hasActiveFilters { setSecondaryToolbarCollapsed(false, animated: false) }
        tableView.reloadData()
        // 筛选或删除后修正越界偏移，避免列表有数据但可视区为空。
        tableView.layoutIfNeeded()
        let maxY = max(-tableView.adjustedContentInset.top,
                       tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom)
        if tableView.contentOffset.y > maxY {
            tableView.setContentOffset(CGPoint(x: 0, y: maxY), animated: false)
        }
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
            self.searchBar.text = q.keyword
            self.displayedLogs = self.allLogs
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
            searchBar.resignFirstResponder()
            scheduledReload?.cancel()
            scheduledReload = nil
            reloadGeneration += 1
            tableView.allowsMultipleSelection = false
            // 进入编辑模式，停止监听日志更新
            NotificationCenter.default.removeObserver(self, name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
        } else {
            tableView.allowsMultipleSelection = false
            // 退出编辑模式，恢复监听日志更新
            observeLogUpdates()
            // 刷新数据
            loadLogs()
        }
        
        updateActionMenu()
        updateUI()
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
        
        SJLogFileSharing.present(contents: SJLogExporter.text(for: logs), from: self, sourceView: moreButton) { [weak self] in
            if self?.isSelectionMode == true { self?.toggleSelectionMode() }
        }
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
        cell.configure(with: log,
                       isSelected: isSelected,
                       showCheckmark: isSelectionMode,
                       showsHost: selectedHost == nil)
        
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
            tableView.deselectRow(at: indexPath, animated: false)
            updateActionMenu()
            updateUI()
        } else {
            // 普通模式：打开详情
            tableView.deselectRow(at: indexPath, animated: true)
            let detailVC = SJLogDetailViewController(log: log, updatesFromStorage: !isSnapshotMode)
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !isSelectionMode else { return nil }
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
        
        return UISwipeActionsConfiguration(actions: isSnapshotMode ? [shareAction] : [deleteAction, shareAction])
    }
    
    private func shareLog(_ log: SJLoggerModel) {
        SJLogFileSharing.present(contents: log.generateLogText(), from: self, sourceView: moreButton)
    }
}

// MARK: - UISearchBarDelegate
extension SJLogListViewController: UISearchBarDelegate {
    
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchBar.text = searchText
        query.keyword = searchText
        applyQuery(reload: true)
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        clearSearchAndHide()
    }
}

// MARK: - 滚动行为
extension SJLogListViewController {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 用户开始浏览历史时，自动切到固定模式，避免被新日志打断
        if !isSnapshotMode, SJLoggerConfig.shared.autoFreezeOnInteraction,
           refreshMode == .live,
           scrollView.contentOffset.y > 20 {
            refreshMode = .frozen
            updateActionMenu()
            updateUI()
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top {
            setSecondaryToolbarCollapsed(false, animated: true)
        }
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                          withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard !isSearchVisible, scrollView === tableView else { return }
        if targetContentOffset.pointee.y <= 0 || velocity.y < -0.35 {
            setSecondaryToolbarCollapsed(false, animated: true)
        } else if velocity.y > 0.35 {
            setSecondaryToolbarCollapsed(true, animated: true)
        }
    }
}

// MARK: - 快捷分类
enum SJQuickFilter: Int {
    case all = 0
    case failed = 1
    case slow = 2
}
