import UIKit

// MARK: - 日志列表Cell
/// 日志列表的单元格，显示日志摘要信息
class SJLogCell: UITableViewCell {
    
    // MARK: - UI组件
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        label.layer.cornerRadius = 6
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
    
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
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
        // 设置卡片样式
        backgroundColor = .clear
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        selectionStyle = .none
        // 添加阴影容器
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.08
        layer.masksToBounds = false
        
        contentView.addSubview(typeLabel)
        contentView.addSubview(methodLabel)
        contentView.addSubview(urlLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(checkmarkImageView)
        
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        methodLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            typeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            typeLabel.widthAnchor.constraint(equalToConstant: 55),
            typeLabel.heightAnchor.constraint(equalToConstant: 20),
            
            methodLabel.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),
            methodLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            urlLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            urlLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 8),
            urlLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            durationLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -12),
            durationLabel.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    // MARK: - 布局
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 添加Cell之间的间距
        contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))
    }
    
    // MARK: - 配置
    
    func configure(with log: SJLoggerModel, isSelected: Bool = false, showCheckmark: Bool = false) {
        // 显示/隐藏勾选图标
        checkmarkImageView.isHidden = !showCheckmark
        if showCheckmark {
            checkmarkImageView.image = isSelected ? 
                UIImage(systemName: "checkmark.circle.fill") : 
                UIImage(systemName: "circle")
        }
        
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
