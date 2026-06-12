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
    
    /// 落盘节流工作项
    private var persistWorkItem: DispatchWorkItem?
    
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
            
            self.schedulePersist(mergeWithPersistedLogs: true)
            
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
                self.schedulePersist(mergeWithPersistedLogs: true)
                
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
    /// 清除当前内存中的日志，不修改磁盘上的持久化日志
    public func clearCurrentLogs() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.logs.removeAll()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: SJLoggerStorage.logsDidUpdateNotification, object: nil)
            }
        }
    }
    
    /// 清除所有日志
    public func clearAllLogs() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.logs.removeAll()
            self.schedulePersist(mergeWithPersistedLogs: false)
            
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
            self.schedulePersist(mergeWithPersistedLogs: true)
            
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
    
    /// 获取磁盘上的持久化日志
    public func getPersistedLogs(completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async { [weak self] in
            guard let self = self,
                  let url = self.persistFileURL,
                  FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let logs = try? JSONDecoder().decode([SJLoggerModel].self, from: data) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            DispatchQueue.main.async {
                completion(logs)
            }
        }
    }
    
    /// 导出磁盘上的持久化日志为文本
    public func exportPersistedLogsAsText(completion: @escaping (String) -> Void) {
        getPersistedLogs { logs in
            guard !logs.isEmpty else {
                completion("")
                return
            }
            completion(Self.exportText(for: logs, title: "SJLogger 持久化日志导出"))
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
    
    private static func exportText(for logs: [SJLoggerModel], title: String) -> String {
        var text = "========== \(title) ==========\n"
        text += "导出时间: \(Date())\n"
        text += "日志数量: \(logs.count)\n"
        text += "========================================\n\n"
        
        for (index, log) in logs.enumerated() {
            text += "[\(index + 1)/\(logs.count)]\n"
            text += log.generateLogText()
            text += "\n========================================\n\n"
        }
        
        return text
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
    
    // MARK: - 接口分组
    /// 按接口路径(path)聚合分组
    public func getEndpointGroups(completion: @escaping ([SJEndpointGroup]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let groups = SJEndpointGroup.build(from: self.logs)
            DispatchQueue.main.async { completion(groups) }
        }
    }
    
    /// 获取指定接口路径下的所有日志
    public func getLogs(forPath path: String, completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let filtered = self.logs.filter { $0.path == path }
            DispatchQueue.main.async { completion(filtered) }
        }
    }
    
    // MARK: - 高级查询
    /// 按组合条件筛选日志
    public func query(_ criteria: SJLogQuery, completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let filtered = criteria.apply(to: self.logs)
            DispatchQueue.main.async { completion(filtered) }
        }
    }
    
    // MARK: - 持久化（磁盘）
    
    /// 持久化文件URL
    private var persistFileURL: URL? {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("SJLogger", isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("logs.json")
    }
    
    /// 安排一次节流落盘（0.8s 内多次调用只写一次）
    /// - Note: 必须在 barrier 队列内调用
    private func schedulePersist(mergeWithPersistedLogs: Bool) {
        guard SJLoggerConfig.shared.persistLogs else { return }
        persistWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.writeToDisk(mergeWithPersistedLogs: mergeWithPersistedLogs)
        }
        persistWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.8, execute: work)
    }
    
    /// 立即将日志写入磁盘
    private func writeToDisk(mergeWithPersistedLogs: Bool) {
        guard SJLoggerConfig.shared.persistLogs, let url = persistFileURL else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            var snapshot = self.logs
            if mergeWithPersistedLogs {
                snapshot = self.mergedWithPersistedLogs(snapshot, from: url)
            }
            do {
                let data = try self.encodedSnapshotForPersistence(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                // 持久化失败时静默忽略，不影响主流程
            }
        }
    }
    
    private func mergedWithPersistedLogs(_ currentLogs: [SJLoggerModel], from url: URL) -> [SJLoggerModel] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let persistedLogs = try? JSONDecoder().decode([SJLoggerModel].self, from: data) else {
            return currentLogs
        }
        
        let currentIds = Set(currentLogs.map { $0.id })
        let olderPersistedLogs = persistedLogs.filter { !currentIds.contains($0.id) }
        return currentLogs + olderPersistedLogs
    }
    
    private func encodedSnapshotForPersistence(_ logs: [SJLoggerModel]) throws -> Data {
        let encoder = JSONEncoder()
        let maxBytes = SJLoggerConfig.shared.maxPersistedLogFileSize
        guard maxBytes > 0 else {
            return try encoder.encode(logs)
        }
        
        var snapshot = logs
        var data = try encoder.encode(snapshot)
        while data.count > maxBytes && !snapshot.isEmpty {
            snapshot.removeLast()
            data = try encoder.encode(snapshot)
        }
        return data
    }
    
    /// 清空磁盘上的持久化文件
    public func clearPersistedLogs() {
        guard let url = persistFileURL else { return }
        persistWorkItem?.cancel()
        try? FileManager.default.removeItem(at: url)
    }
}
