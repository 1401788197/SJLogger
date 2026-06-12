import Foundation

// MARK: - 接口分组模型
/// 按接口路径(path)聚合后的统计信息
public struct SJEndpointGroup {
    /// 接口路径（如 /api/user/login）
    public let path: String
    /// 主机名（取该分组下最近一条的host）
    public let host: String
    /// 调用次数
    public let count: Int
    /// 成功次数
    public let successCount: Int
    /// 失败次数
    public let failedCount: Int
    /// 平均耗时（毫秒）
    public let averageDuration: Double
    /// 最近一次调用时间
    public let lastTime: Date
    /// 最近一次状态码
    public let lastStatusCode: Int?
    /// 最近一次日志类型
    public let type: SJLogType
    /// 该分组下的所有日志ID（最新在前）
    public let logIds: [String]
    
    /// 成功率（0.0 ~ 1.0）
    public var successRate: Double {
        guard count > 0 else { return 0 }
        return Double(successCount) / Double(count)
    }
    
    /// 是否包含失败请求
    public var hasFailure: Bool {
        return failedCount > 0
    }
}

// MARK: - 分组构建
extension SJEndpointGroup {
    
    /// 从一组日志按path聚合生成分组列表（按最近调用时间倒序）
    static func build(from logs: [SJLoggerModel]) -> [SJEndpointGroup] {
        // 保持稳定顺序：先收集每个path的日志
        var order: [String] = []
        var buckets: [String: [SJLoggerModel]] = [:]
        
        for log in logs {
            let key = log.path
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(log)
        }
        
        var groups: [SJEndpointGroup] = []
        for key in order {
            guard let items = buckets[key], let latest = items.first else { continue }
            
            let success = items.filter { $0.isSuccess }.count
            let failed = items.count - success
            let durations = items.compactMap { $0.duration }
            let avg = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
            let lastTime = items.map { $0.startTime }.max() ?? latest.startTime
            
            let group = SJEndpointGroup(
                path: key,
                host: latest.host,
                count: items.count,
                successCount: success,
                failedCount: failed,
                averageDuration: avg,
                lastTime: lastTime,
                lastStatusCode: latest.statusCode,
                type: latest.type,
                logIds: items.map { $0.id }
            )
            groups.append(group)
        }
        
        // 按最近调用时间倒序
        return groups.sorted { $0.lastTime > $1.lastTime }
    }
}
