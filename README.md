# SJLogger

[![CI Status](https://img.shields.io/travis/Hicreate/SJLogger.svg?style=flat)](https://travis-ci.org/Hicreate/SJLogger)
[![Version](https://img.shields.io/cocoapods/v/SJLogger.svg?style=flat)](https://cocoapods.org/pods/SJLogger)
[![License](https://img.shields.io/cocoapods/l/SJLogger.svg?style=flat)](https://cocoapods.org/pods/SJLogger)
[![Platform](https://img.shields.io/cocoapods/p/SJLogger.svg?style=flat)](https://cocoapods.org/pods/SJLogger)

一个强大的iOS网络日志查看框架，类似CocoaDebug，支持实时监控、查看、复制和分享网络请求日志。

## 功能特性

- ✅ **自动拦截所有请求**：使用Method Swizzling技术，自动拦截所有网络请求（包括第三方SDK）
- ✅ **网络请求拦截**：自动拦截所有HTTP/HTTPS请求
- ✅ **TCP日志监控**：支持TCP层网络活动监控
- ✅ **实时日志记录**：实时记录和展示网络请求详情
- ✅ **悬浮窗入口**：应用内悬浮窗，方便快速查看日志
- ✅ **日志搜索过滤**：支持关键词搜索和多种过滤条件
- ✅ **日志复制分享**：一键复制或分享日志内容
- ✅ **URL模式配置**：支持监听和忽略特定URL模式
- ✅ **详细信息展示**：完整显示请求头、请求体、响应头、响应体
- ✅ **性能统计**：显示请求耗时、响应大小等统计信息
- ✅ **线程安全**：多线程环境下安全使用
- ✅ **零侵入集成**：无需修改第三方库代码，自动监听所有请求

## 截图

> 添加截图展示UI界面

## 系统要求

- iOS 15.0+
- Swift 5.0+
- Xcode 13.0+

## 安装

### CocoaPods

在你的 `Podfile` 中添加：

```ruby
pod 'SJLogger'
```

然后运行：

```bash
pod install
```

## 使用方法

### 1. 基础使用

**推荐方式**：在设置根控制器后立即启动 SJLogger

```swift
import SJLogger

// SwiftUI App
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 在视图出现后启动SJLogger
                    SJLogger.shared.start()
                }
        }
    }
}

// UIKit App - SceneDelegate
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = UINavigationController(rootViewController: ViewController())
    window?.makeKeyAndVisible()
    
    // 设置根控制器后立即启动SJLogger
    SJLogger.shared.start()
}

// UIKit App - AppDelegate（旧版）
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = UINavigationController(rootViewController: ViewController())
    window?.makeKeyAndVisible()
    
    // 设置根控制器后立即启动SJLogger
    SJLogger.shared.start()
    
    return true
}
```

**注意**：
- ✅ `start()` 方法可以多次调用，内部会自动处理重复调用
- ✅ 建议在设置根控制器后调用，确保悬浮窗能正确显示
- ✅ 每次调用都会更新配置，无需担心重复初始化

### 2. 自定义配置

```swift
SJLogger.shared.start { config in
    // 是否启用日志记录
    config.isEnabled = true
    
    // 最大日志数量
    config.maxLogCount = 500
    
    // 是否记录请求体和响应体
    config.logRequestBody = true
    config.logResponseBody = true
    
    // 响应体最大记录大小（字节）
    config.maxResponseBodySize = 1024 * 1024 // 1MB
    
    // 是否启用WebSocket日志
    config.enableWebSocketLog = true
    
    // 是否在控制台打印日志
    config.printToConsole = false
    
    // 是否显示悬浮窗
    config.showFloatingWindow = true
}
```

### 3. URL过滤配置

```swift
// 添加需要监控的URL模式（正则表达式）
SJLogger.shared.addMonitoredURL("api.example.com")
SJLogger.shared.addMonitoredURL(".*\\.myapi\\.com/.*")

// 添加需要忽略的URL模式
SJLogger.shared.addIgnoredURL(".*\\.png$")
SJLogger.shared.addIgnoredURL(".*\\.jpg$")
SJLogger.shared.addIgnoredURL("analytics\\.google\\.com")
```

### 4. 手动显示日志界面

```swift
// 从当前视图控制器显示日志列表
SJLogger.shared.showLogList(from: self)

// 或者自动查找顶层视图控制器
SJLogger.shared.showLogList()
```

### 5. 日志管理

```swift
// 清除所有日志
SJLogger.shared.clearLogs()

// 导出所有日志
SJLogger.shared.exportLogs { logText in
    print(logText)
    // 可以保存到文件或分享
}

// 获取日志统计信息
SJLogger.shared.getStatistics { stats in
    print("Total logs: \(stats["total"] ?? 0)")
    print("Success: \(stats["success"] ?? 0)")
    print("Failed: \(stats["failed"] ?? 0)")
}
```

### 6. 悬浮窗控制

```swift
// 显示悬浮窗
SJLogger.shared.showFloatingWindow()

// 隐藏悬浮窗
SJLogger.shared.hideFloatingWindow()
```

### 7. 停止日志记录

```swift
// 停止SJLogger
SJLogger.shared.stop()
```

## 高级功能

### TCP日志监控

框架支持TCP层的网络监控（需要iOS 12.0+）：

```swift
// 启用TCP日志
SJLogger.shared.setTCPLogEnabled(true)

// TCP日志会自动记录：
// - 网络路径变化
// - 连接状态
// - 数据传输统计
```

### 日志搜索和过滤

在日志列表界面中：
- 使用搜索栏搜索URL、方法、请求/响应内容
- 点击过滤按钮选择：全部、成功请求、失败请求、按类型过滤
- 左滑日志项可以删除或分享单条日志

### 日志详情

点击任意日志查看详细信息：
- 基本信息（URL、方法、状态码、耗时等）
- 请求头和请求体
- 响应头和响应体
- TCP连接信息（如果有）
- 支持复制和分享完整日志

## 第三方库集成

**重要提示**：从 v0.1.0 开始，SJLogger 使用 Method Swizzling 技术自动拦截所有网络请求，包括第三方SDK内部的请求。**大多数情况下你不需要做任何额外配置**，只需调用 `SJLogger.shared.start()` 即可。

以下配置方法仅在自动拦截失效时使用：

### Moya集成

如果自动拦截失效，可以手动配置 Session：

#### 方法一：使用便捷方法（推荐）

```swift
import Moya
import SJLogger

// 创建支持SJLogger的Provider
let provider = MoyaProvider<YourAPI>.withSJLogger()

// 或者带插件
let provider = MoyaProvider<YourAPI>.withSJLogger(
    plugins: [NetworkLoggerPlugin()]
)
```

#### 方法二：手动配置Session

```swift
import Moya
import SJLogger

// 创建自定义Session
let configuration = URLSessionConfiguration.default
configuration.protocolClasses = [SJURLProtocol.self] + (configuration.protocolClasses ?? [])
let session = Session(configuration: configuration)

// 使用自定义Session创建Provider
let provider = MoyaProvider<YourAPI>(session: session)
```

#### 方法三：使用辅助方法

```swift
import Moya
import SJLogger

// 使用SJLogger提供的Session
let session = SJLogger.createMoyaSession()
let provider = MoyaProvider<YourAPI>(session: session)
```

### Alamofire集成

如果使用 Alamofire，需要配置 Session：

```swift
import Alamofire
import SJLogger

let configuration = URLSessionConfiguration.default
configuration.protocolClasses = [SJURLProtocol.self] + (configuration.protocolClasses ?? [])
let session = Session(configuration: configuration)

// 使用配置好的session发送请求
session.request("https://api.example.com/data").response { response in
    // 处理响应
}
```

### AFNetworking集成

如果使用 AFNetworking（Objective-C），需要配置 sessionConfiguration：

```objc
#import <SJLogger/SJLogger-Swift.h>

NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
configuration.protocolClasses = @[[SJURLProtocol class]];

AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
```

### WebSocket 集成（Starscream 等）

**重要说明**：WebSocket 连接无法通过 URLProtocol 自动拦截，需要在你的代码中手动调用日志记录方法。

#### 使用方法（超简单，只需一行代码）

```swift
import Starscream
import SJLogger

extension ChatSocketManager: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
        let url = "wss://example.com/socket" // 你的WebSocket URL
        
        // 转换Starscream事件为SJLogger事件并记录
        switch event {
        case .connected(let headers):
            SJLogger.logWebSocket(url: url, event: .connected(headers))
            login() // 你的业务逻辑
            
        case .text(let string):
            SJLogger.logWebSocket(url: url, event: .text(string))
            handleMsg(str: string) // 你的业务逻辑
            
        case .binary(let data):
            SJLogger.logWebSocket(url: url, event: .binary(data))
            
        case .disconnected(let reason, let code):
            SJLogger.logWebSocket(url: url, event: .disconnected(reason, code))
            
        case .error(let error):
            SJLogger.logWebSocket(url: url, event: .error(error))
            
        case .ping(let data):
            SJLogger.logWebSocket(url: url, event: .ping(data))
            
        case .pong(let data):
            SJLogger.logWebSocket(url: url, event: .pong(data))
            
        case .viabilityChanged(let isViable):
            SJLogger.logWebSocket(url: url, event: .viabilityChanged(isViable))
            
        case .reconnectSuggested(let shouldReconnect):
            SJLogger.logWebSocket(url: url, event: .reconnectSuggested(shouldReconnect))
            
        case .cancelled:
            SJLogger.logWebSocket(url: url, event: .cancelled)
            
        case .peerClosed:
            SJLogger.logWebSocket(url: url, event: .peerClosed)
        }
    }
}
```

#### WebSocket 日志记录 API

只需要一个方法：
- `SJLogger.logWebSocket(url:event:)` - 记录所有WebSocket事件

支持的事件类型（`SJWebSocketEvent`）：
- `.connected([String: String])` - 连接建立
- `.disconnected(String, UInt16)` - 断开连接
- `.text(String)` - 文本消息
- `.binary(Data)` - 二进制消息
- `.error(Error?)` - 错误
- `.ping(Data?)` / `.pong(Data?)` - 心跳
- `.viabilityChanged(Bool)` - 连接可用性变化
- `.reconnectSuggested(Bool)` - 重连建议
- `.cancelled` - 取消
- `.peerClosed` - 对端关闭

## 注意事项

1. **仅在Debug模式使用**：建议仅在Debug模式下启用SJLogger，避免在Release版本中使用
2. **内存管理**：设置合理的`maxLogCount`避免内存占用过大
3. **敏感信息**：注意日志中可能包含敏感信息，不要随意分享
4. **性能影响**：日志记录会有轻微的性能影响，但已优化到最小
5. **第三方库**：使用Moya、Alamofire等第三方网络库时，需要手动配置Session

## 示例项目

运行示例项目：

```bash
cd Example
pod install
open SJLogger.xcworkspace
```

## 架构设计

```
SJLogger
├── Models          # 数据模型
│   ├── SJLoggerModel.swift      # 日志数据模型
│   └── SJLoggerConfig.swift     # 配置模型
├── Core            # 核心功能
│   ├── SJURLProtocol.swift      # 网络拦截器
│   ├── SJURLSessionSwizzler.swift # Method Swizzling
│   └── SJLoggerStorage.swift    # 日志存储管理
├── UI              # 用户界面
│   ├── SJLogListViewController.swift   # 日志列表
│   ├── SJLogCell.swift                 # 列表Cell
│   ├── SJLogDetailViewController.swift # 日志详情
│   └── SJFloatingWindow.swift          # 悬浮窗
└── SJLogger.swift  # 主入口类
```

## 更新日志

### Version 0.1.0
- 初始版本发布
- 支持HTTP/HTTPS请求拦截
- 支持TCP日志监控
- 完整的UI界面
- 日志搜索、过滤、复制、分享功能

## 贡献

欢迎提交Issue和Pull Request！

## 作者

shengjie, shengjie

## 许可证

SJLogger is available under the MIT license. See the LICENSE file for more info.
