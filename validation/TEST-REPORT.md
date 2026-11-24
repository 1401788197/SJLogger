# 界面优化与回归验证

验证日期：2026-11-10（Asia/Shanghai）

## 结果

Xcode 26.6，iPhone 17 Pro 模拟器，iOS 26.5。完整 XCTest 套件 **31 项通过、0 失败**，其中新增 9 项。最终测试耗时约 22.3 秒；`git diff --check` 通过。最终日志未发现 Auto Layout 约束冲突。

## 修复和优化

- 接口页清除搜索时遗留关键字：改为由请求页统一提供筛选后的快照，搜索和取消同时更新两页，接口搜索也匹配 Header、Body。
- 固定模式按条数差计算新日志：改为按 ID 与展示快照比较，容量上限淘汰旧日志时仍能提示新请求。
- 固定模式空列表收到数据不展示：首次匹配数据自动展示；已有请求的响应更新、清除与删除继续同步。
- 旧搜索跨次打开遗留：新打开的列表从无搜索条件开始；筛选零结果明确显示总数及重置入口。
- 修正筛选后滚动偏移越界；增加实时/暂停/历史状态栏、两页下拉刷新、键盘避让和筛选重置。
- 多选支持同一行再次取消、全选和计数；选择期间保持数据稳定。历史快照不提供删除当前日志的误导操作。
- 详情监听当前请求完成，Body 支持选中文本与独立复制；持久化详情保持快照。
- 统一失败定义，进行中与重定向不归为失败；高级筛选补全请求方法、取消与应用流程。

## 新增回归场景

1. 接口搜索零结果 → 取消 → 恢复，并验证 Body 搜索。
2. 暂停且初始为空 → 首条请求自动展示。
3. 达到容量上限后新增 ID → 提示 → 刷新两页 → 清空同步。
4. 进行中/重定向/失败的区分，以及 Header 搜索与首尾空格处理。
5. 详情打开后请求完成 → 响应体自动出现。
6. 深度滚动后筛选零结果 → 重置恢复、偏移修正、历史快照只可分享。
7. 同一行多选/取消与退出选择后恢复更新。
8. 暂停期间请求/接口保持一致，接口下拉刷新同时更新两页。
9. 请求、接口、详情布局与渲染，包含 320×568、小屏空状态和深色样式截图。

保留原有存储并发、重定向、URL 过滤、WebSocket、导出、JSON、持久化与重复展示等测试。

## 可复现命令

从 `Example` 目录执行：

```sh
xcodebuild test -workspace SJLogger.xcworkspace \
  -scheme SJLogger-Example \
  -destination 'platform=iOS Simulator,id=141A1EAB-A94C-4362-9B06-55B2245251B5' \
  -derivedDataPath /tmp/SJLogger-UI-Validation
```

本次原始结果：`/tmp/SJLogger-release-check.xcresult`；完整输出：`/tmp/sjlogger-release-check.log`。

## 截图

截图由 XCTest 中真实 UIKit 视图渲染产生，使用合成测试日志：

- [请求列表](Request-list.png)
- [接口列表](Endpoint-list.png)
- [请求详情](Request-detail.png)
- [小屏列表](Small-screen-list.png)
- [深色筛选空状态](Dark-filter-empty-state.png)

## 验证边界

已完成模拟器中的控制器交互回归和截图复核。电脑锁屏阻止了桌面手动点击检查，未完成真机或宿主业务 App 的联调，也未覆盖所有 iOS 版本。截图采用视图层渲染，不包含系统键盘与分享面板。

## 2026-11-12：App 业务结果错误

业务协议：顶层 `code == 0` 为成功，非 0 为业务失败，`message` 为业务说明。新增默认解析器兼容 `msg`、整数字符串和现有 Body 解密器；可通过 `businessResultParser` 自定义、限定域名或关闭。

HTTP 200 + 业务失败现在显示红色业务码和说明，详情页置顶展示；失败筛选、成功率、接口聚合、存储统计、文本导出和 HAR 扩展字段保持一致。HTTP 状态与原始响应体不修改。列表按内容自动调整行高，复用 Cell 时清除上一条业务错误。

完整模拟器测试 **37 项通过、0 失败**，本次新增 6 项，覆盖：

- HTTP 200 业务失败的筛选、统计、接口聚合和导出。
- 业务码 1/2/4/5/98/99、字符串业务码、无效响应及 WebSocket 不误判。
- 解密后的业务错误、Codable 历史日志兼容及响应内容更新。
- 自定义解析、域名限制、关闭判断与业务错误搜索。
- 320 点小屏列表/详情渲染、自动行高及 Cell 复用。
- 在途请求完成后，失败列表和详情自动显示业务错误。

截图已复核：[业务错误列表](Business-error-list.png)、[业务错误详情](Business-error-detail.png)。

最终原始结果：`/tmp/SJLogger-business-final.xcresult`；输出：`/tmp/sjlogger-business-final.log`。`git diff --check` 通过。

边界：未在宿主业务 App 中进行真机联调。缺失或被大小限制省略的响应体无法自动解析业务错误；加密的历史响应需提供相同解密器。

## 2026-11-12：站外分享文件附件

将列表当前结果、多选结果、单条左滑、详情分享及设置页持久化导出统一改为 `.txt` 附件；详情的 HAR 导出改为 `.har` 附件。系统分享面板接收本地文件 URL，复制日志和 cURL 仍是文本。使用异步文件写入、原子保存及独立文件名；取消/完成分享不立刻删除附件，下次导出只回收本导出目录中超过 7 天的旧附件。写入失败显示错误，多选状态只在分享面板成功展示后退出。

Xcode 26.6 / iPhone 17 Pro / iOS 26.5 完整模拟器测试 **41 项通过、0 失败**，本次新增 4 项：

- TXT 文件 URL、UTF-8 内容、所选日志范围及业务错误说明。
- HAR 文件可解析、HTTP/业务结果保留、多次导出不覆盖。
- 临时附件过期清理范围、近期附件保留与文件写入失败传播。
- 从详情分享按钮实际打开系统文件分享面板，取消后附件仍可读取。

原始结果：`/tmp/SJLogger-file-sharing-tests.xcresult`；日志：`/tmp/sjlogger-file-sharing-tests.log`。`git diff --check` 通过，源码扫描确认分享面板统一传入 `[url]`，不再传入 `[text]`。

验证边界：未实际发送到微信或邮件，也未验证第三方接收应用。模拟器分享服务输出了默认接收应用/文件提供域的系统诊断，文件生成、内容读取和面板展示测试通过；第三方 App 附件接收仍需真机验证。

## 0.6.0 发布验证（2026-11-12）

- podspec、HAR 版本标识及示例依赖锁文件已统一为 0.6.0。
- 完整 XCTest：41 项通过，0 失败。结果包：`/tmp/SJLogger-060-release.xcresult`。
- `pod lib lint SJLogger.podspec --allow-warnings`：Core 与 Starscream 子库验证通过；只有 Xcode AppIntents 元数据工具的无依赖提示。
- `git diff --check` 通过。


## 0.6.1 发布验证（2026-11-24）

- 发布内容：取消独立分类、统计、筛选和导出，以及完成回调重入时的取消误报修复。
- 功能提交 `9264271` 已运行完整 XCTest：46 项通过，0 失败；结果包 `/tmp/sjlogger-cancellation-tests.xcresult`。发布阶段仅更新版本元数据、示例锁文件和文档，未重复运行该套件。
- podspec、HAR 版本标识、安装示例及示例工程依赖元数据统一为 0.6.1；`pod install --project-directory=Example` 成功。
- `pod lib lint SJLogger.podspec --allow-warnings --no-ansi` 通过，覆盖 Core 与 Starscream 子库；输出仅有 Xcode AppIntents 无依赖提示及构建说明。完整日志 `/tmp/sjlogger-061-lint.log`。
- CocoaPods 1.16.2，使用 Homebrew Ruby 4.0；`git diff --check` 通过。

### 0.6.1 发布结果

- 版本提交 `2708fb8` 与标签 `0.6.1` 已推送至 `1401788197/SJLogger` 的 `main`。
- `pod trunk push` 完成远端源码验证后返回 GitHub commit API 超时；未盲目重试。
- 随后确认 Trunk 已登记 0.6.1（2026-11-24 04:02:29 UTC，即北京时间 12:02:29），官方 Specs 仓库与 CocoaPods CDN 均可读取该版本。
- 对比 Trunk 重定向规格、Specs 仓库及 CDN 的 podspec，版本与源码标签均为 0.6.1；Specs/CDN JSON 与本地 `pod ipc spec` 结果完全一致，确认发布成功。
- 发布验证日志：`/tmp/sjlogger-061-trunk-push.log`。升级可使用 `pod 'SJLogger', '~> 0.6.1'`，已有项目执行 `pod update SJLogger --repo-update`。
