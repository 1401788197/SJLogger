import Foundation

// MARK: - 配置模型
/// SJLogger配置类
public class SJLoggerConfig {
    /// 单例
    public static let shared = SJLoggerConfig()
    
    /// 是否启用日志记录
    public var isEnabled: Bool = true
    
    /// 最大日志数量（超过后自动删除旧日志）
    public var maxLogCount: Int = 1000
    
    /// 需要监听的URL模式（正则表达式）
    public var monitoredURLPatterns: [String] = []
    
    /// 需要忽略的URL模式（正则表达式）
    public var ignoredURLPatterns: [String] = []
    
    /// 是否记录请求体
    public var logRequestBody: Bool = true
    
    /// 是否记录响应体
    public var logResponseBody: Bool = true
    
    /// 响应体最大记录大小（字节），超过则不记录，0表示不限制
    public var maxResponseBodySize: Int = 1024 * 1024 // 1MB
    
    /// 是否启用WebSocket日志
    public var enableWebSocketLog: Bool = true
    
    /// 是否在控制台打印日志
    public var printToConsole: Bool = false
    
    /// 是否显示悬浮窗入口
    public var showFloatingWindow: Bool = true
    
    private init() {}
    
    /// 检查URL是否应该被监控
    public func shouldMonitor(url: String) -> Bool {
        // 如果未启用，直接返回false
        guard isEnabled else { return false }
        
        // 先检查是否在忽略列表中
        if isURLMatched(url: url, patterns: ignoredURLPatterns) {
            return false
        }
        
        // 如果监控列表为空，则监控所有（除了忽略的）
        if monitoredURLPatterns.isEmpty {
            return true
        }
        
        // 检查是否在监控列表中
        return isURLMatched(url: url, patterns: monitoredURLPatterns)
    }
    
    /// 检查URL是否匹配模式列表
    private func isURLMatched(url: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(url.startIndex..., in: url)
                if regex.firstMatch(in: url, options: [], range: range) != nil {
                    return true
                }
            } else if url.contains(pattern) {
                // 如果不是有效的正则表达式，则使用简单的包含匹配
                return true
            }
        }
        return false
    }
    
    /// 添加监控URL模式
    public func addMonitoredURL(pattern: String) {
        if !monitoredURLPatterns.contains(pattern) {
            monitoredURLPatterns.append(pattern)
        }
    }
    
    /// 移除监控URL模式
    public func removeMonitoredURL(pattern: String) {
        monitoredURLPatterns.removeAll { $0 == pattern }
    }
    
    /// 添加忽略URL模式
    public func addIgnoredURL(pattern: String) {
        if !ignoredURLPatterns.contains(pattern) {
            ignoredURLPatterns.append(pattern)
        }
    }
    
    /// 移除忽略URL模式
    public func removeIgnoredURL(pattern: String) {
        ignoredURLPatterns.removeAll { $0 == pattern }
    }
    
    /// 重置为默认配置
    public func reset() {
        isEnabled = true
        maxLogCount = 1000
        monitoredURLPatterns.removeAll()
        ignoredURLPatterns.removeAll()
        logRequestBody = true
        logResponseBody = true
        maxResponseBodySize = 1024 * 1024
        enableWebSocketLog = true
        printToConsole = false
        showFloatingWindow = true
    }
}
