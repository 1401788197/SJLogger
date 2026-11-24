import Foundation

// MARK: - 状态码段
/// 状态码分段过滤
public enum SJStatusBucket: String, CaseIterable, Codable {
    case info = "1xx"
    case success = "2xx"
    case redirect = "3xx"
    case clientError = "4xx"
    case serverError = "5xx"
    case businessError = "业务失败"
    case cancelled = "已取消"
    case error = "Error"  // 无状态码但有错误
    
    /// 判断给定日志是否落在该段
    func matches(_ log: SJLoggerModel) -> Bool {
        switch self {
        case .cancelled:
            return log.isCancelled
        case .businessError:
            return log.businessError != nil
        case .error:
            return !log.isCancelled && log.statusCode == nil && (log.error != nil || log.errorCode != nil)
        default:
            guard let code = log.statusCode else { return false }
            switch self {
            case .info: return (100...199).contains(code)
            case .success: return (200...299).contains(code)
            case .redirect: return (300...399).contains(code)
            case .clientError: return (400...499).contains(code)
            case .serverError: return (500...599).contains(code)
            case .error, .businessError, .cancelled: return false
            }
        }
    }
}

// MARK: - 高级筛选条件
/// 组合筛选条件，所有非空条件之间为 AND 关系
public struct SJLogQuery {
    /// 关键字（匹配 url/method/请求体/响应体）
    public var keyword: String = ""
    /// 类型过滤（为空表示不限）
    public var types: Set<SJLogType> = []
    /// 方法过滤（为空表示不限）
    public var methods: Set<SJHTTPMethod> = []
    /// 状态码段过滤（为空表示不限）
    public var statusBuckets: Set<SJStatusBucket> = []
    /// 仅显示慢请求（耗时 >= 阈值ms），nil表示不限
    public var minDurationMs: Double? = nil
    /// 起始时间（含），nil表示不限
    public var startDate: Date? = nil
    /// 结束时间（含），nil表示不限
    public var endDate: Date? = nil
    /// 仅失败
    public var onlyFailed: Bool = false
    /// 仅取消，与其他筛选条件保持 AND 关系
    public var onlyCancelled: Bool = false
    /// 限定的接口路径（用于「按接口」下钻），nil表示不限
    public var path: String? = nil
    
    public init() {}
    
    /// 是否为空查询（无任何过滤）
    public var isEmpty: Bool {
        return keyword.isEmpty
            && types.isEmpty
            && methods.isEmpty
            && statusBuckets.isEmpty
            && minDurationMs == nil
            && startDate == nil
            && endDate == nil
            && !onlyFailed
            && !onlyCancelled
            && path == nil
    }
    
    /// 除关键字/path外是否有“高级”过滤生效（用于按钮徽标显示）
    public var hasAdvancedFilter: Bool {
        return !types.isEmpty
            || !methods.isEmpty
            || !statusBuckets.isEmpty
            || minDurationMs != nil
            || startDate != nil
            || endDate != nil
            || onlyFailed
            || onlyCancelled
    }
    
    /// 判断单条日志是否匹配
    public func matches(_ log: SJLoggerModel) -> Bool {
        // path
        if let path = path, log.path != path {
            return false
        }
        // 类型
        if !types.isEmpty, !types.contains(log.type) {
            return false
        }
        // 方法
        if !methods.isEmpty {
            guard let m = log.method, methods.contains(m) else { return false }
        }
        // 状态码段（满足任一即可）
        if !statusBuckets.isEmpty {
            let ok = statusBuckets.contains { $0.matches(log) }
            if !ok { return false }
        }
        // 仅失败
        if onlyFailed, !log.isFailure {
            return false
        }
        if onlyCancelled, !log.isCancelled { return false }
        // 慢请求
        if let minMs = minDurationMs {
            guard let d = log.duration, d >= minMs else { return false }
        }
        // 时间范围
        if let start = startDate, log.startTime < start {
            return false
        }
        if let end = endDate, log.startTime > end {
            return false
        }
        // 关键字
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !kw.isEmpty {
            let hit = log.url.lowercased().contains(kw)
                || (log.method?.rawValue.lowercased().contains(kw) ?? false)
                || (log.requestBodyString?.lowercased().contains(kw) ?? false)
                || (log.responseBodyString?.lowercased().contains(kw) ?? false)
            let headerHit = [log.requestHeaders, log.responseHeaders].contains { headers in
                headers?.contains { $0.key.lowercased().contains(kw) || $0.value.lowercased().contains(kw) } ?? false
            }
            let businessHit = log.businessResult.map {
                $0.code.lowercased().contains(kw) || $0.message.lowercased().contains(kw)
            } ?? false
            if !hit && !headerHit && !businessHit { return false }
        }
        return true
    }
    
    /// 对一组日志应用筛选
    public func apply(to logs: [SJLoggerModel]) -> [SJLoggerModel] {
        guard !isEmpty else { return logs }
        return logs.filter { matches($0) }
    }
}
