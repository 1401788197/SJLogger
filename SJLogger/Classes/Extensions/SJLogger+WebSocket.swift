import Foundation

// MARK: - WebSocket事件枚举
/// WebSocket事件类型（兼容Starscream等WebSocket库）
public enum SJWebSocketEvent {
    case connected([String: String])
    case disconnected(String, UInt16)
    case text(String)
    case binary(Data)
    case pong(Data?)
    case ping(Data?)
    case error(Error?)
    case viabilityChanged(Bool)
    case reconnectSuggested(Bool)
    case cancelled
    case peerClosed
}

// MARK: - WebSocket日志记录扩展
/// 提供简单的WebSocket日志记录API，无需依赖任何第三方库
public extension SJLogger {
    
    /// 记录WebSocket事件（统一入口）
    /// - Parameters:
    ///   - url: WebSocket连接URL
    ///   - event: WebSocket事件
    static func logWebSocket(url: String, event: SJWebSocketEvent) {
        // 检查是否启用WebSocket日志
        guard SJLoggerConfig.shared.enableWebSocketLog else { return }
        
        switch event {
        case .connected(let headers):
            logConnected(url: url, headers: headers)
            
        case .disconnected(let reason, let code):
            logDisconnected(url: url, reason: reason, code: code)
            
        case .text(let message):
            logTextMessage(url: url, message: message)
            
        case .binary(let data):
            logBinaryData(url: url, data: data)
            
        case .error(let error):
            logError(url: url, error: error)
            
        case .pong(let data):
            logPong(url: url, data: data)
            
        case .ping(let data):
            logPing(url: url, data: data)
            
        case .viabilityChanged(let isViable):
            logViabilityChanged(url: url, isViable: isViable)
            
        case .reconnectSuggested(let shouldReconnect):
            logReconnectSuggested(url: url, shouldReconnect: shouldReconnect)
            
        case .cancelled:
            logCancelled(url: url)
            
        case .peerClosed:
            logPeerClosed(url: url)
        }
    }
    
    // MARK: - 内部处理方法
    
    private static func logConnected(url: String, headers: [String: String]) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        log.statusCode = 101
        log.responseHeaders = headers
        log.tcpInfo = "WebSocket Connected"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logDisconnected(url: String, reason: String, code: UInt16) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        log.statusCode = Int(code)
        log.error = reason.isEmpty ? nil : reason
        log.tcpInfo = "WebSocket Disconnected - Code: \(code), Reason: \(reason)"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logTextMessage(url: String, message: String) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        log.responseBody = message.data(using: .utf8)
        log.statusCode = 200
        log.tcpInfo = "WebSocket Message (Text) - Length: \(message.count)"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logBinaryData(url: String, data: Data) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        log.responseBody = data
        log.statusCode = 200
        log.tcpInfo = "WebSocket Message (Binary) - Size: \(data.count) bytes"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logError(url: String, error: Error?) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        log.statusCode = 0
        log.error = errorMessage
        log.tcpInfo = "WebSocket Error: \(errorMessage)"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logPong(url: String, data: Data?) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: data,
            startTime: Date()
        )
        
        log.statusCode = 200
        log.tcpInfo = "WebSocket Pong - Size: \(data?.count ?? 0) bytes"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logPing(url: String, data: Data?) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: data,
            startTime: Date()
        )
        
        log.statusCode = 200
        log.tcpInfo = "WebSocket Ping - Size: \(data?.count ?? 0) bytes"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logViabilityChanged(url: String, isViable: Bool) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        log.statusCode = 0
        log.tcpInfo = "WebSocket Viability Changed: \(isViable ? "Viable" : "Not Viable")"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logReconnectSuggested(url: String, shouldReconnect: Bool) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        log.statusCode = 0
        log.tcpInfo = "WebSocket Reconnect Suggested: \(shouldReconnect)"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logCancelled(url: String) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        log.statusCode = 0
        log.error = "Cancelled"
        log.tcpInfo = "WebSocket Cancelled"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
    
    private static func logPeerClosed(url: String) {
        let log = SJLoggerModel(
            id: UUID().uuidString,
            type: .websocket,
            url: url,
            method: nil,
            requestHeaders: nil,
            requestBody: nil,
            startTime: Date()
        )
        
        log.statusCode = 1000
        log.tcpInfo = "WebSocket Peer Closed"
        log.endTime = Date()
        
        SJLoggerStorage.shared.addLog(log)
    }
}
