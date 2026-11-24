import UIKit

// MARK: - 日志列表 Cell
/// 紧凑的两行摘要，优先展示路径、状态和耗时。
class SJLogCell: UITableViewCell {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private let methodBadge = SJBadgeLabel()
    private let pathLabel = UILabel()
    private let hostLabel = UILabel()
    private let hostSeparator = UILabel()
    private let statusLabel = UILabel()
    private let statusSeparator = UILabel()
    private let durationLabel = UILabel()
    private let timeLabel = UILabel()
    private let businessErrorLabel = UILabel()
    private let accessoryContainer = UIView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let checkmark = UIImageView()
    private let separator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .systemBackground
        contentView.backgroundColor = .systemBackground
        selectionStyle = .none

        pathLabel.font = .systemFont(ofSize: 15, weight: .medium)
        pathLabel.textColor = .label
        pathLabel.numberOfLines = 1
        pathLabel.lineBreakMode = .byTruncatingMiddle

        hostLabel.font = .systemFont(ofSize: 11)
        hostLabel.textColor = .secondaryLabel
        hostLabel.numberOfLines = 1
        hostLabel.lineBreakMode = .byTruncatingMiddle
        hostLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        [hostSeparator, statusSeparator].forEach {
            $0.text = "·"
            $0.font = .systemFont(ofSize: 11)
            $0.textColor = .tertiaryLabel
        }

        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        durationLabel.font = .systemFont(ofSize: 12)
        durationLabel.textColor = .secondaryLabel

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        checkmark.tintColor = SJLoggerConfig.shared.floatingWindowColor
        checkmark.contentMode = .scaleAspectFit
        separator.backgroundColor = .separator

        let metadataStack = UIStackView(arrangedSubviews: [
            hostLabel, hostSeparator, statusLabel, statusSeparator, durationLabel, UIView(), timeLabel
        ])
        metadataStack.axis = .horizontal
        metadataStack.alignment = .center
        metadataStack.spacing = 6

        businessErrorLabel.font = .systemFont(ofSize: 12, weight: .medium)
        businessErrorLabel.textColor = .systemRed
        businessErrorLabel.numberOfLines = 2
        businessErrorLabel.lineBreakMode = .byTruncatingTail
        businessErrorLabel.accessibilityIdentifier = "logger.businessError"
        businessErrorLabel.isHidden = true

        let labels = UIStackView(arrangedSubviews: [pathLabel, metadataStack, businessErrorLabel])
        labels.axis = .vertical
        labels.alignment = .fill
        labels.spacing = 7

        contentView.addSubview(methodBadge)
        contentView.addSubview(labels)
        contentView.addSubview(accessoryContainer)
        accessoryContainer.addSubview(chevron)
        accessoryContainer.addSubview(checkmark)
        contentView.addSubview(separator)

        [methodBadge, labels, accessoryContainer, chevron, checkmark, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            methodBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            methodBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            methodBadge.heightAnchor.constraint(equalToConstant: 24),

            labels.leadingAnchor.constraint(equalTo: methodBadge.trailingAnchor, constant: 12),
            labels.trailingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor, constant: -10),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            labels.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            labels.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            accessoryContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            accessoryContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            accessoryContainer.widthAnchor.constraint(equalToConstant: 24),
            accessoryContainer.heightAnchor.constraint(equalToConstant: 28),

            chevron.centerXAnchor.constraint(equalTo: accessoryContainer.centerXAnchor),
            chevron.centerYAnchor.constraint(equalTo: accessoryContainer.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 9),
            chevron.heightAnchor.constraint(equalToConstant: 14),

            checkmark.centerXAnchor.constraint(equalTo: accessoryContainer.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: accessoryContainer.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 22),
            checkmark.heightAnchor.constraint(equalToConstant: 22),

            separator.leadingAnchor.constraint(equalTo: labels.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
    }

    func configure(with log: SJLoggerModel,
                   isSelected: Bool = false,
                   showCheckmark: Bool = false,
                   showsHost: Bool = true) {
        let badgeText: String
        let badgeColor: UIColor
        if let method = log.method {
            badgeText = method.rawValue
            badgeColor = SJTheme.color(for: method)
        } else if log.type == .websocket, let direction = log.wsDirection {
            badgeText = direction.rawValue
            badgeColor = direction == .sent ? .systemBlue : .systemGreen
        } else {
            badgeText = log.type.rawValue
            badgeColor = SJTheme.color(for: log.type)
        }
        methodBadge.setText(badgeText, color: badgeColor)

        pathLabel.text = log.shortPath.isEmpty ? log.url : log.shortPath
        hostLabel.text = log.host
        hostLabel.isHidden = !showsHost || log.host.isEmpty
        hostSeparator.isHidden = hostLabel.isHidden

        if log.isCancelled {
            statusLabel.text = "已取消"
            statusLabel.textColor = .secondaryLabel
        } else if log.error != nil || log.errorCode != nil {
            statusLabel.text = "失败"
            statusLabel.textColor = .systemRed
        } else if let statusCode = log.statusCode {
            statusLabel.text = "\(statusCode)"
            statusLabel.textColor = SJTheme.color(forStatus: statusCode)
        } else {
            statusLabel.text = log.endTime == nil ? "进行中" : "完成"
            statusLabel.textColor = .secondaryLabel
        }

        if let duration = log.duration {
            durationLabel.text = duration >= 1_000
                ? String(format: "%.2f s", duration / 1_000)
                : "\(Int(duration)) ms"
            let isSlow = duration >= SJLoggerConfig.shared.slowRequestThresholdMs
            durationLabel.textColor = isSlow ? .systemOrange : .secondaryLabel
            durationLabel.font = .systemFont(ofSize: 12, weight: isSlow ? .semibold : .regular)
        } else {
            durationLabel.text = "-"
            durationLabel.textColor = .secondaryLabel
            durationLabel.font = .systemFont(ofSize: 12)
        }

        let businessError = log.isCancelled ? nil : log.businessError
        businessErrorLabel.isHidden = businessError == nil
        businessErrorLabel.text = businessError.map {
            "业务失败 · \($0.code) · \($0.message.isEmpty ? "服务端未提供错误说明" : $0.message)"
        }
        if businessError != nil, let statusCode = log.statusCode {
            statusLabel.text = "HTTP \(statusCode)"
        }

        timeLabel.text = Self.timeFormatter.string(from: log.startTime)
        chevron.isHidden = showCheckmark
        checkmark.isHidden = !showCheckmark
        checkmark.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        contentView.backgroundColor = isSelected
            ? SJLoggerConfig.shared.floatingWindowColor.withAlphaComponent(0.08)
            : .systemBackground

        let hostDescription = log.host.isEmpty ? "" : "，域名 \(log.host)"
        let businessDescription = businessErrorLabel.text.map { "，\($0)" } ?? ""
        accessibilityLabel = "\(badgeText)，\(pathLabel.text ?? "")\(hostDescription)，状态 \(statusLabel.text ?? "")，耗时 \(durationLabel.text ?? "")，\(timeLabel.text ?? "")\(businessDescription)"
    }
}
