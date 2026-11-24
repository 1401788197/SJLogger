import Foundation

// MARK: - 日志导出器
/// 将日志导出为 cURL 命令或 HAR(HTTP Archive) 格式
public enum SJLogExporter {
    
    public enum FileFormat: String {
        case text = "txt"
        case har = "har"
    }

    /// 将指定日志写成独立文件，返回可直接交给系统分享面板的 file URL。
    public static func exportFile(for logs: [SJLoggerModel], format: FileFormat = .text) throws -> URL {
        guard !logs.isEmpty else {
            throw NSError(domain: "SJLogger.Export", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "没有日志可导出"])
        }
        return try writeFile(contents: format == .har ? har(for: logs) : text(for: logs), format: format)
    }

    public static func text(for logs: [SJLoggerModel]) -> String {
        var text = "========== SJLogger 日志导出 ==========\n"
        text += "导出时间: \(ISO8601DateFormatter().string(from: Date()))\n"
        text += "日志数量: \(logs.count)\n\n"
        for (index, log) in logs.enumerated() {
            text += "[\(index + 1)/\(logs.count)]\n"
            text += log.generateLogText()
            text += "\n"
        }
        return text
    }

    /// 独立文件名避免多次分享相互覆盖。分享结束不立即删文件，留给接收扩展读取。
    static func writeFile(contents: String, format: FileFormat,
                          directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("SJLogger-Exports", isDirectory: true)) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        // 只回收本导出目录中的过期附件，保留最近 7 天文件供接收方异步读取。
        let expiry = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let oldFiles = (try? manager.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])) ?? []
        for file in oldFiles where file.lastPathComponent.hasPrefix("SJLogger-")
            && ["txt", "har"].contains(file.pathExtension) {
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
               values.isRegularFile == true, let date = values.contentModificationDate, date < expiry {
                try? manager.removeItem(at: file)
            }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "SJLogger-\(formatter.string(from: Date()))-\(UUID().uuidString).\(format.rawValue)"
        let url = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url, options: .atomic)
        return url
    }

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
                "creator": ["name": "SJLogger", "version": "0.6.0"],
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
        
        var entry: [String: Any] = [
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
        entry["_cancelled"] = log.isCancelled
        if let error = log.error { entry["_error"] = error }
        if let domain = log.errorDomain { entry["_errorDomain"] = domain }
        if let code = log.errorCode { entry["_errorCode"] = code }
        if let source = log.cancellationSource { entry["_cancellationSource"] = source }
        if let result = log.businessResult {
            entry["_businessResult"] = ["code": result.code, "message": result.message, "isSuccess": result.isSuccess]
        }
        return entry
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
