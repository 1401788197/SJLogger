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
        table.rowHeight = 80
        table.separatorStyle = .none
        table.backgroundColor = .systemBackground
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        return table
    }()
    
    private lazy var searchBar: UISearchBar = {
        let search = UISearchBar()
        search.delegate = self
        search.placeholder = "搜索URL、方法、内容..."
        search.searchBarStyle = .minimal
        search.backgroundImage = UIImage()
        search.setShowsCancelButton(true, animated: false)
        return search
    }()

    private let secondaryToolbar = UIView()
    
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
        vc.onSelectEndpoint = { [weak self] path, host in
            let detail = SJLogListViewController(fixedPath: path)
            detail.selectedHost = host.isEmpty ? self?.selectedHost : host
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
    /// nil 表示全部域名。
    private var selectedHost: String?
    
    /// 刷新模式（动态/固定）
    private var refreshMode: SJRefreshMode = SJLoggerConfig.shared.defaultRefreshMode
    /// 固定模式下暂存的新日志数量
    private var pendingCount = 0
    
    // 记住筛选条件
    private static var savedSearchText: String = ""
    
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
        updateContentInsets()
        updateStatsHeaderFrame()
    }
    
    deinit {
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
        view.addSubview(emptyLabel)
        view.addSubview(newLogsBanner)

        [customNavigationBar, secondaryToolbar, compactFilterBar, searchBar, tableView, emptyLabel, newLogsBanner].forEach {
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

            tableView.topAnchor.constraint(equalTo: secondaryToolbar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),

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
        let isPushed = navigationController?.viewControllers.first !== self
        let closeButton = SJCustomNavigationBar.iconButton(systemName: isPushed ? "chevron.left" : "xmark",
                                                           target: self,
                                                           action: isPushed ? #selector(backAction) : #selector(closeAction))
        closeButton.accessibilityLabel = isPushed ? "返回" : "关闭"
        customNavigationBar.setLeftButtons([closeButton])
        customNavigationBar.setRightButtons([searchButton, filterButton, moreButton])
    }
    
    // MARK: - 数据加载
    
    private func loadLogs() {
        if let snapshotLogs = snapshotLogs {
            allLogs = snapshotLogs
            updateDomainMenu()
            applyQuery(reload: true)
            return
        }
        
        SJLoggerStorage.shared.getAllLogs { [weak self] logs in
            guard let self = self else { return }
            self.allLogs = logs
            self.updateDomainMenu()
            self.applyQuery(reload: true)
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
                let previousCount = self.scopedLogs(from: self.allLogs).count
                let newCount = max(0, self.scopedLogs(from: logs).count - previousCount)
                self.allLogs = logs
                self.updateDomainMenu()
                if newCount > 0 {
                    self.pendingCount += newCount
                    self.updateNewLogsBanner()
                }
            }
            return
        }
        // 动态模式：实时刷新
        loadLogs()
    }
    
    /// 合并当前query+快捷分类，刷新展示
    private func applyQuery(reload: Bool) {
        filteredLogs = scopedLogs(from: allLogs)
        pendingCount = 0
        updateNewLogsBanner()
        updateStats()
        updateQuickFilterCounts()
        updateFilterBadge()
        updateEndpointFiltersIfNeeded()
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
    
    // MARK: - 状态恢复
    
    private func restoreFilterState() {
        if fixedPath == nil, !isSnapshotMode, !Self.savedSearchText.isEmpty {
            searchBar.text = Self.savedSearchText
            query.keyword = Self.savedSearchText
            setSearchVisible(true, animated: false, focus: false)
        }
    }
    
    // MARK: - 统计 / 提示条 / 操作状态
    
    private func updateStats() {
        guard fixedPath == nil else { return }
        statsBar.update(with: filteredLogs)
    }
    
    private func updateNewLogsBanner() {
        if pendingCount > 0 && refreshMode == .frozen {
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
        let domainLogs = allLogs.filter { selectedHost == nil || $0.host == selectedHost }
        let failed = domainLogs.filter {
            $0.error != nil || (($0.statusCode ?? 0) >= 400)
        }.count
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

        if !allLogs.isEmpty, let selectedHost = selectedHost, !hosts.contains(selectedHost) {
            self.selectedHost = nil
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
        guard segmentedControl.selectedSegmentIndex == 1, endpointsVC.parent === self else { return }
        endpointsVC.setHost(selectedHost)
        var endpointQuery = effectiveQuery
        endpointQuery.keyword = ""
        endpointQuery.path = nil
        endpointsVC.setFilterQuery(endpointQuery)
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
        if fixedPath == nil && !isSnapshotMode {
            primaryActions.append(UIAction(title: isSelectionMode ? "取消选择" : "选择日志",
                                           image: UIImage(systemName: isSelectionMode ? "xmark.circle" : "checkmark.circle")) { [weak self] _ in
                self?.toggleSelectionMode()
            })
        }
        primaryActions.append(UIAction(title: isSelectionMode ? "导出已选日志" : "导出当前结果",
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
        Self.savedSearchText = ""
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
        guard !isSearchVisible || !collapsed, isSecondaryToolbarCollapsed != collapsed else { return }
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
        pendingCount = 0
        updateNewLogsBanner()
        applyQuery(reload: true)
        if !filteredLogs.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }
    
    @objc private func toggleRefreshMode() {
        refreshMode = (refreshMode == .live) ? .frozen : .live
        updateActionMenu()
        if refreshMode == .live {
            applyPendingLogs()
        }
        let msg = refreshMode == .live ? "动态模式：新请求实时显示" : "固定模式：新请求暂存，不打断查看"
        showToast(msg)
    }
    
    @objc private func segmentChanged() {
        let showEndpoints = segmentedControl.selectedSegmentIndex == 1
        if showEndpoints {
            addChild(endpointsVC)
            endpointsVC.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(endpointsVC.view)
            NSLayoutConstraint.activate([
                endpointsVC.view.topAnchor.constraint(equalTo: secondaryToolbar.bottomAnchor),
                endpointsVC.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                endpointsVC.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                endpointsVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            endpointsVC.didMove(toParent: self)
            endpointsVC.setKeyword(searchBar.text ?? "")
            endpointsVC.setHost(selectedHost)
            var endpointQuery = effectiveQuery
            endpointQuery.keyword = ""
            endpointQuery.path = nil
            endpointsVC.setFilterQuery(endpointQuery)
            view.bringSubviewToFront(newLogsBanner)
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
        tableView.contentInset = UIEdgeInsets(top: 0,
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
            tableView.allowsMultipleSelection = true
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
            popover.sourceView = moreButton
            popover.sourceRect = moreButton.bounds
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
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
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
        clearSearchAndHide()
    }
}

// MARK: - 滚动行为
extension SJLogListViewController {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 用户开始浏览历史时，自动切到固定模式，避免被新日志打断
        if SJLoggerConfig.shared.autoFreezeOnInteraction,
           refreshMode == .live,
           scrollView.contentOffset.y > 20 {
            refreshMode = .frozen
            updateActionMenu()
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
