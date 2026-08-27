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

    /// 当前展示中的日志页面，用于避免连续点击叠加多个全屏页面
    private weak var presentedLogListNavigationController: UINavigationController?

    /// `present` 动画完成前阻止重复发起展示
    private var isPresentingLogList = false
    
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

        // stop() 会恢复 Swizzling；再次 start() 时必须重新注入 URLProtocol。
        SJURLSessionSwizzler.shared.swizzle()
        
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
        DispatchQueue.main.async { [weak self, weak viewController] in
            self?.presentLogList(from: viewController)
        }
    }
    
    /// 显示设置界面
    /// - Parameter from: 从哪个视图控制器present
    public func showSettings(from viewController: UIViewController? = nil) {
        DispatchQueue.main.async {
            let settingsVC = SJLoggerSettingsViewController()
            let nav = UINavigationController(rootViewController: settingsVC)
            nav.setNavigationBarHidden(true, animated: false)
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
    
    /// 清除当前内存日志，持久化日志需在设置页主动清除
    public func clearLogs() {
        SJLoggerStorage.shared.clearCurrentLogs()
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

    private func presentLogList(from viewController: UIViewController?) {
        if let current = presentedLogListNavigationController,
           current.presentingViewController != nil || current.viewIfLoaded?.window != nil {
            return
        }

        guard !isPresentingLogList,
              let presenter = viewController.map({ findTopViewController(from: $0) }) ?? topViewController(),
              presenter.viewIfLoaded?.window != nil else {
            return
        }

        // UIKit 不允许在另一个 present/dismiss 动画中稳定地发起新转场。
        // 等当前转场完成后重新解析顶部控制器，避免展示到正在消失的页面上。
        if let coordinator = presenter.transitionCoordinator {
            isPresentingLogList = true
            coordinator.animate(alongsideTransition: nil) { [weak self, weak viewController] _ in
                self?.isPresentingLogList = false
                self?.showLogList(from: viewController)
            }
            return
        }

        guard !presenter.isBeingPresented,
              !presenter.isBeingDismissed,
              presenter.presentedViewController == nil else {
            return
        }

        let logListVC = SJLogListViewController()
        let nav = UINavigationController(rootViewController: logListVC)
        nav.modalPresentationStyle = .fullScreen
        nav.setNavigationBarHidden(true, animated: false)

        isPresentingLogList = true
        presentedLogListNavigationController = nav
        presenter.present(nav, animated: true)

        // present 失败时 UIKit 不保证调用完成回调，下一轮主线程主动释放尝试状态。
        DispatchQueue.main.async { [weak self, weak nav] in
            self?.isPresentingLogList = false
            if nav?.presentingViewController == nil && nav?.viewIfLoaded?.window == nil {
                self?.presentedLogListNavigationController = nil
            }
        }
    }
    
    private func topViewController() -> UIViewController? {
        // 悬浮按钮可能属于多个 Scene 中的任意一个，优先使用它实际所在的窗口。
        let floatingWindowHost = floatingWindow?.window
        let foregroundWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
        let window = floatingWindowHost
            ?? foregroundWindows.first(where: { $0.isKeyWindow })
            ?? foregroundWindows.first(where: { !$0.isHidden && $0.alpha > 0 })

        guard let rootVC = window?.rootViewController else {
            return nil
        }
        
        return findTopViewController(from: rootVC)
    }
    
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController,
           !presented.isBeingDismissed {
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

        if let split = viewController as? UISplitViewController,
           let last = split.viewControllers.last {
            return findTopViewController(from: last)
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
    
    /// 设置默认刷新模式（动态/固定）
    func setRefreshMode(_ mode: SJRefreshMode) {
        config.defaultRefreshMode = mode
    }
    
    /// 启用/禁用日志持久化（App重启不丢失）
    func setPersistLogs(_ enabled: Bool) {
        config.persistLogs = enabled
    }
    
    /// 设置 AES-CBC-PKCS7 请求/响应体解密器
    func setAESBodyDecryptor(key: String, iv: String? = nil) {
        config.setAESBodyDecryptor(key: key, iv: iv)
    }
    
    /// 设置自定义请求/响应体解密器
    func setBodyDecryptor(_ decryptor: ((Data) -> String?)?) {
        config.setBodyDecryptor(decryptor)
    }
    
    /// 导出所有日志为 HAR 格式
    func exportHAR(completion: @escaping (String) -> Void) {
        SJLoggerStorage.shared.getAllLogs { logs in
            completion(SJLogExporter.har(for: logs))
        }
    }
}
