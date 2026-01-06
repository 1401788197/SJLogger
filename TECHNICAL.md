# SJLogger 技术实现说明

## 核心技术

### 1. URLProtocol 拦截机制

SJLogger 使用 `URLProtocol` 作为核心拦截技术：

```swift
public class SJURLProtocol: URLProtocol {
    // 判断是否需要处理该请求
    public override class func canInit(with request: URLRequest) -> Bool
    
    // 开始加载请求
    public override func startLoading()
    
    // 停止加载
    public override func stopLoading()
}
```

**优点**：
- Apple官方提供的API，稳定可靠
- 可以拦截所有基于URLSession的请求
- 可以修改请求和响应

**限制**：
- 只能拦截URLSession的请求
- 需要注册到URLSessionConfiguration中

### 2. Method Swizzling 自动注入

为了解决第三方SDK使用自定义URLSessionConfiguration的问题，SJLogger 使用 Method Swizzling 技术：

```swift
class SJURLSessionSwizzler {
    func swizzle() {
        // 交换 URLSessionConfiguration.default 的实现
        swizzleMethod(
            class: URLSessionConfiguration.self,
            original: #selector(getter: URLSessionConfiguration.default),
            swizzled: #selector(URLSessionConfiguration.sj_default)
        )
    }
}

extension URLSessionConfiguration {
    @objc class var sj_default: URLSessionConfiguration {
        let configuration = self.sj_default // 调用原始方法
        configuration.sj_injectProtocol()   // 注入SJURLProtocol
        return configuration
    }
}
```

**工作原理**：
1. 启动时交换 `URLSessionConfiguration.default` 和 `URLSessionConfiguration.ephemeral` 的实现
2. 当任何代码（包括第三方SDK）调用这些方法时，会自动执行我们的实现
3. 我们的实现会调用原始方法获取配置，然后自动注入 `SJURLProtocol`
4. 这样所有使用默认配置的URLSession都会被自动拦截

**优点**：
- 零侵入，无需修改第三方库代码
- 自动拦截所有使用默认配置的请求
- 对开发者透明

**注意事项**：
- Method Swizzling 需要谨慎使用
- 仅在Debug模式下使用
- 停止时会恢复原始实现

### 3. WebSocket 日志记录

提供简单的 API 记录 WebSocket 事件：

```swift
public extension SJLogger {
    static func logWebSocket(url: String, event: SJWebSocketEvent) {
        // 检查配置开关
        guard SJLoggerConfig.shared.enableWebSocketLog else { return }
        
        // 根据事件类型记录日志
        switch event {
        case .connected(let headers):
            // 记录连接事件
        case .text(let message):
            // 记录文本消息
        // ... 其他事件
        }
    }
}
```

**支持的事件类型**：
- 连接建立/断开
- 文本/二进制消息
- 错误和状态变化
- Ping/Pong 心跳

### 4. 线程安全设计

使用 GCD 的 Concurrent Queue + Barrier 实现线程安全：

```swift
public class SJLoggerStorage {
    private let queue = DispatchQueue(label: "com.sjlogger.storage", attributes: .concurrent)
    
    // 读操作：并发执行
    public func getAllLogs(completion: @escaping ([SJLoggerModel]) -> Void) {
        queue.async {
            let logs = self.logs
            DispatchQueue.main.async {
                completion(logs)
            }
        }
    }
    
    // 写操作：使用barrier确保独占访问
    public func addLog(_ log: SJLoggerModel) {
        queue.async(flags: .barrier) {
            self.logs.insert(log, at: 0)
        }
    }
}
```

**优点**：
- 读操作可以并发执行，提高性能
- 写操作使用barrier确保数据一致性
- 避免死锁和竞态条件

### 5. UI层设计

#### 悬浮窗实现

```swift
class SJFloatingWindow: UIView {
    // 拖动手势
    private var panGesture: UIPanGestureRecognizer!
    
    // 吸附到边缘
    private func snapToEdge() {
        // 计算最近的边缘并吸附
    }
}
```

**特性**：
- 可拖动
- 自动吸附到屏幕边缘
- 显示未读日志数量徽章
- 延迟显示避免启动冲突

#### 日志列表

- 使用 `UITableView` 展示日志列表
- 支持搜索、过滤、排序
- 左滑删除和分享
- 实时更新（通过NotificationCenter）

#### 日志详情

- 使用 `UIScrollView` + `UIStackView` 动态布局
- 支持复制单个字段
- 支持分享完整日志

## 性能优化

### 1. 内存管理

- 限制最大日志数量（默认1000条）
- 限制响应体大小（默认1MB）
- 超过限制自动丢弃旧数据

### 2. 异步处理

- 所有日志操作都在后台队列执行
- UI更新在主线程执行
- 避免阻塞主线程

### 3. 数据压缩

- 对于大型响应体，只记录前N个字节
- 二进制数据转换为十六进制字符串

## 安全考虑

### 1. 敏感信息

- 支持URL过滤，可以忽略包含敏感信息的请求
- 建议仅在Debug模式使用
- 不持久化日志到磁盘

### 2. 内存安全

- 使用 `weak self` 避免循环引用
- 及时释放不需要的资源
- 限制内存占用

## 兼容性

### 系统要求

- iOS 15.0+（主要功能）
- iOS 12.0+（TCP监控需要）

### 第三方库兼容性

已测试兼容：
- ✅ Moya/RxSwift
- ✅ Alamofire
- ✅ AFNetworking
- ✅ 原生 URLSession

理论上兼容所有基于 URLSession 的网络库。

## 已知限制

1. **无法拦截 CFNetwork 直接调用**：如果第三方库直接使用 CFNetwork API，无法拦截
2. **WebSocket 支持有限**：目前只能记录握手请求，无法记录消息内容
3. **上传进度**：暂不支持显示上传进度
4. **下载进度**：暂不支持显示下载进度

## 未来计划

- [ ] 支持 WebSocket 消息监控
- [ ] 支持请求/响应修改（Mock功能）
- [ ] 支持导出为 HAR 格式
- [ ] 支持请求重放
- [ ] 支持性能分析图表
- [ ] 支持 gRPC 请求监控
