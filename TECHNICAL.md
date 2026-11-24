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

- 响应体超过配置上限后不再缓存，并立即释放已缓存数据
- 二进制数据转换为十六进制字符串

## 安全考虑

### 1. 敏感信息

- 支持URL过滤，可以忽略包含敏感信息的请求
- 建议仅在Debug模式使用
- 支持日志持久化，默认写入 Caches；分享或提交日志前需检查敏感信息

### 2. 内存安全

- 使用 `weak self` 避免循环引用
- 及时释放不需要的资源
- 限制内存占用

## 兼容性

### 系统要求

- iOS 15.0+（主要功能）

### 第三方库兼容性

已测试兼容：
- ✅ Moya/RxSwift
- ✅ Alamofire
- ✅ AFNetworking
- ✅ 原生 URLSession

理论上兼容所有基于 URLSession 的网络库。

## 已知限制

1. **无法拦截 CFNetwork 直接调用**：如果第三方库直接使用 CFNetwork API，无法拦截
2. **WebSocket 需接入**：Core 提供手动事件记录，Starscream 可通过可选子库代理；其他 WebSocket 库不会自动采集消息
3. **上传进度**：暂不支持显示上传进度
4. **下载进度**：暂不支持显示下载进度

## 未来计划

- [ ] 支持请求/响应修改（Mock功能）
- [ ] 支持请求重放
- [ ] 支持性能分析图表
- [ ] 支持 gRPC 请求监控

## 取消分类与终态保护（2026-11-24）

- 取消仅匹配 `NSURLErrorDomain` + `NSURLErrorCancelled`；相同数值的其他错误域仍按失败处理。取消优先于已经收到的 HTTP 状态，保留原始响应与错误用于诊断。
- 模型新增可选的 `errorDomain`、`errorCode`、`cancellationSource`，快照、Codable 和导出保留这些字段，兼容旧日志缺省字段。
- `finishCurrentLog` 在锁内认领日志终态，并且只允许一次写回。完成结果先排入存储队列，再通知外层 client，避免外层回调重入 `stopLoading()` 时将成功覆盖为取消。
- `stopLoading` 在取消底层任务之前记录取消来源；停止后抑制后续数据/完成回调。重定向继续分别记录原始跳转与目标请求。
- 本次调整只影响日志分类和记录时序，不改动宿主 App 的页面取消逻辑或日志页面展示方式。

验证：Xcode 26.6，iPhone 17 Pro / iOS 26.5 模拟器，完整 XCTest 共 46 项全部通过（新增 5 项），`git diff --check` 通过。覆盖取消与其他错误域的区分、筛选/统计/HAR、快照与旧格式解码、中性 UI、完成回调重入停止、响应期间主动取消，以及既有重定向流程。未进行宿主 Coolfly App 真机联调。

```sh
xcodebuild test -workspace Example/SJLogger.xcworkspace -scheme SJLogger-Example \
  -destination 'platform=iOS Simulator,id=141A1EAB-A94C-4362-9B06-55B2245251B5' \
  -derivedDataPath /tmp/sjlogger-cancellation-build \
  -resultBundlePath /tmp/sjlogger-cancellation-tests.xcresult CODE_SIGNING_ALLOWED=NO
```
