import UIKit

// MARK: - 日志列表Cell
/// 日志列表的单元格，显示日志摘要信息
class SJLogCell: UITableViewCell {
    
    // MARK: - UI组件
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        return label
    }()
    
    private let methodLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .right
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    // MARK: - 初始化
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI设置
    
    private func setupUI() {
        contentView.addSubview(typeLabel)
        contentView.addSubview(methodLabel)
        contentView.addSubview(urlLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(durationLabel)
        
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        methodLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            typeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            typeLabel.widthAnchor.constraint(equalToConstant: 50),
            typeLabel.heightAnchor.constraint(equalToConstant: 18),
            
            methodLabel.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),
            methodLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            urlLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            urlLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 6),
            urlLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            durationLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -12),
            durationLabel.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor)
        ])
    }
    
    // MARK: - 配置
    
    func configure(with log: SJLoggerModel) {
        // 类型标签
        typeLabel.text = log.type.rawValue
        switch log.type {
        case .http, .https:
            typeLabel.backgroundColor = .systemBlue.withAlphaComponent(0.2)
            typeLabel.textColor = .systemBlue
        case .tcp:
            typeLabel.backgroundColor = .systemPurple.withAlphaComponent(0.2)
            typeLabel.textColor = .systemPurple
        case .udp:
            typeLabel.backgroundColor = .systemOrange.withAlphaComponent(0.2)
            typeLabel.textColor = .systemOrange
        case .websocket:
            typeLabel.backgroundColor = .systemGreen.withAlphaComponent(0.2)
            typeLabel.textColor = .systemGreen
        }
        
        // 方法
        if let method = log.method {
            methodLabel.text = method.rawValue
            methodLabel.isHidden = false
        } else {
            methodLabel.isHidden = true
        }
        
        // URL
        urlLabel.text = log.url
        
        // 状态码
        if let statusCode = log.statusCode {
            statusLabel.text = "\(statusCode)"
            if log.isSuccess {
                statusLabel.textColor = .systemGreen
            } else {
                statusLabel.textColor = .systemRed
            }
        } else if log.error != nil {
            statusLabel.text = "Error"
            statusLabel.textColor = .systemRed
        } else {
            statusLabel.text = "-"
            statusLabel.textColor = .secondaryLabel
        }
        
        // 时间
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        timeLabel.text = formatter.string(from: log.startTime)
        
        // 耗时
        if let duration = log.duration {
            durationLabel.text = "\(Int(duration))ms"
        } else {
            durationLabel.text = "-"
        }
    }
}
