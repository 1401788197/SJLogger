import Foundation

// MARK: - URLSession方法交换
/// 通过Method Swizzling自动注入SJURLProtocol到所有URLSession配置中
class SJURLSessionSwizzler {
    
    static let shared = SJURLSessionSwizzler()
    private var isSwizzled = false
    
    private init() {}
    
    /// 开始方法交换
    func swizzle() {
        guard !isSwizzled else { return }
        
        // 交换URLSessionConfiguration的init方法
        swizzleURLSessionConfiguration()
        
        isSwizzled = true
    }
    
    /// 停止方法交换（恢复原始实现）
    func unswizzle() {
        guard isSwizzled else { return }
        
        // 再次调用会恢复原始方法
        swizzleURLSessionConfiguration()
        
        isSwizzled = false
    }
    
    // MARK: - Private Methods
    
    private func swizzleURLSessionConfiguration() {
        // Swizzle default configuration
        swizzleMethod(
            class: URLSessionConfiguration.self,
            original: #selector(getter: URLSessionConfiguration.default),
            swizzled: #selector(getter: URLSessionConfiguration.sj_default)
        )
        
        // Swizzle ephemeral configuration
        swizzleMethod(
            class: URLSessionConfiguration.self,
            original: #selector(getter: URLSessionConfiguration.ephemeral),
            swizzled: #selector(getter: URLSessionConfiguration.sj_ephemeral)
        )
    }
    
    private func swizzleMethod(class: AnyClass, original: Selector, swizzled: Selector) {
        guard let originalMethod = class_getClassMethod(`class`, original),
              let swizzledMethod = class_getClassMethod(`class`, swizzled) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

// MARK: - URLSessionConfiguration Extension
extension URLSessionConfiguration {
    
    @objc class var sj_default: URLSessionConfiguration {
        let configuration = self.sj_default // 调用原始方法
        configuration.sj_injectProtocol()
        return configuration
    }
    
    @objc class var sj_ephemeral: URLSessionConfiguration {
        let configuration = self.sj_ephemeral // 调用原始方法
        configuration.sj_injectProtocol()
        return configuration
    }
    
    /// 注入SJURLProtocol到配置中
    private func sj_injectProtocol() {
        guard SJLoggerConfig.shared.isEnabled else { return }
        
        var protocols = self.protocolClasses ?? []
        
        // 检查是否已经包含SJURLProtocol
        let hasSJProtocol = protocols.contains { $0 is SJURLProtocol.Type }
        
        if !hasSJProtocol {
            protocols.insert(SJURLProtocol.self, at: 0)
            self.protocolClasses = protocols
        }
    }
}
