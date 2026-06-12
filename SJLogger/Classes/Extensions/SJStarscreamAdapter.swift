import Foundation

#if canImport(Starscream)
import Starscream

// MARK: - Starscream 适配器
/// 近似零埋点：包裹原有 WebSocketDelegate，先记录事件再透传。
///
/// 用法（只改一行 delegate 赋值）：
/// ```
/// let proxy = SJLogger.starscreamProxy(url: "wss://example.com/ws", forwarding: self)
/// socket.delegate = proxy   // 持有 proxy，避免被释放
/// ```
public final class SJStarscreamProxy: WebSocketDelegate {
    
    private let url: String
    private weak var forwarding: WebSocketDelegate?
    
    public init(url: String, forwarding: WebSocketDelegate?) {
        self.url = url
        self.forwarding = forwarding
    }
    
    public func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        // 先记录
        if let mapped = SJStarscreamProxy.map(event) {
            SJLogger.logWebSocket(url: url, event: mapped)
        }
        // 再透传给业务原本的 delegate
        forwarding?.didReceive(event: event, client: client)
    }
    
    /// 将 Starscream 的 WebSocketEvent 映射为 SJWebSocketEvent
    private static func map(_ event: WebSocketEvent) -> SJWebSocketEvent? {
        switch event {
        case .connected(let headers):
            return .connected(headers)
        case .disconnected(let reason, let code):
            return .disconnected(reason, code)
        case .text(let text):
            return .text(text)
        case .binary(let data):
            return .binary(data)
        case .pong(let data):
            return .pong(data)
        case .ping(let data):
            return .ping(data)
        case .error(let error):
            return .error(error)
        case .viabilityChanged(let isViable):
            return .viabilityChanged(isViable)
        case .reconnectSuggested(let suggest):
            return .reconnectSuggested(suggest)
        case .cancelled:
            return .cancelled
        case .peerClosed:
            return .peerClosed
        @unknown default:
            return nil
        }
    }
}

// MARK: - 便捷入口
public extension SJLogger {
    
    /// 创建一个 Starscream 代理委托，自动记录所有事件并透传给原 delegate。
    /// - Parameters:
    ///   - url: WebSocket 连接地址（用于在日志中标识接口）
    ///   - forwarding: 业务原本的 WebSocketDelegate（可为 nil）
    /// - Returns: 赋值给 `socket.delegate` 的代理对象（注意持有它）
    static func starscreamProxy(url: String, forwarding: WebSocketDelegate?) -> SJStarscreamProxy {
        return SJStarscreamProxy(url: url, forwarding: forwarding)
    }
}

#endif
