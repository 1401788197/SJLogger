import Foundation

// MARK: - 日志类型
/// 日志类型枚举
public enum SJLogType: String, Codable {
    case http = "HTTP"
    case https = "HTTPS"
    case tcp = "TCP"
    case udp = "UDP"
    case websocket = "WebSocket"
}

// MARK: - 请求方法
/// HTTP请求方法
public enum SJHTTPMethod: String, Codable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
}

// MARK: - 日志模型
/// 网络日志数据模型
public class SJLoggerModel: Codable {
    /// 唯一标识
    public let id: String
    /// 日志类型
    public let type: SJLogType
    /// 请求URL
    public let url: String
    /// 请求方法
    public let method: SJHTTPMethod?
    /// 请求头
    public var requestHeaders: [String: String]?
    /// 请求体
    public var requestBody: Data?
    /// 响应状态码
    public var statusCode: Int?
    /// 响应头
    public var responseHeaders: [String: String]?
    /// 响应体
    public var responseBody: Data?
    /// 错误信息
    public var error: String?
    /// 请求开始时间
    public let startTime: Date
    /// 请求结束时间
    public var endTime: Date?
    /// 请求耗时（毫秒）
    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return (endTime.timeIntervalSince(startTime) * 1000).rounded()
    }
    
    // TCP相关
    /// TCP连接信息
    public var tcpInfo: String?
    
    // 计算属性
    /// 请求体字符串
    public var requestBodyString: String? {
        guard let data = requestBody else { return nil }
        return String(data: data, encoding: .utf8) ?? data.hexString
    }
    
    /// 响应体字符串
    public var responseBodyString: String? {
        guard let data = responseBody else { return nil }
        return String(data: data, encoding: .utf8) ?? data.hexString
    }
    
    /// 是否成功
    public var isSuccess: Bool {
        guard let code = statusCode else { return false }
        return (200...299).contains(code)
    }
    
    /// 响应大小（字节）
    public var responseSize: Int {
        return responseBody?.count ?? 0
    }
    
    public init(
        id: String = UUID().uuidString,
        type: SJLogType,
        url: String,
        method: SJHTTPMethod? = nil,
        requestHeaders: [String: String]? = nil,
        requestBody: Data? = nil,
        startTime: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.startTime = startTime
    }
    
    /// 生成完整的日志文本
    public func generateLogText() -> String {
        var text = ""
        
        text += "========== \(type.rawValue) Request ==========\n"
        text += "ID: \(id)\n"
        text += "URL: \(url)\n"
        
        if let method = method {
            text += "Method: \(method.rawValue)\n"
        }
        
        text += "Start Time: \(formatDate(startTime))\n"
        
        if let duration = duration {
            text += "Duration: \(duration)ms\n"
        }
        
        if let statusCode = statusCode {
            text += "Status Code: \(statusCode)\n"
        }
        
        if let error = error {
            text += "Error: \(error)\n"
        }
        
        // 请求头
        if let headers = requestHeaders, !headers.isEmpty {
            text += "\n--- Request Headers ---\n"
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                text += "\(key): \(value)\n"
            }
        }
        
        // 请求体
        if let bodyString = requestBodyString {
            text += "\n--- Request Body ---\n"
            text += "\(bodyString)\n"
        }
        
        // 响应头
        if let headers = responseHeaders, !headers.isEmpty {
            text += "\n--- Response Headers ---\n"
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                text += "\(key): \(value)\n"
            }
        }
        
        // 响应体
        if let bodyString = responseBodyString {
            text += "\n--- Response Body ---\n"
            text += "\(bodyString)\n"
        }
        
        // TCP信息
        if let tcpInfo = tcpInfo {
            text += "\n--- TCP Info ---\n"
            text += "\(tcpInfo)\n"
        }
        
        text += "==========================================\n"
        
        return text
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

// MARK: - Data Extension
extension Data {
    /// 转换为十六进制字符串
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}
