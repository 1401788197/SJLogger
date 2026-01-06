import Foundation

// MARK: - 网络请求拦截器
/// 基于URLProtocol的网络请求拦截器，用于捕获所有网络请求
public class SJURLProtocol: URLProtocol {
    
    private static let requestHandledKey = "SJURLProtocolHandled"
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var responseData: Data?
    private var currentLog: SJLoggerModel?
    
    // MARK: - URLProtocol Override
    
    /// 判断是否需要处理该请求
    public override class func canInit(with request: URLRequest) -> Bool {
        // 避免重复处理
        if URLProtocol.property(forKey: requestHandledKey, in: request) != nil {
            return false
        }
        
        // 检查是否需要监控
        guard let url = request.url?.absoluteString else { return false }
        return SJLoggerConfig.shared.shouldMonitor(url: url)
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
        
        // 创建日志记录
        let log = createLog(from: request)
        currentLog = log
        SJLoggerStorage.shared.addLog(log)
        
        // 创建会话
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        // 创建任务
        dataTask = session?.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }
    
    /// 停止加载
    public override func stopLoading() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
    }
    
    // MARK: - Helper Methods
    
    /// 创建日志对象
    private func createLog(from request: URLRequest) -> SJLoggerModel {
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
        
        // 获取请求体
        var body: Data?
        if SJLoggerConfig.shared.logRequestBody {
            body = request.httpBody ?? request.httpBodyStream?.readData()
        }
        
        return SJLoggerModel(
            type: type,
            url: url,
            method: method,
            requestHeaders: headers,
            requestBody: body,
            startTime: Date()
        )
    }
    
    /// 更新日志响应信息
    private func updateLog(with response: URLResponse?, data: Data?, error: Error?) {
        guard var log = currentLog else { return }
        
        log.endTime = Date()
        
        if let httpResponse = response as? HTTPURLResponse {
            log.statusCode = httpResponse.statusCode
            
            var headers: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let key = key as? String, let value = value as? String {
                    headers[key] = value
                }
            }
            log.responseHeaders = headers
        }
        
        if let error = error {
            log.error = error.localizedDescription
        }
        
        if let data = data, SJLoggerConfig.shared.logResponseBody {
            let maxSize = SJLoggerConfig.shared.maxResponseBodySize
            if maxSize == 0 || data.count <= maxSize {
                log.responseBody = data
            }
        }
        
        SJLoggerStorage.shared.updateLog(log)
    }
}

// MARK: - URLSessionDataDelegate
extension SJURLProtocol: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if responseData == nil {
            responseData = Data()
        }
        responseData?.append(data)
        client?.urlProtocol(self, didLoad: data)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
        
        updateLog(with: task.response, data: responseData, error: error)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        completionHandler(request)
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
