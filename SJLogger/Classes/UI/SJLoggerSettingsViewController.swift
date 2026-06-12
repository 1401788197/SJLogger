import UIKit

// MARK: - 设置视图控制器
/// 集中管理 SJLogger 的所有配置开关与清理操作
public class SJLoggerSettingsViewController: UIViewController {
    
    private enum Row {
        case toggle(title: String, subtitle: String?, get: () -> Bool, set: (Bool) -> Void)
        case segment(title: String, options: [String], selected: () -> Int, set: (Int) -> Void)
        case stepper(title: String, range: ClosedRange<Double>, step: Double, get: () -> Double, set: (Double) -> Void, format: (Double) -> String)
        case action(title: String, destructive: Bool, handler: () -> Void)
    }
    
    private struct Section {
        let header: String?
        let footer: String?
        let rows: [Row]
    }
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [Section] = []
    private lazy var customNavigationBar: SJCustomNavigationBar = {
        return SJCustomNavigationBar(title: "设置")
    }()
    private lazy var doneButton: UIButton = {
        return SJCustomNavigationBar.textButton(title: "完成", target: self, action: #selector(close))
    }()
    private lazy var resetButton: UIButton = {
        return SJCustomNavigationBar.textButton(title: "重置", target: self, action: #selector(resetAll))
    }()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = .systemGroupedBackground
        customNavigationBar.setLeftButtons([resetButton])
        customNavigationBar.setRightButtons([doneButton])
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(customNavigationBar)
        view.addSubview(tableView)
        customNavigationBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customNavigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: customNavigationBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        buildSections()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func buildSections() {
        let config = SJLoggerConfig.shared
        
        sections = [
            Section(header: "采集", footer: "关闭后将停止记录新的网络请求。", rows: [
                .toggle(title: "启用日志记录", subtitle: nil,
                        get: { config.isEnabled }, set: { config.isEnabled = $0; config.persistSettings() }),
                .toggle(title: "记录请求体", subtitle: nil,
                        get: { config.logRequestBody }, set: { config.logRequestBody = $0; config.persistSettings() }),
                .toggle(title: "记录响应体", subtitle: nil,
                        get: { config.logResponseBody }, set: { config.logResponseBody = $0; config.persistSettings() }),
                .toggle(title: "WebSocket 日志", subtitle: nil,
                        get: { config.enableWebSocketLog }, set: { config.enableWebSocketLog = $0; config.persistSettings() }),
                .toggle(title: "控制台打印", subtitle: nil,
                        get: { config.printToConsole }, set: { config.printToConsole = $0; config.persistSettings() })
            ]),
            
            Section(header: "界面与刷新", footer: "「固定」模式下新请求不会打断当前查看；开启自动固定后，滚动浏览历史时会自动暂停刷新。", rows: [
                .segment(title: "默认刷新模式", options: ["动态", "固定"],
                         selected: { config.defaultRefreshMode == .live ? 0 : 1 },
                         set: { config.defaultRefreshMode = $0 == 0 ? .live : .frozen }),
                .toggle(title: "滚动时自动固定", subtitle: nil,
                        get: { config.autoFreezeOnInteraction }, set: { config.autoFreezeOnInteraction = $0 }),
                .toggle(title: "显示悬浮窗", subtitle: nil,
                        get: { config.showFloatingWindow }, set: { config.showFloatingWindow = $0; config.persistSettings()
                            if $0 { SJLogger.shared.showFloatingWindow() } else { SJLogger.shared.hideFloatingWindow() } }),
                .stepper(title: "慢请求阈值", range: 100...10000, step: 100,
                         get: { config.slowRequestThresholdMs }, set: { config.slowRequestThresholdMs = $0 },
                         format: { "\(Int($0))ms" })
            ]),
            
            Section(header: "存储", footer: "开启后日志会写入磁盘，App 重启不丢失。持久化超过最大空间后会优先丢弃旧日志。", rows: [
                .toggle(title: "持久化到磁盘", subtitle: nil,
                        get: { config.persistLogs }, set: { config.persistLogs = $0 }),
                .stepper(title: "持久化最大空间", range: 1...100, step: 1,
                         get: { Double(config.maxPersistedLogFileSize) / 1024 / 1024 },
                         set: { config.maxPersistedLogFileSize = Int($0) * 1024 * 1024; config.persistSettings() },
                         format: { "\(Int($0)) MB" }),
                .action(title: "查看持久化日志", destructive: false, handler: { [weak self] in self?.showPersistedLogs() }),
                .action(title: "导出持久化日志", destructive: false, handler: { [weak self] in self?.exportPersistedLogs() })
            ]),
            
            Section(header: "清理", footer: nil, rows: [
                .action(title: "清除所有日志", destructive: true, handler: { [weak self] in self?.confirmClear() })
            ])
        ]
        tableView.reloadData()
    }
    
    @objc private func close() { dismiss(animated: true) }
    
    @objc private func resetAll() {
        let alert = UIAlertController(title: "重置设置", message: "将所有配置恢复为默认值？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { [weak self] _ in
            SJLoggerConfig.shared.reset()
            self?.buildSections()
        })
        present(alert, animated: true)
    }
    
    private func confirmClear() {
        let alert = UIAlertController(title: "清除所有日志", message: "此操作不可恢复。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { _ in
            SJLoggerStorage.shared.clearAllLogs()
            SJLoggerStorage.shared.clearPersistedLogs()
        })
        present(alert, animated: true)
    }
    
    private func showPersistedLogs() {
        SJLoggerStorage.shared.getPersistedLogs { [weak self] logs in
            guard let self = self else { return }
            guard !logs.isEmpty else {
                self.showMessage("暂无持久化日志")
                return
            }
            
            let vc = SJLogListViewController(title: "持久化日志", logs: logs)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func exportPersistedLogs() {
        SJLoggerStorage.shared.exportPersistedLogsAsText { [weak self] text in
            guard let self = self else { return }
            guard !text.isEmpty else {
                self.showMessage("暂无持久化日志")
                return
            }
            
            let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX,
                                            y: self.view.bounds.midY,
                                            width: 1,
                                            height: 1)
            }
            self.present(activityVC, animated: true)
        }
    }
    
    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - DataSource / Delegate
extension SJLoggerSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    
    public func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].header
    }
    
    public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let row = sections[indexPath.section].rows[indexPath.row]
        
        switch row {
        case let .toggle(title, subtitle, get, set):
            cell.textLabel?.text = title
            cell.detailTextLabel?.text = subtitle
            let sw = UISwitch()
            sw.isOn = get()
            sw.addAction(UIAction { _ in set(sw.isOn) }, for: .valueChanged)
            cell.accessoryView = sw
            
        case let .segment(title, options, selected, set):
            cell.textLabel?.text = title
            let seg = UISegmentedControl(items: options)
            seg.selectedSegmentIndex = selected()
            seg.addAction(UIAction { _ in set(seg.selectedSegmentIndex) }, for: .valueChanged)
            seg.sizeToFit()
            cell.accessoryView = seg
            
        case let .stepper(title, range, step, get, set, format):
            cell.textLabel?.text = title
            let value = get()
            let valueLabel = UILabel()
            valueLabel.text = format(value)
            valueLabel.textColor = .secondaryLabel
            valueLabel.font = .systemFont(ofSize: 15)
            let stepper = UIStepper()
            stepper.minimumValue = range.lowerBound
            stepper.maximumValue = range.upperBound
            stepper.stepValue = step
            stepper.value = value
            stepper.addAction(UIAction { _ in
                set(stepper.value)
                valueLabel.text = format(stepper.value)
            }, for: .valueChanged)
            let container = UIStackView(arrangedSubviews: [valueLabel, stepper])
            container.axis = .horizontal
            container.spacing = 10
            container.alignment = .center
            container.sizeToFit()
            container.frame = CGRect(x: 0, y: 0, width: 160, height: 32)
            cell.accessoryView = container
            
        case let .action(title, destructive, _):
            cell.textLabel?.text = title
            cell.textLabel?.textColor = destructive ? .systemRed : .systemBlue
            cell.textLabel?.textAlignment = .center
            cell.selectionStyle = .default
        }
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if case let .action(_, _, handler) = sections[indexPath.section].rows[indexPath.row] {
            handler()
        }
    }
}
