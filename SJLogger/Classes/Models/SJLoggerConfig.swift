import Foundation
import UIKit
import CommonCrypto

// MARK: - 刷新模式
/// 日志列表刷新模式
public enum SJRefreshMode: String, Codable {
    /// 动态：新日志实时进入列表
    case live
    /// 固定：新日志暂存，不打断当前查看
    case frozen
}

// MARK: - Body Decryptor
/// 请求/响应体展示用解密器。只影响展示、搜索、导出，不修改原始抓包数据。
public enum SJBodyDecryptor {
    
    /// AES-CBC-PKCS7 解密。body 优先按 Base64 密文解析，失败时按原始密文字节处理。
    public static func aesCBCPKCS7(key: String, iv: String? = nil) -> (Data) -> String? {
        return { encryptedBody in
            let encryptedData = encryptedBody.base64DecodedBody ?? encryptedBody
            guard let keyData = key.data(using: .utf8),
                  let ivData = (iv ?? key).data(using: .utf8),
                  let decrypted = decryptAES(data: encryptedData, key: keyData, iv: ivData) else {
                return nil
            }
            
            return String(data: decrypted, encoding: .utf8)
        }
    }
    
    private static func decryptAES(data: Data, key: Data, iv: Data) -> Data? {
        guard [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(key.count),
              iv.count >= kCCBlockSizeAES128 else {
            return nil
        }
        
        let outputCapacity = data.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(CCOperation(kCCDecrypt),
                                CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                keyBytes.baseAddress,
                                key.count,
                                ivBytes.baseAddress,
                                dataBytes.baseAddress,
                                data.count,
                                outputBytes.baseAddress,
                                outputCapacity,
                                &outputLength)
                    }
                }
            }
        }
        
        guard status == kCCSuccess else { return nil }
        output.removeSubrange(outputLength..<output.count)
        return output
    }
}

// MARK: - 配置模型
/// SJLogger配置类
public class SJLoggerConfig {
    /// 单例
    public static let shared = SJLoggerConfig()
    
    /// 是否启用日志记录
    public var isEnabled: Bool = true
    
    /// 当前内存列表最大日志数量，持久化日志按磁盘空间限制
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
    
    /// 是否将日志持久化到磁盘（App重启不丢失）
    public var persistLogs: Bool = true {
        didSet { saveSettings() }
    }
    
    /// 持久化日志文件最大大小（字节），超过后优先丢弃旧日志，0 表示不限制
    public var maxPersistedLogFileSize: Int = 10 * 1024 * 1024 {
        didSet { saveSettings() }
    }
    
    /// 请求/响应体展示用解密器。仅运行时生效，不持久化。
    public var bodyDecryptor: ((Data) -> String?)?
    
    /// 列表默认刷新模式
    public var defaultRefreshMode: SJRefreshMode = .live {
        didSet { saveSettings() }
    }
    
    /// 慢请求阈值（毫秒），用于高亮与筛选
    public var slowRequestThresholdMs: Double = 1000 {
        didSet { saveSettings() }
    }
    
    /// 在列表交互（滚动/搜索）时自动切换到固定模式
    public var autoFreezeOnInteraction: Bool = true {
        didSet { saveSettings() }
    }
    
    /// 悬浮窗背景色
    public var floatingWindowColor: UIColor = UIColor(
        red: 0.0 / 255.0,
        green: 180.0 / 255.0,
        blue: 216.0 / 255.0,
        alpha: 1.0
    )
    
    private init() {
        loadSettings()
    }
    
    // MARK: - 设置持久化（UserDefaults）
    
    private static let defaultsKey = "com.sjlogger.config"
    
    private func saveSettings() {
        let dict: [String: Any] = [
            "persistLogs": persistLogs,
            "defaultRefreshMode": defaultRefreshMode.rawValue,
            "slowRequestThresholdMs": slowRequestThresholdMs,
            "autoFreezeOnInteraction": autoFreezeOnInteraction,
            "isEnabled": isEnabled,
            "maxLogCount": maxLogCount,
            "logRequestBody": logRequestBody,
            "logResponseBody": logResponseBody,
            "enableWebSocketLog": enableWebSocketLog,
            "printToConsole": printToConsole,
            "showFloatingWindow": showFloatingWindow,
            "maxPersistedLogFileSize": maxPersistedLogFileSize
        ]
        UserDefaults.standard.set(dict, forKey: Self.defaultsKey)
    }
    
    private func loadSettings() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) else { return }
        if let v = dict["persistLogs"] as? Bool { persistLogs = v }
        if let v = dict["defaultRefreshMode"] as? String, let m = SJRefreshMode(rawValue: v) { defaultRefreshMode = m }
        if let v = dict["slowRequestThresholdMs"] as? Double { slowRequestThresholdMs = v }
        if let v = dict["autoFreezeOnInteraction"] as? Bool { autoFreezeOnInteraction = v }
        if let v = dict["isEnabled"] as? Bool { isEnabled = v }
        if let v = dict["maxLogCount"] as? Int { maxLogCount = v }
        if let v = dict["logRequestBody"] as? Bool { logRequestBody = v }
        if let v = dict["logResponseBody"] as? Bool { logResponseBody = v }
        if let v = dict["enableWebSocketLog"] as? Bool { enableWebSocketLog = v }
        if let v = dict["printToConsole"] as? Bool { printToConsole = v }
        if let v = dict["showFloatingWindow"] as? Bool { showFloatingWindow = v }
        if let v = dict["maxPersistedLogFileSize"] as? Int { maxPersistedLogFileSize = v }
    }
    
    /// 手动持久化当前配置
    public func persistSettings() {
        saveSettings()
    }
    
    /// 设置 AES-CBC-PKCS7 请求/响应体解密器。iv 不传时默认使用 key。
    public func setAESBodyDecryptor(key: String, iv: String? = nil) {
        bodyDecryptor = SJBodyDecryptor.aesCBCPKCS7(key: key, iv: iv)
    }
    
    /// 设置自定义请求/响应体解密器
    public func setBodyDecryptor(_ decryptor: ((Data) -> String?)?) {
        bodyDecryptor = decryptor
    }
    
    func displayString(forBody data: Data) -> String {
        if let decrypted = bodyDecryptor?(data), !decrypted.isEmpty {
            return decrypted
        }
        return String(data: data, encoding: .utf8) ?? data.hexString
    }
    
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
        maxPersistedLogFileSize = 10 * 1024 * 1024
        persistLogs = true
        defaultRefreshMode = .live
        slowRequestThresholdMs = 1000
        autoFreezeOnInteraction = true
        saveSettings()
    }
}

private extension Data {
    var base64DecodedBody: Data? {
        guard let string = String(data: self, encoding: .utf8) else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Data(base64Encoded: trimmed)
    }
}
