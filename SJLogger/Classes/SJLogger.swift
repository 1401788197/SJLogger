import Foundation
import UIKit

// MARK: - SJLogger主类
/// SJLogger框架的主入口类，提供初始化和控制功能
public class SJLogger {
    
    /// 单例
    public static let shared = SJLogger()
    
    /// 是否已启动
    private(set) var isStarted = false
    
    /// 悬浮窗
    private var floatingWindow: SJFloatingWindow?
    
    private init() {
        // 在初始化时就执行Swizzling，确保即使延迟调用start()也能监听到请求
        SJURLSessionSwizzler.shared.swizzle()
    }
    
    // MARK: - 启动和停止
    
    /// 启动SJLogger
    /// - Parameter config: 配置闭包，可选
    /// - Note: 可以多次调用，内部会自动处理重复调用逻辑
    public func start(config: ((SJLoggerConfig) -> Void)? = nil) {
        // 应用配置（每次都允许更新配置）
        if let config = config {
            config(SJLoggerConfig.shared)
        }
        
        // 如果已经启动，只更新悬浮窗状态
        if isStarted {
            if SJLoggerConfig.shared.showFloatingWindow {
                showFloatingWindow()
            } else {
                hideFloatingWindow()
            }
            print("[SJLogger] Configuration updated")
            return
        }
        
        // 首次启动：注册URLProtocol
        URLProtocol.registerClass(SJURLProtocol.self)
        
        // 显示悬浮窗
        if SJLoggerConfig.shared.showFloatingWindow {
            showFloatingWindow()
        }
        
        isStarted = true
        print("[SJLogger] Started successfully - All network requests will be monitored")
    }
    
    /// 停止SJLogger
    public func stop() {
        guard isStarted else {
            print("[SJLogger] Not started yet")
            return
        }
        
        // 注销URLProtocol
        URLProtocol.unregisterClass(SJURLProtocol.self)
        
        // 恢复Method Swizzling
        SJURLSessionSwizzler.shared.unswizzle()
        
        // 隐藏悬浮窗
        hideFloatingWindow()
        
        isStarted = false
        print("[SJLogger] Stopped")
    }
    
    // MARK: - 悬浮窗控制
    
    /// 显示悬浮窗
    public func showFloatingWindow() {
        if floatingWindow == nil {
            floatingWindow = SJFloatingWindow()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.floatingWindow?.show()
        }
    }
    
    /// 隐藏悬浮窗
    public func hideFloatingWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.floatingWindow?.hide()
            self?.floatingWindow = nil
        }
    }
    
    // MARK: - 显示日志界面
    
    /// 显示日志列表界面
    /// - Parameter from: 从哪个视图控制器present
    public func showLogList(from viewController: UIViewController? = nil) {
        DispatchQueue.main.async {
            let logListVC = SJLogListViewController()
            let nav = UINavigationController(rootViewController: logListVC)
            nav.modalPresentationStyle = .fullScreen
            
            if let vc = viewController {
                vc.present(nav, animated: true)
            } else if let topVC = self.topViewController() {
                topVC.present(nav, animated: true)
            }
        }
    }
    
    // MARK: - 配置访问
    
    /// 获取配置对象
    public var config: SJLoggerConfig {
        return SJLoggerConfig.shared
    }
    
    /// 获取存储对象
    public var storage: SJLoggerStorage {
        return SJLoggerStorage.shared
    }
    
    // MARK: - 便捷方法
    
    /// 清除所有日志
    public func clearLogs() {
        SJLoggerStorage.shared.clearAllLogs()
    }
    
    /// 导出所有日志
    /// - Parameter completion: 完成回调，返回日志文本
    public func exportLogs(completion: @escaping (String) -> Void) {
        SJLoggerStorage.shared.exportLogsAsText(completion: completion)
    }
    
    /// 获取日志统计
    /// - Parameter completion: 完成回调
    public func getStatistics(completion: @escaping ([String: Any]) -> Void) {
        SJLoggerStorage.shared.getStatistics(completion: completion)
    }
    
    // MARK: - 辅助方法
    
    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return nil
        }
        
        return findTopViewController(from: rootVC)
    }
    
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return findTopViewController(from: presented)
        }
        
        if let nav = viewController as? UINavigationController,
           let visible = nav.visibleViewController {
            return findTopViewController(from: visible)
        }
        
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return findTopViewController(from: selected)
        }
        
        return viewController
    }
}

// MARK: - 便捷扩展
public extension SJLogger {
    
    /// 添加监控URL模式
    func addMonitoredURL(_ pattern: String) {
        config.addMonitoredURL(pattern: pattern)
    }
    
    /// 添加忽略URL模式
    func addIgnoredURL(_ pattern: String) {
        config.addIgnoredURL(pattern: pattern)
    }
    
    /// 启用/禁用日志记录
    func setEnabled(_ enabled: Bool) {
        config.isEnabled = enabled
    }
    
    /// 启用/禁用WebSocket日志
    func setWebSocketLogEnabled(_ enabled: Bool) {
        config.enableWebSocketLog = enabled
    }
}
