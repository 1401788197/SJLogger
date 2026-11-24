import Foundation

/// 仅在配置允许的范围内缓存响应体，避免大下载把完整内容留在内存中。
struct SJResponseBodyBuffer {
    let limit: Int
    private(set) var data = Data()
    private(set) var exceededLimit = false

    init(limit: Int) {
        self.limit = max(0, limit)
    }

    mutating func append(_ chunk: Data) {
        guard !exceededLimit, !chunk.isEmpty else { return }
        if limit > 0 && (data.count > limit || chunk.count > limit - data.count) {
            data.removeAll(keepingCapacity: false)
            exceededLimit = true
            return
        }
        data.append(chunk)
    }

    var capturedData: Data? {
        guard !exceededLimit, !data.isEmpty else { return nil }
        return data
    }
}

// MARK: - 网络请求拦截器
/// 基于URLProtocol的网络请求拦截器，用于捕获所有网络请求
public class SJURLProtocol: URLProtocol {
    
    private static let requestHandledKey = "SJURLProtocolHandled"
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var responseBodyBuffer: SJResponseBodyBuffer?
    private var currentLogID: String?
    private var hasForwardedRedirect = false
    private var hasStopped = false
    private let stateLock = NSLock()
    
    // MARK: - URLProtocol Override
    
    /// 判断是否需要处理该请求
    public override class func canInit(with request: URLRequest) -> Bool {
        // 避免重复处理
        if URLProtocol.property(forKey: requestHandledKey, in: request) != nil {
            return false
        }
        
        // 只处理 URLSession 的 HTTP(S) 请求，其他协议由系统或对应库处理。
        guard let url = request.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        return SJLoggerConfig.shared.shouldMonitor(url: url.absoluteString)
    }
    
    /// 返回规范化的请求
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    /// 开始加载
    public override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        
        // 标记已处理
        URLProtocol.setProperty(true, forKey: SJURLProtocol.requestHandledKey, in: mutableRequest)

        let config = SJLoggerConfig.shared
        let requestBody = Self.captureRequestBody(from: mutableRequest,
                                                  enabled: config.logRequestBody)
        
        // 创建日志记录
        let log = createLog(from: mutableRequest as URLRequest, requestBody: requestBody)
        stateLock.lock()
        currentLogID = log.id
        hasForwardedRedirect = false
        responseBodyBuffer = config.logResponseBody
            ? SJResponseBodyBuffer(limit: config.maxResponseBodySize)
            : nil
        stateLock.unlock()
        SJLoggerStorage.shared.addLog(log)
        
        // 创建会话
        let configuration = URLSessionConfiguration.default
        let activeSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        // 创建任务
        let task = activeSession.dataTask(with: mutableRequest as URLRequest)
        stateLock.lock()
        session = activeSession
        dataTask = task
        stateLock.unlock()
        task.resume()
    }
    
    /// 停止加载
    public override func stopLoading() {
        // 先认领终态，再取消底层任务，防止取消回调抢先覆盖来源。
        stateLock.lock()
        let response = dataTask?.response
        stateLock.unlock()
        finishCurrentLog(with: response, error: URLError(.cancelled),
                         cancellationSource: "URLProtocol.stopLoading", stopping: true)
        stateLock.lock()
        let task = dataTask
        let activeSession = session
        dataTask = nil
        session = nil
        stateLock.unlock()

        task?.cancel()
        activeSession?.invalidateAndCancel()
    }
    
    // MARK: - Helper Methods
    
    /// 创建日志对象
    private func createLog(from request: URLRequest, requestBody: Data?) -> SJLoggerModel {
        let url = request.url?.absoluteString ?? ""
        let methodString = request.httpMethod ?? "GET"
        let method = SJHTTPMethod(rawValue: methodString.uppercased()) ?? .get
        
        // 判断类型
        let type: SJLogType
        if url.hasPrefix("https") {
            type = .https
        } else if url.hasPrefix("http") {
            type = .http
        } else if url.hasPrefix("ws") {
            type = .websocket
        } else {
            type = .http
        }
        
        // 获取请求头
        var headers: [String: String] = [:]
        if let allHeaders = request.allHTTPHeaderFields {
            headers = allHeaders
        }
        
        return SJLoggerModel(
            type: type,
            url: url,
            method: method,
            requestHeaders: headers,
            requestBody: requestBody,
            startTime: Date()
        )
    }

    /// 读取流式请求体后将数据回填到转发请求，避免采集动作消费原始 InputStream。
    static func captureRequestBody(from request: NSMutableURLRequest, enabled: Bool) -> Data? {
        guard enabled else { return nil }
        if let body = request.httpBody {
            return body
        }
        guard let body = request.httpBodyStream?.readData() else { return nil }
        request.httpBodyStream = nil
        request.httpBody = body
        return body
    }

    /// 重定向交回外层 URLProtocol 系统前移除内部标记，让新地址可以再次被记录。
    static func requestForFollowingRedirect(_ request: URLRequest) -> URLRequest {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        URLProtocol.removeProperty(forKey: requestHandledKey, in: mutableRequest)
        return mutableRequest as URLRequest
    }

    private func appendResponseData(_ data: Data) {
        stateLock.lock()
        if !hasForwardedRedirect && !hasStopped && currentLogID != nil {
            responseBodyBuffer?.append(data)
        }
        stateLock.unlock()
    }

    private func shouldForwardClientCallbacks(completing: Bool = false) -> Bool {
        stateLock.lock()
        let shouldForward = !hasForwardedRedirect && !hasStopped && (completing || currentLogID != nil)
        stateLock.unlock()
        return shouldForward
    }

    private func markRedirectAsForwarded() {
        stateLock.lock()
        hasForwardedRedirect = true
        stateLock.unlock()
    }

    /// stop、redirect 和 completion 可能紧邻发生；只允许其中一个结束并写回日志。
    @discardableResult
    private func finishCurrentLog(with response: URLResponse?, error: Error?,
                                  cancellationSource: String? = nil, stopping: Bool = false) -> Bool {
        stateLock.lock()
        if stopping { hasStopped = true }
        guard let logID = currentLogID else {
            stateLock.unlock()
            return false
        }
        let data = responseBodyBuffer?.capturedData
        currentLogID = nil
        responseBodyBuffer = nil
        stateLock.unlock()

        updateLog(logID: logID, with: response, data: data, error: error, cancellationSource: cancellationSource)
        return true
    }

    private func releaseSession(_ completedSession: URLSession) {
        stateLock.lock()
        if session === completedSession {
            session = nil
            dataTask = nil
        }
        stateLock.unlock()
        completedSession.finishTasksAndInvalidate()
    }
    
    /// 更新日志响应信息
    private func updateLog(logID: String, with response: URLResponse?, data: Data?, error: Error?, cancellationSource: String?) {
        let endTime = Date()
        var statusCode: Int?
        var responseHeaders: [String: String]?
        if let httpResponse = response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            var headers: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                headers[String(describing: key)] = String(describing: value)
            }
            responseHeaders = headers
        }

        let nsError = error as NSError?
        SJLoggerStorage.shared.updateLog(byId: logID) { log in
            log.endTime = endTime
            log.statusCode = statusCode
            log.responseHeaders = responseHeaders
            log.error = error?.localizedDescription
            log.errorDomain = nsError?.domain
            log.errorCode = nsError?.code
            log.cancellationSource = log.isCancelled ? (cancellationSource ?? "URLSession.didCompleteWithError") : nil
            log.responseBody = data
        }
    }
}

// MARK: - URLSessionDataDelegate
extension SJURLProtocol: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard shouldForwardClientCallbacks() else {
            completionHandler(.cancel)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard shouldForwardClientCallbacks() else { return }
        appendResponseData(data)
        client?.urlProtocol(self, didLoad: data)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 必须在通知外层之前提交结果；外层回调可能同步触发 stopLoading。
        let didFinish = finishCurrentLog(with: task.response, error: error)
        if didFinish && shouldForwardClientCallbacks(completing: true) {
            if let error = error {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }
        }
        
        releaseSession(session)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard finishCurrentLog(with: response, error: nil) else {
            completionHandler(nil)
            return
        }
        markRedirectAsForwarded()
        let redirectedRequest = Self.requestForFollowingRedirect(request)
        client?.urlProtocol(self, wasRedirectedTo: redirectedRequest, redirectResponse: response)
        completionHandler(nil)
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        completionHandler(disposition, nil)
    }
}

// MARK: - InputStream Extension
extension InputStream {
    /// 读取流数据
    func readData() -> Data? {
        open()
        defer { close() }
        
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var data = Data()
        while hasBytesAvailable {
            let bytesRead = read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        
        return data.isEmpty ? nil : data
    }
}
