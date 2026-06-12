# SJLogger

[![Version](https://img.shields.io/cocoapods/v/SJLogger.svg?style=flat)](https://cocoapods.org/pods/SJLogger)
[![License](https://img.shields.io/cocoapods/l/SJLogger.svg?style=flat)](https://cocoapods.org/pods/SJLogger)
[![Platform](https://img.shields.io/cocoapods/p/SJLogger.svg?style=flat)](https://cocoapods.org/pods/SJLogger)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat)](https://swift.org)

SJLogger is a Debug network logger for iOS apps. It captures HTTP/HTTPS requests, WebSocket events, request bodies, response bodies, headers, timing, traffic size, failures, and slow requests, then presents them in an in-app floating debugger.

It is designed for day-to-day development, QA, test builds, and debugging third-party network behavior without attaching Charles, Proxyman, or Xcode console filters.

中文简介：SJLogger 是一个 iOS App 内网络日志调试工具，适合 Debug/测试包中查看接口请求、响应、耗时、失败、WebSocket 消息、持久化日志和导出数据。

## What It Solves

- See network requests directly inside the app.
- Inspect headers, request body, response body, status code, duration, and error.
- Search and filter logs while new requests are still arriving.
- Group repeated calls by API path to find noisy or slow endpoints.
- Export logs as text, cURL, or HAR for backend and QA collaboration.
- Keep logs on disk across app restarts when persistence is enabled.
- Decode encrypted request/response bodies with a custom decryptor.
- Record WebSocket lifecycle and messages, with optional Starscream integration.

## Features

- Automatic HTTP/HTTPS capture through URL loading interception.
- Floating entry button with log count, tap to open, long press to clear current logs.
- Custom in-app navigation UI, isolated from host app `UINavigationBar` global styling.
- Request list and endpoint-group views.
- Quick filters: all, success, failed, HTTP, WebSocket.
- Advanced filters: type, method, status bucket, slow request, failed only.
- Dynamic/frozen refresh mode so new logs do not interrupt inspection.
- Detail view with formatted body display and JSON highlighting.
- Copy, share, cURL export, HAR export, and multi-select export.
- Disk persistence with maximum storage size limit.
- Settings screen for collection, UI, persistence, slow threshold, and cleanup.
- Optional `SJLogger/Starscream` subspec for Starscream WebSocket events.
- Core pod has no third-party dependency.

## Screenshots

<p align="center">
  <img src="IMG_1494.PNG" width="30%" />
  <img src="IMG_1495.PNG" width="30%" />
  <img src="IMG_1496.PNG" width="30%" />
</p>

## Requirements

- iOS 15.0+
- Swift 5.0+
- Xcode 13.0+

## Installation

### Core

Recommended for Debug builds:

```ruby
pod 'SJLogger', '~> 0.4.0', :configurations => ['Debug']
```

Or install in all configurations:

```ruby
pod 'SJLogger', '~> 0.4.0'
```

`pod 'SJLogger'` installs only the default `Core` subspec. It does not include Starscream.

### Starscream Support

If your project uses Starscream and you want automatic WebSocket receive/connect/disconnect logging:

```ruby
pod 'SJLogger/Starscream', '~> 0.4.0', :configurations => ['Debug']
```

This adds:

```ruby
pod 'Starscream', '~> 4.0'
```

## Quick Start

Start SJLogger after your root view controller is ready.

```swift
#if DEBUG
import SJLogger
#endif

func scene(_ scene: UIScene,
           willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }

    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = UINavigationController(rootViewController: ViewController())
    window?.makeKeyAndVisible()

    #if DEBUG
    SJLogger.shared.start()
    #endif
}
```

If your app replaces `window.rootViewController` later, call `start()` again after replacement. The method is safe to call multiple times.

```swift
#if DEBUG
SJLogger.shared.start()
#endif
```

## Configuration

```swift
#if DEBUG
SJLogger.shared.start { config in
    config.isEnabled = true
    config.showFloatingWindow = true

    config.logRequestBody = true
    config.logResponseBody = true
    config.maxResponseBodySize = 1024 * 1024

    config.enableWebSocketLog = true
    config.printToConsole = false

    // Persist logs to disk. Enabled by default in 0.4.0.
    config.persistLogs = true
    config.maxPersistedLogFileSize = 10 * 1024 * 1024

    // Monitor all URLs by default. Add patterns only when you need a whitelist.
    // config.addMonitoredURL(pattern: "api.example.com")

    // Ignore noisy assets or endpoints.
    config.addIgnoredURL(pattern: ".*\\.png$")
    config.addIgnoredURL(pattern: ".*\\.jpg$")
    config.addIgnoredURL(pattern: ".*\\.gif$")
}
#endif
```

## Open UI Manually

```swift
#if DEBUG
SJLogger.shared.showLogList()
SJLogger.shared.showLogList(from: viewController)
SJLogger.shared.showSettings(from: viewController)
#endif
```

## Export Logs

```swift
SJLogger.shared.exportLogs { text in
    print(text)
}
```

In the UI:

- The list export button exports all current logs.
- In selection mode, it exports selected logs only.
- Detail page supports copy, share, cURL, and HAR actions.
- Settings page can view/export persisted logs.

## Persistence

SJLogger keeps two concepts separate:

- Current logs: shown by default when opening the logger UI.
- Persisted logs: stored on disk and available from Settings.

Persistence is enabled by default. Disk usage is limited by `maxPersistedLogFileSize`; when the file exceeds the limit, older logs are dropped first.

```swift
SJLogger.shared.start { config in
    config.persistLogs = true
    config.maxPersistedLogFileSize = 20 * 1024 * 1024
}
```

Long pressing the floating button clears current in-memory logs only. Persisted logs are cleared explicitly from Settings.

## Decrypt Request And Response Bodies

If your request or response body is encrypted, provide a display decryptor. The raw captured data is passed in, and your closure returns the string shown in the UI/export.

Built-in AES-CBC-PKCS7 helper:

```swift
SJLogger.shared.start { config in
    config.setAESBodyDecryptor(key: "1234567890123456", iv: "1234567890123456")
}
```

Custom decryptor:

```swift
SJLogger.shared.start { config in
    config.setBodyDecryptor { data in
        // Return nil to fall back to UTF-8/hex display.
        return String(data: data, encoding: .utf8)
    }
}
```

The AES helper tries to treat body data as Base64 first, then falls back to raw bytes. Supported AES key lengths are 16, 24, or 32 bytes.

## WebSocket

### Manual Logging

Core SJLogger can log WebSocket events without depending on any WebSocket library:

```swift
import SJLogger

SJLogger.logWebSocket(url: "wss://example.com/socket", event: .connected([:]))
SJLogger.logWebSocket(url: "wss://example.com/socket", event: .text("hello"))
SJLogger.logWebSocket(url: "wss://example.com/socket", event: .disconnected("normal", 1000))
SJLogger.logWebSocket(url: "wss://example.com/socket", event: .error(error))

SJLogger.logWebSocketSent(url: "wss://example.com/socket", text: "client message")
```

### Starscream

Install:

```ruby
pod 'SJLogger/Starscream', '~> 0.4.0'
```

Wrap your original delegate with `SJStarscreamProxy`. Your original delegate still receives events because the proxy forwards them after logging.

```swift
import SJLogger
import Starscream

final class ChatSocketManager: NSObject, WebSocketDelegate {
    private var socket: WebSocket?
    private var loggerProxy: SJStarscreamProxy?
    private let urlString = "wss://example.com/socket"

    func connect() {
        let request = URLRequest(url: URL(string: urlString)!)
        let socket = WebSocket(request: request)

        let proxy = SJLogger.starscreamProxy(url: urlString, forwarding: self)
        loggerProxy = proxy

        socket.delegate = proxy
        socket.connect()

        self.socket = socket
    }

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        // Your original business logic still runs here.
    }

    func send(_ text: String) {
        socket?.write(string: text)
        SJLogger.logWebSocketSent(url: urlString, text: text)
    }
}
```

Important:

- Keep a strong reference to `loggerProxy`.
- Do not assign another object to `socket.delegate` after installing the proxy.
- Starscream delegate events cover receive/connect/disconnect/error. Send direction should be logged where you call `write`.

## UI Guide

- Floating button: tap to open logs, long press to clear current logs.
- Top stats: total count, success rate, average duration, traffic.
- Request tab: individual request/event records.
- Endpoint tab: grouped API paths with count, success rate, and average duration.
- Search: URL, method, headers, body, and response content.
- Filter: type, method, status bucket, slow request, failed only.
- Detail: headers, body, error, timing, copy/share/export.
- Settings: collection switches, persistence, slow threshold, view/export persisted logs.

## API Overview

```swift
SJLogger.shared.start()
SJLogger.shared.stop()

SJLogger.shared.showFloatingWindow()
SJLogger.shared.hideFloatingWindow()

SJLogger.shared.showLogList()
SJLogger.shared.showSettings()

SJLogger.shared.clearLogs()
SJLogger.shared.exportLogs { text in }
SJLogger.shared.getStatistics { stats in }

SJLogger.logWebSocket(url: "wss://...", event: .text("..."))
SJLogger.logWebSocketSent(url: "wss://...", text: "...")
```

## Notes

- Use this library in Debug or internal test builds.
- Logs may contain tokens, cookies, user data, or private API payloads.
- Avoid shipping verbose network logging in production unless your privacy and security review allows it.
- Some custom `URLSessionConfiguration` or third-party networking setups may need verification in your app.
- Body logging and disk persistence can increase memory/disk usage for very large payloads. Set size limits appropriately.

## Example

```bash
cd Example
pod install
open SJLogger.xcworkspace
```

## Project Structure

```text
SJLogger
├── Core
│   ├── SJURLProtocol.swift
│   ├── SJURLSessionSwizzler.swift
│   ├── SJLoggerStorage.swift
│   └── SJLogExporter.swift
├── Extensions
│   ├── SJLogger+WebSocket.swift
│   └── SJStarscreamAdapter.swift
├── Models
│   ├── SJLoggerModel.swift
│   ├── SJLoggerConfig.swift
│   ├── SJLogQuery.swift
│   └── SJEndpointGroup.swift
├── UI
│   ├── SJLogListViewController.swift
│   ├── SJLogDetailViewController.swift
│   ├── SJLogFilterViewController.swift
│   ├── SJLoggerSettingsViewController.swift
│   ├── SJEndpointListViewController.swift
│   ├── SJFloatingWindow.swift
│   └── SJUIComponents.swift
└── SJLogger.swift
```

## Changelog

### 0.4.0

- Added custom in-app navigation UI.
- Added endpoint grouping, stats bar, advanced filter, and frozen refresh mode.
- Added JSON highlighting, cURL/HAR export, and multi-select export.
- Added disk persistence with maximum storage size.
- Added settings page for runtime configuration and persisted log management.
- Added AES/custom body decryptor support.
- Added optional `SJLogger/Starscream` subspec.
- Improved floating button behavior and current-log clearing.

### 0.3.0

- HTTP/HTTPS capture.
- Log list, detail, search, copy, share, and floating entry.

## Author

Shengjie

## License

SJLogger is available under the MIT license. See the LICENSE file for details.
