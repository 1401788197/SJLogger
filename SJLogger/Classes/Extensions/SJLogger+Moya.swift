import Foundation

#if canImport(Moya)
import Moya

// MARK: - Moya集成扩展
/// 为Moya提供便捷的集成方法
public extension SJLogger {
    
    /// 创建支持SJLogger的Moya Session
    /// - Returns: 配置了SJURLProtocol的URLSession
    static func createMoyaSession() -> Session {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [SJURLProtocol.self] + (configuration.protocolClasses ?? [])
        return Session(configuration: configuration)
    }
    
    /// 创建支持SJLogger的Moya Session配置
    /// - Returns: 配置了SJURLProtocol的URLSessionConfiguration
    static func createMoyaConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [SJURLProtocol.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
}

// MARK: - MoyaProvider扩展
public extension MoyaProvider {
    
    /// 创建支持SJLogger的MoyaProvider
    /// - Parameters:
    ///   - endpointClosure: endpoint闭包
    ///   - requestClosure: request闭包
    ///   - stubClosure: stub闭包
    ///   - callbackQueue: 回调队列
    ///   - plugins: 插件数组
    ///   - trackInflights: 是否跟踪进行中的请求
    /// - Returns: 配置了SJLogger的MoyaProvider
    static func withSJLogger(
        endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
        requestClosure: @escaping RequestClosure = MoyaProvider.defaultRequestMapping,
        stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
        callbackQueue: DispatchQueue? = nil,
        session: Session = SJLogger.createMoyaSession(),
        plugins: [PluginType] = [],
        trackInflights: Bool = false
    ) -> MoyaProvider<Target> {
        return MoyaProvider<Target>(
            endpointClosure: endpointClosure,
            requestClosure: requestClosure,
            stubClosure: stubClosure,
            callbackQueue: callbackQueue,
            session: session,
            plugins: plugins,
            trackInflights: trackInflights
        )
    }
}

#endif
