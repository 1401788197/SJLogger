import Foundation

// MARK: - 日志存储管理器
/// 负责日志的存储、查询和管理
public class SJLoggerStorage {
    /// 单例
    public static let shared = SJLoggerStorage()
    
    /// 存储的日志列表
    private var logs: [SJLoggerModel] = []
    
    /// 线程安全队列
    private let queue = DispatchQueue(label: "com.sjlogger.storage", attributes: .concurrent)
    
    /// 日志更新通知
    public static let logsDidUpdateNotification = Notification.Name("SJLoggerLogsDidUpdate")
    
    private init() {}
    
    // MARK: - 添加日志
    /// 添加新日志
    public func addLog(_ log: SJLoggerModel) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.logs.insert(log, at: 0) // 最新的在前面
            
            // 检查是否超过最大数量
            let maxCount = SJLoggerConfig.shared.maxLogCount
            if self.logs.count > maxCount {
                self.logs = Array(self.logs.prefix(maxCount))
            }
            
            // 发送通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
            }
            
            // 打印到控制台
            if SJLoggerConfig.shared.printToConsole {
                print(log.generateLogText())
            }
        }
    }
    
    /// 更新日志
    public func updateLog(_ log: SJLoggerModel) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let index = self.logs.firstIndex(where: { $0.id == log.id }) {
                self.logs[index] = log
                
                // 发送通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
                }
            }
        }
    }
    
    // MARK: - 查询日志
    /// 获取所有日志
    public func getAllLogs(completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let logs = self.logs
            DispatchQueue.main.async {
                completion(logs)
            }
        }
    }
    
    /// 根据ID获取日志
    public func getLog(byId id: String, completion: @escaping (SJLoggerModel?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let log = self.logs.first { $0.id == id }
            DispatchQueue.main.async {
                completion(log)
            }
        }
    }
    
    /// 搜索日志
    public func searchLogs(keyword: String, completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let keyword = keyword.lowercased()
            let filtered = self.logs.filter { log in
                log.url.lowercased().contains(keyword) ||
                log.method?.rawValue.lowercased().contains(keyword) == true ||
                log.requestBodyString?.lowercased().contains(keyword) == true ||
                log.responseBodyString?.lowercased().contains(keyword) == true
            }
            
            DispatchQueue.main.async {
                completion(filtered)
            }
        }
    }
    
    /// 按类型过滤日志
    public func filterLogs(byType type: SJLogType, completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let filtered = self.logs.filter { $0.type == type }
            DispatchQueue.main.async {
                completion(filtered)
            }
        }
    }
    
    /// 按状态码过滤日志
    public func filterLogs(byStatusCode code: Int, completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let filtered = self.logs.filter { $0.statusCode == code }
            DispatchQueue.main.async {
                completion(filtered)
            }
        }
    }
    
    /// 获取失败的请求
    public func getFailedLogs(completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let filtered = self.logs.filter { !$0.isSuccess || $0.error != nil }
            DispatchQueue.main.async {
                completion(filtered)
            }
        }
    }
    
    // MARK: - 清除日志
    /// 清除所有日志
    public func clearAllLogs() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.logs.removeAll()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
            }
        }
    }
    
    /// 清除指定日志
    public func removeLog(byId id: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.logs.removeAll { $0.id == id }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
            }
        }
    }
    
    // MARK: - 导出日志
    /// 导出所有日志为文本
    public func exportLogsAsText(completion: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion("") }
                return
            }
            
            var text = "SJLogger Export - \(Date())\n"
            text += "Total Logs: \(self.logs.count)\n"
            text += "==========================================\n\n"
            
            for log in self.logs.reversed() {
                text += log.generateLogText()
                text += "\n"
            }
            
            DispatchQueue.main.async {
                completion(text)
            }
        }
    }
    
    /// 导出指定日志为文本
    public func exportLog(byId id: String, completion: @escaping (String?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let log = self.logs.first { $0.id == id }
            let text = log?.generateLogText()
            
            DispatchQueue.main.async {
                completion(text)
            }
        }
    }
    
    // MARK: - 统计信息
    /// 获取日志统计信息
    public func getStatistics(completion: @escaping ([String: Any]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([:]) }
                return
            }
            
            let total = self.logs.count
            let success = self.logs.filter { $0.isSuccess }.count
            let failed = total - success
            let totalSize = self.logs.reduce(0) { $0 + $1.responseSize }
            
            var typeCount: [String: Int] = [:]
            for log in self.logs {
                let key = log.type.rawValue
                typeCount[key, default: 0] += 1
            }
            
            let stats: [String: Any] = [
                "total": total,
                "success": success,
                "failed": failed,
                "totalSize": totalSize,
                "typeCount": typeCount
            ]
            
            DispatchQueue.main.async {
                completion(stats)
            }
        }
    }
}
