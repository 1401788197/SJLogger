import Foundation

// MARK: - 日志导出器
/// 将日志导出为 cURL 命令或 HAR(HTTP Archive) 格式
public enum SJLogExporter {
    
    // MARK: - cURL
    
    /// 将单条日志转为 cURL 命令
    public static func curl(for log: SJLoggerModel) -> String {
        var parts: [String] = ["curl"]
        
        // 方法
        if let method = log.method, method != .get {
            parts.append("-X \(method.rawValue)")
        }
        
        // URL
        parts.append("'\(log.url)'")
        
        // 请求头
        if let headers = log.requestHeaders {
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
                parts.append("-H '\(key): \(escaped)'")
            }
        }
        
        // 请求体
        if let body = log.requestBodyString, !body.isEmpty {
            let escaped = body.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("--data '\(escaped)'")
        }
        
        return parts.joined(separator: " \\\n  ")
    }
    
    // MARK: - HAR
    
    /// 将一组日志导出为 HAR JSON 字符串
    public static func har(for logs: [SJLoggerModel]) -> String {
        let entries: [[String: Any]] = logs.map { harEntry(for: $0) }
        let har: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": ["name": "SJLogger", "version": "0.4.0"],
                "entries": entries
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: har, options: [.prettyPrinted]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
    
    private static func harEntry(for log: SJLoggerModel) -> [String: Any] {
        let iso = ISO8601DateFormatter()
        
        let reqHeaders = (log.requestHeaders ?? [:]).map { ["name": $0.key, "value": $0.value] }
        let respHeaders = (log.responseHeaders ?? [:]).map { ["name": $0.key, "value": $0.value] }
        
        var request: [String: Any] = [
            "method": log.method?.rawValue ?? "GET",
            "url": log.url,
            "httpVersion": "HTTP/1.1",
            "headers": reqHeaders,
            "queryString": [],
            "headersSize": -1,
            "bodySize": log.requestBody?.count ?? 0
        ]
        if let body = log.requestBodyString {
            request["postData"] = [
                "mimeType": log.requestHeaders?["Content-Type"] ?? "application/json",
                "text": body
            ]
        }
        
        let response: [String: Any] = [
            "status": log.statusCode ?? 0,
            "statusText": "",
            "httpVersion": "HTTP/1.1",
            "headers": respHeaders,
            "content": [
                "size": log.responseSize,
                "mimeType": log.responseHeaders?["Content-Type"] ?? "application/json",
                "text": log.responseBodyString ?? ""
            ],
            "redirectURL": "",
            "headersSize": -1,
            "bodySize": log.responseSize
        ]
        
        return [
            "startedDateTime": iso.string(from: log.startTime),
            "time": log.duration ?? 0,
            "request": request,
            "response": response,
            "cache": [:],
            "timings": [
                "send": 0,
                "wait": log.duration ?? 0,
                "receive": 0
            ]
        ]
    }
}
