# SJLogger 使用指南

## 快速开始

### 1. 最简单的使用方式

```swift
import SJLogger

// 在AppDelegate中启动
SJLogger.shared.start()
```

这样就完成了！SJLogger会自动拦截所有网络请求，并在屏幕右下角显示悬浮窗。

### 2. 查看日志的三种方式

#### 方式一：点击悬浮窗
- 屏幕上会出现一个蓝色的悬浮球
- 点击悬浮球即可打开日志列表
- 悬浮球可以拖动到屏幕边缘任意位置

#### 方式二：代码调用
```swift
// 从当前视图控制器打开
SJLogger.shared.showLogList(from: self)

// 或者自动查找顶层视图控制器
SJLogger.shared.showLogList()
```

#### 方式三：摇一摇（需要自己实现）
```swift
override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
        SJLogger.shared.showLogList()
    }
}
```

## 配置选项详解

### 基础配置

```swift
SJLogger.shared.start { config in
    // 是否启用日志记录（默认：true）
    config.isEnabled = true
    
    // 最大日志数量，超过后自动删除旧日志（默认：1000）
    config.maxLogCount = 500
    
    // 是否显示悬浮窗（默认：true）
    config.showFloatingWindow = true
    
    // 是否在控制台打印日志（默认：false）
    config.printToConsole = false
}
```

### 日志内容配置

```swift
SJLogger.shared.start { config in
    // 是否记录请求体（默认：true）
    config.logRequestBody = true
    
    // 是否记录响应体（默认：true）
    config.logResponseBody = true
    
    // 响应体最大记录大小（字节），0表示不限制（默认：1MB）
    config.maxResponseBodySize = 1024 * 1024
}
```

### TCP日志配置

```swift
SJLogger.shared.start { config in
    // 是否启用TCP日志（默认：true）
    config.enableTCPLog = true
}

// 也可以动态开关
SJLogger.shared.setTCPLogEnabled(true)
```

## URL过滤配置

### 监控特定URL

如果设置了监控URL模式，则只记录匹配的请求：

```swift
// 只监控包含api.example.com的请求
SJLogger.shared.addMonitoredURL("api.example.com")

// 使用正则表达式
SJLogger.shared.addMonitoredURL(".*\\.myapi\\.com/.*")
SJLogger.shared.addMonitoredURL("https://.*\\.github\\.com/.*")
```

### 忽略特定URL

忽略不需要记录的请求（如图片、静态资源等）：

```swift
// 忽略图片
SJLogger.shared.addIgnoredURL(".*\\.png$")
SJLogger.shared.addIgnoredURL(".*\\.jpg$")
SJLogger.shared.addIgnoredURL(".*\\.gif$")

// 忽略分析统计
SJLogger.shared.addIgnoredURL("analytics\\.google\\.com")
SJLogger.shared.addIgnoredURL("firebase\\.com")
```

### 过滤优先级

1. 首先检查忽略列表，如果匹配则不记录
2. 如果监控列表为空，则记录所有（除了忽略的）
3. 如果监控列表不为空，则只记录匹配的

## 日志管理

### 清除日志

```swift
// 清除所有日志
SJLogger.shared.clearLogs()

// 在UI中清除
// 方法1：日志列表页面的清除按钮
// 方法2：左滑单条日志删除
```

### 导出日志

```swift
// 导出所有日志为文本
SJLogger.shared.exportLogs { logText in
    // 保存到文件
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("logs.txt")
    try? logText.write(to: fileURL, atomically: true, encoding: .utf8)
    
    // 或者分享
    let activityVC = UIActivityViewController(activityItems: [logText], applicationActivities: nil)
    self.present(activityVC, animated: true)
}

// 在UI中导出
// 点击日志列表页面右上角的分享按钮
```

### 获取统计信息

```swift
SJLogger.shared.getStatistics { stats in
    let total = stats["total"] as? Int ?? 0
    let success = stats["success"] as? Int ?? 0
    let failed = stats["failed"] as? Int ?? 0
    let totalSize = stats["totalSize"] as? Int ?? 0
    let typeCount = stats["typeCount"] as? [String: Int] ?? [:]
    
    print("总请求数: \(total)")
    print("成功: \(success), 失败: \(failed)")
    print("总数据量: \(totalSize) bytes")
    print("类型统计: \(typeCount)")
}
```

## 日志查看功能

### 日志列表

- **搜索**：在搜索栏输入关键词，搜索URL、方法、请求/响应内容
- **过滤**：点击过滤按钮，可以按状态或类型过滤
  - 全部
  - 成功请求（2xx状态码）
  - 失败请求（非2xx或有错误）
  - HTTP/HTTPS
  - TCP
- **排序**：最新的日志在最上面
- **操作**：左滑日志项可以删除或分享

### 日志详情

点击任意日志查看详细信息：

- **基本信息**
  - 类型、URL、方法
  - 状态码、开始时间、结束时间
  - 耗时、响应大小
  
- **请求信息**
  - 请求头
  - 请求体（支持点击复制）
  
- **响应信息**
  - 响应头
  - 响应体（支持点击复制）
  
- **TCP信息**（如果有）
  - 连接状态
  - 数据传输统计

- **操作**
  - 右上角复制按钮：复制完整日志
  - 右上角分享按钮：分享日志

## 高级用法

### 仅在Debug模式启用

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    #if DEBUG
    SJLogger.shared.start { config in
        config.isEnabled = true
        config.showFloatingWindow = true
    }
    #endif
    
    return true
}
```

### 动态开关

```swift
// 运行时启用/禁用
SJLogger.shared.setEnabled(true)
SJLogger.shared.setEnabled(false)

// 显示/隐藏悬浮窗
SJLogger.shared.showFloatingWindow()
SJLogger.shared.hideFloatingWindow()

// 启用/禁用TCP日志
SJLogger.shared.setTCPLogEnabled(true)
```

### 自定义悬浮窗触发

```swift
// 可以添加手势或按钮来控制悬浮窗
let gesture = UITapGestureRecognizer(target: self, action: #selector(toggleFloatingWindow))
gesture.numberOfTapsRequired = 3
view.addGestureRecognizer(gesture)

@objc func toggleFloatingWindow() {
    // 切换悬浮窗显示状态
    if SJLogger.shared.config.showFloatingWindow {
        SJLogger.shared.hideFloatingWindow()
    } else {
        SJLogger.shared.showFloatingWindow()
    }
}
```

## 第三方网络库集成

**好消息**：SJLogger 使用 Method Swizzling 技术自动拦截所有网络请求！

这意味着：
- ✅ 第三方SDK的网络请求会自动被监听
- ✅ Moya、Alamofire等库的请求会自动被监听
- ✅ 无需修改任何第三方库的代码
- ✅ 只需调用 `SJLogger.shared.start()` 即可

### 自动拦截原理

SJLogger 会自动交换 `URLSessionConfiguration.default` 和 `URLSessionConfiguration.ephemeral` 的实现，在所有配置中自动注入 `SJURLProtocol`。这样即使第三方SDK内部创建了自己的 URLSession，也会被自动拦截。

### Moya/RxSwift 集成

**通常情况下无需任何配置**，SJLogger 会自动拦截。

如果自动拦截失效（极少数情况），可以手动配置：

```swift
import Moya
import SJLogger

// 方法1：使用便捷方法（推荐）
let provider = MoyaProvider<YourAPI>.withSJLogger()

// 方法2：手动配置
let configuration = URLSessionConfiguration.default
configuration.protocolClasses = [SJURLProtocol.self] + (configuration.protocolClasses ?? [])
let session = Session(configuration: configuration)
let provider = MoyaProvider<YourAPI>(session: session)

// 方法3：使用辅助方法
let session = SJLogger.createMoyaSession()
let provider = MoyaProvider<YourAPI>(session: session)
```

### Alamofire 集成

```swift
import Alamofire
import SJLogger

let configuration = URLSessionConfiguration.default
configuration.protocolClasses = [SJURLProtocol.self] + (configuration.protocolClasses ?? [])
let session = Session(configuration: configuration)

session.request("https://api.example.com/data").response { response in
    // 处理响应
}
```

### 自定义 URLSession

如果你使用自定义的 URLSession，需要手动添加 SJURLProtocol：

```swift
let configuration = URLSessionConfiguration.default
configuration.protocolClasses = [SJURLProtocol.self] + (configuration.protocolClasses ?? [])
let session = URLSession(configuration: configuration)
```

## 常见问题

### Q: 为什么看不到日志？

A: 检查以下几点：
1. 确认已调用 `SJLogger.shared.start()`
2. 确认 `config.isEnabled = true`
3. 检查是否设置了过于严格的URL过滤规则
4. 确认网络请求使用的是 `URLSession`（而非底层的 CFNetwork）
5. 查看控制台是否有 "[SJLogger] Started successfully" 的提示
6. 尝试发送一个简单的测试请求验证

### Q: 日志太多怎么办？

A: 可以：
1. 设置 `config.maxLogCount` 限制数量
2. 使用 `addIgnoredURL` 忽略不需要的请求
3. 定期调用 `clearLogs()` 清除日志

### Q: 如何只监控特定接口？

A: 使用监控URL模式：
```swift
config.monitoredURLPatterns = ["api.myapp.com"]
```

### Q: 响应体太大导致卡顿？

A: 设置响应体大小限制：
```swift
config.maxResponseBodySize = 512 * 1024 // 512KB
```

### Q: 如何在Release版本中禁用？

A: 使用编译条件：
```swift
#if DEBUG
SJLogger.shared.start()
#endif
```

## 性能建议

1. **合理设置日志数量**：`maxLogCount` 建议不超过1000
2. **限制响应体大小**：对于大文件下载，建议设置 `maxResponseBodySize`
3. **忽略静态资源**：图片、CSS、JS等静态资源建议忽略
4. **Release版本禁用**：生产环境务必禁用SJLogger

## 安全建议

1. **不要在生产环境使用**：日志可能包含敏感信息
2. **注意分享内容**：分享日志前检查是否包含密码、token等
3. **定期清理日志**：避免敏感信息长期保存在内存中
4. **使用URL过滤**：对于包含敏感参数的URL，建议忽略记录
