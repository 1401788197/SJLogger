import UIKit

// MARK: - 接口分组列表视图控制器
/// 按接口路径(path)聚合展示，点击某接口下钻查看该接口的全部调用记录
public class SJEndpointListViewController: UIViewController {
    
    // MARK: - UI
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(SJEndpointCell.self, forCellReuseIdentifier: "SJEndpointCell")
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 92
        table.separatorStyle = .none
        table.backgroundColor = .systemGroupedBackground
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        return table
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无接口\n\n应用发起网络请求后，接口将按路径聚合显示在这里"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.isHidden = true
        return label
    }()
    
    // MARK: - 数据
    
    private var groups: [SJEndpointGroup] = []
    private var filteredGroups: [SJEndpointGroup] = []
    private var keyword: String = ""
    
    /// 点击某接口的回调（若设置则优先于默认push行为）
    public var onSelectPath: ((String) -> Void)?
    
    // MARK: - 生命周期
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        loadGroups()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(loadGroups),
                                               name: SJLoggerStorage.logsDidUpdateNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    // MARK: - 数据
    
    @objc private func loadGroups() {
        SJLoggerStorage.shared.getEndpointGroups { [weak self] groups in
            self?.groups = groups
            self?.applyKeyword()
        }
    }
    
    /// 外部设置搜索关键字（来自容器VC的搜索框）
    public func setKeyword(_ text: String) {
        keyword = text
        applyKeyword()
    }
    
    private func applyKeyword() {
        if keyword.isEmpty {
            filteredGroups = groups
        } else {
            let kw = keyword.lowercased()
            filteredGroups = groups.filter {
                $0.path.lowercased().contains(kw) || $0.host.lowercased().contains(kw)
            }
        }
        emptyLabel.isHidden = !filteredGroups.isEmpty
        tableView.reloadData()
    }
}

// MARK: - DataSource / Delegate
extension SJEndpointListViewController: UITableViewDataSource, UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredGroups.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SJEndpointCell", for: indexPath) as! SJEndpointCell
        cell.configure(with: filteredGroups[indexPath.row])
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let path = filteredGroups[indexPath.row].path
        if let onSelectPath = onSelectPath {
            onSelectPath(path)
        } else {
            let vc = SJLogListViewController(fixedPath: path)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - 接口分组Cell
class SJEndpointCell: UITableViewCell {
    
    private let card = UIView()
    private let methodBadge = SJBadgeLabel()
    private let pathLabel = UILabel()
    private let hostLabel = UILabel()
    private let statsLabel = UILabel()
    private let countBadge = SJBadgeLabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.layer.masksToBounds = false
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 4
        card.layer.shadowOpacity = 0.06
        
        pathLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        pathLabel.textColor = .label
        pathLabel.numberOfLines = 1
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        hostLabel.font = .systemFont(ofSize: 11)
        hostLabel.textColor = .secondaryLabel
        hostLabel.numberOfLines = 1
        hostLabel.lineBreakMode = .byTruncatingMiddle
        
        statsLabel.font = .systemFont(ofSize: 11)
        statsLabel.textColor = .secondaryLabel
        statsLabel.numberOfLines = 1
        statsLabel.lineBreakMode = .byTruncatingTail
        
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        
        contentView.addSubview(card)
        [methodBadge, pathLabel, hostLabel, statsLabel, countBadge, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }
        card.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            methodBadge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            methodBadge.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            methodBadge.heightAnchor.constraint(equalToConstant: 18),
            
            pathLabel.leadingAnchor.constraint(equalTo: methodBadge.trailingAnchor, constant: 8),
            pathLabel.centerYAnchor.constraint(equalTo: methodBadge.centerYAnchor),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: countBadge.leadingAnchor, constant: -8),
            
            countBadge.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            countBadge.centerYAnchor.constraint(equalTo: methodBadge.centerYAnchor),
            countBadge.heightAnchor.constraint(equalToConstant: 18),
            
            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            
            hostLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            hostLabel.topAnchor.constraint(equalTo: methodBadge.bottomAnchor, constant: 8),
            hostLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            
            statsLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            statsLabel.topAnchor.constraint(equalTo: hostLabel.bottomAnchor, constant: 4),
            statsLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            statsLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10)
        ])
    }
    
    func configure(with group: SJEndpointGroup) {
        methodBadge.setText(group.type.rawValue, color: SJTheme.color(for: group.type))
        pathLabel.text = group.path.isEmpty ? "/" : group.path
        hostLabel.text = group.host.isEmpty ? "—" : group.host
        countBadge.setText("×\(group.count)", color: .systemGray)
        
        let rate = Int((group.successRate * 100).rounded())
        let avg = Int(group.averageDuration)
        let rateColor = group.hasFailure ? "⚠️ " : ""
        statsLabel.text = "\(rateColor)成功率 \(rate)% · 平均 \(avg)ms · 失败 \(group.failedCount)"
    }
}
