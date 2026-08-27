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
        parts.append(shellQuoted(log.url))
        
        // 请求头
        if let headers = log.requestHeaders {
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                parts.append("-H \(shellQuoted("\(key): \(value)"))")
            }
        }
        
        // 请求体
        if let body = log.requestBodyString, !body.isEmpty {
            parts.append("--data \(shellQuoted(body))")
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
                "creator": ["name": "SJLogger", "version": "0.5.0"],
                "entries": entries
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: har, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
    
    private static func harEntry(for log: SJLoggerModel) -> [String: Any] {
        let iso = ISO8601DateFormatter()
        
        let reqHeaders = sortedHeaders(log.requestHeaders)
        let respHeaders = sortedHeaders(log.responseHeaders)
        let queryItems = URLComponents(string: log.url)?.queryItems?.map {
            ["name": $0.name, "value": $0.value ?? ""]
        } ?? []
        
        var request: [String: Any] = [
            "method": log.method?.rawValue ?? "GET",
            "url": log.url,
            "httpVersion": "HTTP/1.1",
            "headers": reqHeaders,
            "queryString": queryItems,
            "cookies": [],
            "headersSize": -1,
            "bodySize": log.requestBody?.count ?? 0
        ]
        if let body = log.requestBodyString {
            request["postData"] = [
                "mimeType": headerValue(named: "Content-Type", in: log.requestHeaders) ?? "application/octet-stream",
                "text": body
            ]
        }
        
        let response: [String: Any] = [
            "status": log.statusCode ?? 0,
            "statusText": "",
            "httpVersion": "HTTP/1.1",
            "headers": respHeaders,
            "cookies": [],
            "content": [
                "size": log.responseSize,
                "mimeType": headerValue(named: "Content-Type", in: log.responseHeaders) ?? "application/octet-stream",
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

    private static func shellQuoted(_ value: String) -> String {
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func sortedHeaders(_ headers: [String: String]?) -> [[String: String]] {
        return (headers ?? [:])
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { ["name": $0.key, "value": $0.value] }
    }

    private static func headerValue(named name: String, in headers: [String: String]?) -> String? {
        return headers?.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}
