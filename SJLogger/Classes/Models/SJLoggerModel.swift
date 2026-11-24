import Foundation
import CoreFoundation

// MARK: - 日志类型
/// 日志类型枚举
public enum SJLogType: String, Codable {
    case http = "HTTP"
    case https = "HTTPS"
    case tcp = "TCP"
    case udp = "UDP"
    case websocket = "WebSocket"
}

// MARK: - WebSocket消息方向
/// WebSocket消息方向（发送/接收/系统事件）
public enum SJWSDirection: String, Codable {
    case sent = "SENT"
    case received = "RECV"
    case system = "SYS"
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

/// App 响应中的业务结果，与 HTTP 状态码相互独立。
public struct SJBusinessResult: Codable, Equatable {
    public let code: String
    public let message: String
    public let isSuccess: Bool

    public init(code: String, message: String, isSuccess: Bool) {
        self.code = code
        self.message = message
        self.isSuccess = isSuccess
    }

    /// 默认协议：顶层 code + message（或 msg），code 为整数或整数字符串，0 成功。
    /// 不把任意业务对象中的 code、布尔值、嵌套字段或无效 JSON 猜测成错误。
    public static func parseJSONEnvelope(_ log: SJLoggerModel) -> SJBusinessResult? {
        guard let text = log.responseBodyString,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = (json["message"] as? String) ?? (json["msg"] as? String) else { return nil }
        let code: String
        if let number = json["code"] as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue.isFinite,
                  number.doubleValue.rounded() == number.doubleValue else { return nil }
            code = number.stringValue
        } else if let value = json["code"] as? String,
                  let number = Int64(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            code = String(number)
        } else {
            return nil
        }
        return SJBusinessResult(code: code, message: message, isSuccess: code == "0")
    }
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
    /// 原始 NSError 标识；旧版持久化日志缺少这些字段时保持 nil。
    public var errorDomain: String?
    public var errorCode: Int?
    /// 仅记录拦截层可观察到的取消来源，不推断页面或业务原因。
    public var cancellationSource: String?

    public var isCancelled: Bool {
        return errorDomain == NSURLErrorDomain && errorCode == NSURLErrorCancelled
    }

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
    
    /// WebSocket消息方向（仅WebSocket日志有效）
    public var wsDirection: SJWSDirection?
    
    /// WebSocket事件名（如 Connected / Text / Disconnected）
    public var wsEventName: String?
    
    // MARK: - URL解析
    
    /// 主机名（host），解析失败时返回原始url
    public var host: String {
        return URLComponents(string: url)?.host ?? ""
    }
    
    /// 接口路径（忽略 scheme/host/query），如 /api/user/login
    public var path: String {
        if let comps = URLComponents(string: url), !comps.path.isEmpty {
            return comps.path
        }
        // 解析失败时，去掉query后返回
        if let q = url.firstIndex(of: "?") {
            return String(url[..<q])
        }
        return url
    }
    
    /// 用于列表展示的简短路径（path + 末尾query提示）
    public var shortPath: String {
        let p = path
        return p.isEmpty ? url : p
    }
    
    // 计算属性
    /// 请求体字符串
    public var requestBodyString: String? {
        guard let data = requestBody else { return nil }
        return SJLoggerConfig.shared.displayString(forBody: data)
    }
    
    /// 响应体字符串
    public var responseBodyString: String? {
        guard let data = responseBody else { return nil }
        return SJLoggerConfig.shared.displayString(forBody: data)
    }
    
    /// 仅 HTTP/HTTPS 响应参与业务判断，复用展示用解密器，不修改原始响应。
    public var businessResult: SJBusinessResult? {
        guard type == .http || type == .https, responseBody != nil else { return nil }
        return SJLoggerConfig.shared.businessResultParser?(self)
    }

    public var businessError: SJBusinessResult? {
        guard let result = businessResult, !result.isSuccess else { return nil }
        return result
    }

    /// HTTP 成功且不存在传输错误或明确的业务失败。
    public var isSuccess: Bool {
        guard let code = statusCode else { return false }
        return (200...299).contains(code) && error == nil && errorCode == nil && businessError == nil
    }
    
    /// 已明确失败的请求；进行中、重定向和正常 WebSocket 事件不算失败。
    public var isFailure: Bool {
        guard !isCancelled else { return false }
        if error != nil || errorCode != nil || businessError != nil { return true }
        guard type == .http || type == .https, let code = statusCode else { return false }
        return code >= 400
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

    /// 创建独立快照，避免存储队列更新时与 UI 共享同一个可变对象。
    func snapshot() -> SJLoggerModel {
        let copy = SJLoggerModel(
            id: id,
            type: type,
            url: url,
            method: method,
            requestHeaders: requestHeaders,
            requestBody: requestBody,
            startTime: startTime
        )
        copy.statusCode = statusCode
        copy.responseHeaders = responseHeaders
        copy.responseBody = responseBody
        copy.error = error
        copy.errorDomain = errorDomain
        copy.errorCode = errorCode
        copy.cancellationSource = cancellationSource
        copy.endTime = endTime
        copy.tcpInfo = tcpInfo
        copy.wsDirection = wsDirection
        copy.wsEventName = wsEventName
        return copy
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
        
        if isCancelled { text += "Result: 已取消\n" }
        if let domain = errorDomain { text += "Error Domain: \(domain)\n" }
        if let code = errorCode { text += "Error Code: \(code)\n" }
        if let source = cancellationSource { text += "Cancellation Source: \(source)\n" }

        if let error = error {
            text += "Error: \(error)\n"
        }
        
        if let result = businessResult {
            text += "Business Result: \(result.isSuccess ? "成功" : "业务失败")\n"
            text += "Business Code: \(result.code)\n"
            text += "Business Message: \(result.message)\n"
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
