import XCTest
import UIKit
import Network
@testable import SJLogger

class Tests: XCTestCase {
    private struct ConfigSnapshot {
        let isEnabled: Bool
        let maxLogCount: Int
        let monitoredURLPatterns: [String]
        let ignoredURLPatterns: [String]
        let logRequestBody: Bool
        let logResponseBody: Bool
        let maxResponseBodySize: Int
        let enableWebSocketLog: Bool
        let printToConsole: Bool
        let showFloatingWindow: Bool
        let persistLogs: Bool
        let maxPersistedLogFileSize: Int
        let defaultRefreshMode: SJRefreshMode
        let slowRequestThresholdMs: Double
        let autoFreezeOnInteraction: Bool
    }

    private var configSnapshot: ConfigSnapshot!
    private var loggerWasStarted = false
    private var savedBodyDecryptor: ((Data) -> String?)?
    private var savedBusinessParser: ((SJLoggerModel) -> SJBusinessResult?)?

    override func setUp() {
        super.setUp()
        let config = SJLoggerConfig.shared
        savedBodyDecryptor = config.bodyDecryptor
        savedBusinessParser = config.businessResultParser
        config.bodyDecryptor = nil
        config.businessResultParser = SJBusinessResult.parseJSONEnvelope
        configSnapshot = ConfigSnapshot(
            isEnabled: config.isEnabled,
            maxLogCount: config.maxLogCount,
            monitoredURLPatterns: config.monitoredURLPatterns,
            ignoredURLPatterns: config.ignoredURLPatterns,
            logRequestBody: config.logRequestBody,
            logResponseBody: config.logResponseBody,
            maxResponseBodySize: config.maxResponseBodySize,
            enableWebSocketLog: config.enableWebSocketLog,
            printToConsole: config.printToConsole,
            showFloatingWindow: config.showFloatingWindow,
            persistLogs: config.persistLogs,
            maxPersistedLogFileSize: config.maxPersistedLogFileSize,
            defaultRefreshMode: config.defaultRefreshMode,
            slowRequestThresholdMs: config.slowRequestThresholdMs,
            autoFreezeOnInteraction: config.autoFreezeOnInteraction
        )
        loggerWasStarted = SJLogger.shared.isStarted

        config.isEnabled = true
        config.maxLogCount = 1000
        config.monitoredURLPatterns = []
        config.ignoredURLPatterns = []
        config.logRequestBody = true
        config.logResponseBody = true
        config.maxResponseBodySize = 1024 * 1024
        config.enableWebSocketLog = true
        config.printToConsole = false
        config.persistLogs = false
        config.slowRequestThresholdMs = 1000
        config.autoFreezeOnInteraction = false
        SJLoggerStorage.shared.clearCurrentLogs()
    }

    override func tearDown() {
        SJLoggerStorage.shared.clearCurrentLogs()

        if loggerWasStarted && !SJLogger.shared.isStarted {
            SJLogger.shared.start { $0.showFloatingWindow = false }
        } else if !loggerWasStarted && SJLogger.shared.isStarted {
            SJLogger.shared.stop()
        }

        let config = SJLoggerConfig.shared
        config.bodyDecryptor = savedBodyDecryptor
        config.businessResultParser = savedBusinessParser
        config.isEnabled = configSnapshot.isEnabled
        config.maxLogCount = configSnapshot.maxLogCount
        config.monitoredURLPatterns = configSnapshot.monitoredURLPatterns
        config.ignoredURLPatterns = configSnapshot.ignoredURLPatterns
        config.logRequestBody = configSnapshot.logRequestBody
        config.logResponseBody = configSnapshot.logResponseBody
        config.maxResponseBodySize = configSnapshot.maxResponseBodySize
        config.enableWebSocketLog = configSnapshot.enableWebSocketLog
        config.printToConsole = configSnapshot.printToConsole
        config.showFloatingWindow = configSnapshot.showFloatingWindow
        config.maxPersistedLogFileSize = configSnapshot.maxPersistedLogFileSize
        config.persistLogs = configSnapshot.persistLogs
        config.defaultRefreshMode = configSnapshot.defaultRefreshMode
        config.slowRequestThresholdMs = configSnapshot.slowRequestThresholdMs
        config.autoFreezeOnInteraction = configSnapshot.autoFreezeOnInteraction
        config.persistSettings()
        super.tearDown()
    }

    func testModelDerivedValuesAndCodableRoundTrip() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let log = makeLog(id: "model", url: "https://api.example.com/v1/users?id=7",
                          method: .post, status: 201, durationMs: 250,
                          requestBody: "request", responseBody: "response", startTime: start)

        XCTAssertEqual(log.host, "api.example.com")
        XCTAssertEqual(log.path, "/v1/users")
        XCTAssertEqual(log.shortPath, "/v1/users")
        XCTAssertEqual(log.duration, 250)
        XCTAssertTrue(log.isSuccess)
        XCTAssertEqual(log.responseSize, 8)

        let decoded = try JSONDecoder().decode(SJLoggerModel.self, from: JSONEncoder().encode(log))
        XCTAssertEqual(decoded.id, log.id)
        XCTAssertEqual(decoded.url, log.url)
        XCTAssertEqual(decoded.statusCode, 201)
        XCTAssertEqual(decoded.responseBodyString, "response")
    }

    func testQueryCombinesFiltersAndFailureMode() {
        let match = makeLog(id: "match", url: "https://api.example.com/v1/users",
                            method: .post, status: 200, durationMs: 800,
                            requestBody: "needle")
        let failed = makeLog(id: "failed", url: "https://api.example.com/v1/users",
                             method: .get, status: 500, durationMs: 50)

        var query = SJLogQuery()
        query.keyword = "NEEDLE"
        query.types = [.https]
        query.methods = [.post]
        query.statusBuckets = [.success]
        query.minDurationMs = 500
        query.path = "/v1/users"
        XCTAssertEqual(query.apply(to: [failed, match]).map { $0.id }, ["match"])

        var failedQuery = SJLogQuery()
        failedQuery.onlyFailed = true
        XCTAssertEqual(failedQuery.apply(to: [match, failed]).map { $0.id }, ["failed"])
    }

    func testEndpointGroupingAggregatesAndSortsByLatestRequest() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let success = makeLog(id: "success", url: "https://api.example.com/items?offset=0",
                              status: 200, durationMs: 100, startTime: older)
        let failure = makeLog(id: "failure", url: "https://api.example.com/items?offset=10",
                              status: 500, durationMs: 300, startTime: newer)
        let other = makeLog(id: "other", url: "https://api.example.com/profile",
                            status: 200, durationMs: 50, startTime: older)

        let groups = SJEndpointGroup.build(from: [failure, other, success])
        XCTAssertEqual(groups.map { $0.path }, ["/items", "/profile"])
        XCTAssertEqual(groups[0].count, 2)
        XCTAssertEqual(groups[0].successCount, 1)
        XCTAssertEqual(groups[0].failedCount, 1)
        XCTAssertEqual(groups[0].averageDuration, 200)
        XCTAssertEqual(groups[0].lastStatusCode, 500)
    }

    func testEndpointGroupingKeepsSamePathOnDifferentHostsSeparate() {
        let production = makeLog(id: "production", url: "https://api.example.com/v1/profile",
                                 status: 200, durationMs: 80)
        let staging = makeLog(id: "staging", url: "https://staging.example.com/v1/profile",
                              status: 500, durationMs: 120)

        let groups = SJEndpointGroup.build(from: [staging, production])

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.host)), Set(["api.example.com", "staging.example.com"]))
        XCTAssertTrue(groups.allSatisfy { $0.path == "/v1/profile" && $0.count == 1 })
    }

    func testBadgeIntrinsicWidthTracksItsText() {
        let badge = SJBadgeLabel()
        badge.setText("GET", color: .systemBlue)
        let shortWidth = badge.intrinsicContentSize.width

        badge.setText("WebSocket", color: .systemGreen)
        let longWidth = badge.intrinsicContentSize.width

        XCTAssertGreaterThan(shortWidth, 12)
        XCTAssertLessThan(shortWidth, 60)
        XCTAssertGreaterThan(longWidth, shortWidth)
    }

    func testCurlEscapesURLHeadersAndBodyForShell() {
        let log = makeLog(url: "https://example.com/o'reilly?x=1", method: .post,
                          status: 200, requestBody: "{'name':'O'Reilly'}")
        log.requestHeaders = ["X-Author": "O'Reilly"]

        let curl = SJLogExporter.curl(for: log)
        XCTAssertTrue(curl.contains("'https://example.com/o'\\''reilly?x=1'"))
        XCTAssertTrue(curl.contains("-H 'X-Author: O'\\''Reilly'"))
        XCTAssertTrue(curl.contains("--data "))
        XCTAssertTrue(curl.contains("'\\''name'\\''"))
        XCTAssertTrue(curl.contains("O'\\''Reilly"))
    }

    func testHARIncludesQueryItemsAndCaseInsensitiveContentTypes() throws {
        let log = makeLog(url: "https://example.com/search?q=swift&empty=", method: .post,
                          status: 200, requestBody: "{}", responseBody: "ok")
        log.requestHeaders = ["content-type": "application/json"]
        log.responseHeaders = ["CONTENT-TYPE": "text/plain"]

        let data = try XCTUnwrap(SJLogExporter.har(for: [log]).data(using: .utf8))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let harLog = try XCTUnwrap(root["log"] as? [String: Any])
        let entries = try XCTUnwrap(harLog["entries"] as? [[String: Any]])
        let request = try XCTUnwrap(entries.first?["request"] as? [String: Any])
        let response = try XCTUnwrap(entries.first?["response"] as? [String: Any])
        let query = try XCTUnwrap(request["queryString"] as? [[String: String]])
        let postData = try XCTUnwrap(request["postData"] as? [String: Any])
        let content = try XCTUnwrap(response["content"] as? [String: Any])

        XCTAssertEqual(query, [["name": "q", "value": "swift"], ["name": "empty", "value": ""]])
        XCTAssertEqual(postData["mimeType"] as? String, "application/json")
        XCTAssertEqual(content["mimeType"] as? String, "text/plain")
    }

    func testURLFilterHonorsIgnorePrecedenceAndInvalidRegexFallback() {
        let config = SJLoggerConfig.shared
        config.monitoredURLPatterns = ["api\\.example\\.com"]
        config.ignoredURLPatterns = ["/private"]

        XCTAssertTrue(config.shouldMonitor(url: "https://api.example.com/public"))
        XCTAssertFalse(config.shouldMonitor(url: "https://api.example.com/private"))
        XCTAssertFalse(config.shouldMonitor(url: "https://other.example.com/public"))

        config.monitoredURLPatterns = ["["]
        config.ignoredURLPatterns = []
        XCTAssertTrue(config.shouldMonitor(url: "https://example.com/[preview]"))
    }

    func testRedirectRequestRemovesHandledMarkerAndUnsupportedSchemesAreIgnored() {
        let mutableRequest = NSMutableURLRequest(url: URL(string: "https://example.com/final")!)
        URLProtocol.setProperty(true, forKey: "SJURLProtocolHandled", in: mutableRequest)
        XCTAssertFalse(SJURLProtocol.canInit(with: mutableRequest as URLRequest))

        let redirected = SJURLProtocol.requestForFollowingRedirect(mutableRequest as URLRequest)
        XCTAssertTrue(SJURLProtocol.canInit(with: redirected))
        XCTAssertFalse(SJURLProtocol.canInit(with: URLRequest(url: URL(fileURLWithPath: "/tmp/test"))))
    }

    func testConfigurationClampsInvalidLimits() {
        let config = SJLoggerConfig.shared
        config.maxLogCount = -10
        config.maxResponseBodySize = -10
        config.maxPersistedLogFileSize = -10
        config.slowRequestThresholdMs = -10

        XCTAssertEqual(config.maxLogCount, 1)
        XCTAssertEqual(config.maxResponseBodySize, 0)
        XCTAssertEqual(config.maxPersistedLogFileSize, 0)
        XCTAssertEqual(config.slowRequestThresholdMs, 0)
    }

    func testResponseBodyBufferDropsDataAsSoonAsLimitIsExceeded() {
        var buffer = SJResponseBodyBuffer(limit: 5)
        buffer.append(Data("12".utf8))
        buffer.append(Data("345".utf8))
        XCTAssertEqual(buffer.capturedData, Data("12345".utf8))

        buffer.append(Data("6".utf8))
        XCTAssertTrue(buffer.exceededLimit)
        XCTAssertNil(buffer.capturedData)

        var unlimited = SJResponseBodyBuffer(limit: 0)
        unlimited.append(Data(repeating: 1, count: 10_000))
        XCTAssertEqual(unlimited.capturedData?.count, 10_000)
    }

    func testCapturingStreamedRequestBodyPreservesForwardedPayload() {
        let body = Data("streamed-body".utf8)
        let request = NSMutableURLRequest(url: URL(string: "https://example.com/upload")!)
        request.httpBodyStream = InputStream(data: body)

        let captured = SJURLProtocol.captureRequestBody(from: request, enabled: true)
        XCTAssertEqual(captured, body)
        XCTAssertEqual(request.httpBody, body)
        XCTAssertNil(request.httpBodyStream)
    }

    func testHTTPRedirectReturnsFinalResponseAndLogsBothHops() throws {
        let server = try RedirectHTTPServer()
        defer { server.stop() }

        let serverReady = expectation(description: "Redirect server ready")
        var serverError: Error?
        server.start { error in
            serverError = error
            serverReady.fulfill()
        }
        wait(for: [serverReady], timeout: 3)
        XCTAssertNil(serverError)

        let redirectURL = try XCTUnwrap(server.redirectURL)
        let logger = SJLogger.shared
        if !logger.isStarted {
            logger.start { $0.showFloatingWindow = false }
        }

        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let requestFinished = expectation(description: "Redirect request finished")
        var receivedData: Data?
        var receivedResponse: HTTPURLResponse?
        var receivedError: Error?
        session.dataTask(with: redirectURL) { data, response, error in
            receivedData = data
            receivedResponse = response as? HTTPURLResponse
            receivedError = error
            requestFinished.fulfill()
        }.resume()
        wait(for: [requestFinished], timeout: 5)

        XCTAssertNil(receivedError)
        XCTAssertEqual(receivedResponse?.statusCode, 200)
        XCTAssertEqual(receivedData, Data("redirect-ok".utf8))

        let logsRead = expectation(description: "Both redirect hops stored")
        SJLoggerStorage.shared.getAllLogs { logs in
            let matching = logs.filter { $0.url.hasPrefix(server.baseURLString) }
            XCTAssertEqual(matching.count, 2)
            XCTAssertEqual(matching.first(where: { $0.path == "/redirect" })?.statusCode, 302)
            XCTAssertEqual(matching.first(where: { $0.path == "/final" })?.statusCode, 200)
            logsRead.fulfill()
        }
        wait(for: [logsRead], timeout: 2)
    }

    func testStorageKeepsNewestLogsAndCompletesOnMainThread() {
        SJLoggerConfig.shared.maxLogCount = 3
        for index in 0..<5 {
            SJLoggerStorage.shared.addLog(makeLog(id: "\(index)"))
        }

        let expectation = expectation(description: "Read capped logs")
        SJLoggerStorage.shared.getAllLogs { logs in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(logs.map { $0.id }, ["4", "3", "2"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testStorageUpdatesLogAtomicallyByID() {
        let log = makeLog(id: "atomic", status: nil)
        SJLoggerStorage.shared.addLog(log)

        var initialSnapshot: SJLoggerModel?
        let initialRead = expectation(description: "Read initial snapshot")
        SJLoggerStorage.shared.getLog(byId: log.id) { storedLog in
            initialSnapshot = storedLog
            XCTAssertFalse(storedLog === log)
            initialRead.fulfill()
        }
        wait(for: [initialRead], timeout: 2)

        SJLoggerStorage.shared.updateLog(byId: log.id) {
            $0.statusCode = 204
            $0.endTime = $0.startTime.addingTimeInterval(0.1)
        }

        let expectation = expectation(description: "Read updated log")
        SJLoggerStorage.shared.getAllLogs { logs in
            XCTAssertNil(initialSnapshot?.statusCode)
            XCTAssertFalse(initialSnapshot === logs.first)
            XCTAssertEqual(logs.first?.statusCode, 204)
            XCTAssertEqual(logs.first?.duration, 100)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testConcurrentStorageAddsRespectConfiguredLimit() {
        SJLoggerConfig.shared.maxLogCount = 50
        DispatchQueue.concurrentPerform(iterations: 200) { index in
            SJLoggerStorage.shared.addLog(makeLog(id: "concurrent-\(index)"))
        }

        let expectation = expectation(description: "Read concurrent logs")
        SJLoggerStorage.shared.getAllLogs { logs in
            XCTAssertEqual(logs.count, 50)
            XCTAssertEqual(Set(logs.map { $0.id }).count, 50)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
    }

    func testClearingPersistedLogsCancelsPendingDiskWrite() {
        let config = SJLoggerConfig.shared
        config.persistLogs = true
        let storage = SJLoggerStorage.shared

        storage.clearPersistedLogs()
        let initialClear = expectation(description: "Initial persisted logs cleared")
        storage.getPersistedLogs { logs in
            XCTAssertTrue(logs.isEmpty)
            initialClear.fulfill()
        }
        wait(for: [initialClear], timeout: 2)

        storage.addLog(makeLog(id: "pending-persist"))
        storage.clearPersistedLogs()

        let delayedRead = expectation(description: "Cancelled persist is not written back")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            storage.getPersistedLogs { logs in
                XCTAssertTrue(logs.isEmpty)
                delayedRead.fulfill()
            }
        }
        wait(for: [delayedRead], timeout: 3)
    }

    func testLoggerReinjectsURLProtocolAfterRestart() {
        let logger = SJLogger.shared
        if !logger.isStarted {
            logger.start { $0.showFloatingWindow = false }
        }

        logger.stop()
        XCTAssertFalse(URLSessionConfiguration.default.protocolClasses?.contains {
            $0 == SJURLProtocol.self
        } ?? false)

        logger.start { $0.showFloatingWindow = false }
        XCTAssertTrue(URLSessionConfiguration.default.protocolClasses?.contains {
            $0 == SJURLProtocol.self
        } ?? false)
    }

    func testWebSocketSentMessageIsStoredWithDirection() {
        SJLogger.logWebSocketSent(url: "wss://example.com/socket", text: "hello")

        let expectation = expectation(description: "Read WebSocket log")
        SJLoggerStorage.shared.getAllLogs { logs in
            XCTAssertEqual(logs.first?.type, .websocket)
            XCTAssertEqual(logs.first?.wsDirection, .sent)
            XCTAssertEqual(logs.first?.wsEventName, "Send (Text)")
            XCTAssertEqual(logs.first?.requestBodyString, "hello")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testJSONFormattingHelpers() {
        let json = "{\"b\":2,\"a\":1}"
        XCTAssertTrue(json.isJSON)
        let compact = json.compactJSON
        XCTAssertFalse(compact?.contains("\n") == true)
        XCTAssertFalse(compact?.contains(" ") == true)
        let object = compact?.data(using: .utf8).flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? NSDictionary
        }
        XCTAssertEqual(object, ["a": 1, "b": 2] as NSDictionary)
        XCTAssertTrue(json.prettyJSON?.contains("\n") == true)
        XCTAssertFalse("not-json".isJSON)
    }

    func testShowLogListIgnoresRepeatedPresentationRequests() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()

        let expectation = expectation(description: "Only one log list is presented")
        SJLogger.shared.showLogList(from: host)
        SJLogger.shared.showLogList(from: host)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let navigationController = host.presentedViewController as? UINavigationController
            XCTAssertNotNil(navigationController)
            XCTAssertTrue(navigationController?.viewControllers.first is SJLogListViewController)
            XCTAssertNil(navigationController?.presentedViewController)

            navigationController?.dismiss(animated: false) {
                window.isHidden = true
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2)
    }

    func testCompactToolbarCollapsesAndRestoresWithScrollDirection() throws {
        let logs = (0..<20).map { index in
            makeLog(id: "layout-\(index)", url: "https://api.example.com/items/\(index)",
                    durationMs: Double(index * 10))
        }
        let viewController = SJLogListViewController(title: "布局测试", logs: logs)
        let window = makeTestWindow(size: CGSize(width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.view.frame = window.bounds
        viewController.view.layoutIfNeeded()

        let filterBar: SJCompactFilterBar = try XCTUnwrap(firstSubview(in: viewController.view))
        let tableView: UITableView = try XCTUnwrap(firstSubview(in: viewController.view))
        XCTAssertEqual(filterBar.superview?.bounds.height ?? -1, 40, accuracy: 0.5)

        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            UIView.setAnimationsEnabled(animationsWereEnabled)
            window.isHidden = true
        }

        var targetOffset = CGPoint(x: 0, y: 300)
        viewController.scrollViewWillEndDragging(tableView,
                                                 withVelocity: CGPoint(x: 0, y: 1),
                                                 targetContentOffset: &targetOffset)
        viewController.view.layoutIfNeeded()
        XCTAssertEqual(filterBar.superview?.bounds.height ?? -1, 0, accuracy: 0.5)

        viewController.scrollViewWillEndDragging(tableView,
                                                 withVelocity: CGPoint(x: 0, y: -1),
                                                 targetContentOffset: &targetOffset)
        viewController.view.layoutIfNeeded()
        XCTAssertEqual(filterBar.superview?.bounds.height ?? -1, 40, accuracy: 0.5)
    }

    func testEndpointSearchCancelRestoresResultsAndBodySearchMatchesRequests() throws {
        SJLoggerConfig.shared.defaultRefreshMode = .live
        SJLoggerStorage.shared.addLog(makeLog(responseBody: "unique-payload"))
        let vc = SJLogListViewController()
        vc.loadViewIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: vc.view))
        waitUntil { table.numberOfRows(inSection: 0) == 1 }
        let segments: UISegmentedControl = try XCTUnwrap(firstSubview(in: vc.view))
        segments.selectedSegmentIndex = 1
        segments.sendActions(for: .valueChanged)
        let endpoint = try XCTUnwrap(vc.children.first as? SJEndpointListViewController)
        let endpointTable: UITableView = try XCTUnwrap(firstSubview(in: endpoint.view))
        waitUntil { endpointTable.numberOfRows(inSection: 0) == 1 }
        let search: UISearchBar = try XCTUnwrap(firstSubview(in: vc.view))
        vc.searchBar(search, textDidChange: "no-match")
        waitUntil { endpointTable.numberOfRows(inSection: 0) == 0 }
        vc.searchBarCancelButtonClicked(search)
        waitUntil { endpointTable.numberOfRows(inSection: 0) == 1 }
        vc.searchBar(search, textDidChange: "unique-payload")
        waitUntil { endpointTable.numberOfRows(inSection: 0) == 1 }
        vc.searchBarCancelButtonClicked(search)
    }

    func testFrozenEmptyListDisplaysFirstIncomingRequest() throws {
        SJLoggerConfig.shared.defaultRefreshMode = .frozen
        let vc = SJLogListViewController()
        vc.loadViewIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: vc.view))
        let initial = expectation(description: "Initial empty storage read")
        SJLoggerStorage.shared.getAllLogs { _ in initial.fulfill() }
        wait(for: [initial], timeout: 2)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 0)
        SJLoggerStorage.shared.addLog(makeLog(id: "first-arrival"))
        waitUntil { table.numberOfRows(inSection: 0) == 1 }
    }

    func testFrozenListDetectsNewIDsAtCapacityAndRefreshesBothTabs() throws {
        SJLoggerConfig.shared.defaultRefreshMode = .frozen
        SJLoggerConfig.shared.maxLogCount = 2
        SJLoggerStorage.shared.addLog(makeLog(id: "oldest", url: "https://example.com/oldest"))
        SJLoggerStorage.shared.addLog(makeLog(id: "retained", url: "https://example.com/retained"))
        let vc = SJLogListViewController()
        vc.loadViewIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: vc.view))
        waitUntil { table.numberOfRows(inSection: 0) == 2 }
        SJLoggerStorage.shared.addLog(makeLog(id: "new", url: "https://example.com/new"))
        waitUntil { self.allSubviews(in: vc.view).compactMap { $0 as? UIButton }.contains {
            !$0.isHidden && ($0.title(for: .normal)?.contains("1 条新请求") ?? false)
        } }
        let banner = try XCTUnwrap(allSubviews(in: vc.view).compactMap { $0 as? UIButton }.first {
            $0.title(for: .normal)?.contains("1 条新请求") ?? false
        })
        banner.sendActions(for: .touchUpInside)
        waitUntil { table.numberOfRows(inSection: 0) == 2 && banner.isHidden }
        let segments: UISegmentedControl = try XCTUnwrap(firstSubview(in: vc.view))
        segments.selectedSegmentIndex = 1
        segments.sendActions(for: .valueChanged)
        let endpoint = try XCTUnwrap(vc.children.first as? SJEndpointListViewController)
        let endpointTable: UITableView = try XCTUnwrap(firstSubview(in: endpoint.view))
        waitUntil { endpointTable.numberOfRows(inSection: 0) == 2 }
        SJLoggerStorage.shared.clearCurrentLogs()
        waitUntil { table.numberOfRows(inSection: 0) == 0 && endpointTable.numberOfRows(inSection: 0) == 0 }
    }

    func testPendingRequestIsNotFailureAndSearchIncludesHeaders() {
        let pending = makeLog(status: nil)
        let redirect = makeLog(status: 302)
        let failed = makeLog(status: 503)
        var query = SJLogQuery()
        query.onlyFailed = true
        XCTAssertEqual(query.apply(to: [pending, redirect, failed]).map(\.id), [failed.id])
        query = SJLogQuery()
        pending.requestHeaders = ["X-Trace": "trace-value"]
        query.keyword = "  TRACE-VALUE  "
        XCTAssertEqual(query.apply(to: [pending]).map(\.id), [pending.id])
    }

    func testOpenDetailUpdatesWhenRequestCompletes() {
        let log = makeLog(id: "detail-pending", status: nil)
        SJLoggerStorage.shared.addLog(log)
        let vc = SJLogDetailViewController(log: log)
        vc.loadViewIfNeeded()
        SJLoggerStorage.shared.updateLog(byId: log.id) {
            $0.statusCode = 200
            $0.responseBody = Data("completed-response".utf8)
            $0.endTime = Date()
        }
        waitUntil { self.allSubviews(in: vc.view).compactMap { $0 as? UITextView }.contains {
            $0.text.contains("completed-response")
        } }
    }

    func testResetFiltersRestoresRowsAndCountsAfterScrolling() throws {
        let logs = (0..<30).map { makeLog(id: "scroll-\($0)", url: "https://example.com/items/\($0)") }
        let vc = SJLogListViewController(title: "历史日志", logs: logs)
        let window = makeTestWindow(size: CGSize(width: 320, height: 568))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        vc.view.layoutIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: vc.view))
        table.setContentOffset(CGPoint(x: 0, y: 1800), animated: false)
        let search: UISearchBar = try XCTUnwrap(firstSubview(in: vc.view))
        vc.searchBar(search, textDidChange: "no-such-request")
        XCTAssertEqual(table.numberOfRows(inSection: 0), 0)
        let reset = try XCTUnwrap(allSubviews(in: vc.view).first { $0.accessibilityIdentifier == "logger.resetFilters" } as? UIButton)
        XCTAssertFalse(reset.isHidden)
        let status = try XCTUnwrap(allSubviews(in: vc.view).first { $0.accessibilityIdentifier == "logger.status" } as? UILabel)
        XCTAssertTrue(status.text?.contains("0 / 30") == true)
        reset.sendActions(for: .touchUpInside)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 30)
        XCTAssertEqual(table.contentOffset.y, -table.adjustedContentInset.top, accuracy: 1)
        XCTAssertTrue(reset.isHidden)
        XCTAssertTrue(status.text?.contains("30 / 30") == true)
        XCTAssertFalse(table.visibleCells.isEmpty)
        let swipe = vc.tableView(table, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(swipe?.actions.map(\.title), ["分享"])
        attachScreenshot(window, name: "Small-screen-list")
        window.overrideUserInterfaceStyle = .dark
        vc.searchBar(search, textDidChange: "no-such-request")
        vc.view.layoutIfNeeded()
        attachScreenshot(window, name: "Dark-filter-empty-state")
    }

    func testSelectionCanToggleSameRowTwiceAndResumeUpdates() throws {
        SJLoggerConfig.shared.defaultRefreshMode = .live
        SJLoggerStorage.shared.addLog(makeLog(id: "selectable"))
        let vc = SJLogListViewController()
        vc.loadViewIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: vc.view))
        waitUntil { table.numberOfRows(inSection: 0) == 1 }
        _ = vc.perform(NSSelectorFromString("toggleSelectionMode"))
        let status = try XCTUnwrap(allSubviews(in: vc.view).first { $0.accessibilityIdentifier == "logger.status" } as? UILabel)
        vc.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(status.text, "已选 1 / 1 条")
        vc.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(status.text, "已选 0 / 1 条")
        SJLoggerStorage.shared.addLog(makeLog(id: "after-selection"))
        _ = vc.perform(NSSelectorFromString("toggleSelectionMode"))
        waitUntil { table.numberOfRows(inSection: 0) == 2 }
    }

    func testFrozenTabsStayConsistentUntilExplicitRefresh() throws {
        SJLoggerConfig.shared.defaultRefreshMode = .frozen
        SJLoggerStorage.shared.addLog(makeLog(id: "visible", url: "https://example.com/visible"))
        let vc = SJLogListViewController()
        vc.loadViewIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: vc.view))
        waitUntil { table.numberOfRows(inSection: 0) == 1 }
        let segments: UISegmentedControl = try XCTUnwrap(firstSubview(in: vc.view))
        segments.selectedSegmentIndex = 1
        segments.sendActions(for: .valueChanged)
        let endpoint = try XCTUnwrap(vc.children.first as? SJEndpointListViewController)
        let endpointTable: UITableView = try XCTUnwrap(firstSubview(in: endpoint.view))
        SJLoggerStorage.shared.addLog(makeLog(id: "pending", url: "https://example.com/pending"))
        waitUntil { self.allSubviews(in: vc.view).compactMap { $0 as? UIButton }.contains {
            !$0.isHidden && ($0.title(for: .normal)?.contains("1 条新请求") ?? false)
        } }
        XCTAssertEqual(endpointTable.numberOfRows(inSection: 0), 1)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        endpointTable.refreshControl?.sendActions(for: .valueChanged)
        waitUntil { endpointTable.numberOfRows(inSection: 0) == 2 && table.numberOfRows(inSection: 0) == 2 }
    }

    func testRequestEndpointAndDetailLayouts() throws {
        SJLoggerConfig.shared.defaultRefreshMode = .live
        for index in 0..<9 {
            SJLoggerStorage.shared.addLog(makeLog(id: "preview-\(index)",
                url: "https://api.example.com/v1/\(index < 3 ? "profile" : "feed/\(index)")",
                method: index % 2 == 0 ? .get : .post, status: index % 3 == 0 ? 500 : 200,
                durationMs: index % 3 == 0 ? 2400 : 120,
                responseBody: "{\"message\":\"Sample response\",\"items\":[1,2,3]}"))
        }
        let vc = SJLogListViewController()
        let nav = UINavigationController(rootViewController: vc)
        let window = makeTestWindow(size: CGSize(width: 390, height: 844))
        window.rootViewController = nav
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let table: UITableView = try XCTUnwrap(firstSubview(in: vc.view))
        waitUntil { table.numberOfRows(inSection: 0) == 9 }
        window.layoutIfNeeded()
        nav.view.frame = window.bounds
        nav.view.layoutIfNeeded()
        vc.view.layoutIfNeeded()
        XCTAssertGreaterThan(table.bounds.height, 200)
        attachScreenshot(window, name: "Request-list")
        let segments: UISegmentedControl = try XCTUnwrap(firstSubview(in: vc.view))
        segments.selectedSegmentIndex = 1
        segments.sendActions(for: .valueChanged)
        vc.view.layoutIfNeeded()
        let endpoint = try XCTUnwrap(vc.children.first as? SJEndpointListViewController)
        let endpointTable: UITableView = try XCTUnwrap(firstSubview(in: endpoint.view))
        XCTAssertEqual(endpointTable.numberOfRows(inSection: 0), 7)
        attachScreenshot(window, name: "Endpoint-list")
        segments.selectedSegmentIndex = 0
        segments.sendActions(for: .valueChanged)
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        vc.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        nav.view.layoutIfNeeded()
        let detail = try XCTUnwrap(nav.topViewController as? SJLogDetailViewController)
        waitUntil { nav.transitionCoordinator == nil }
        nav.view.layoutIfNeeded()
        detail.view.layoutIfNeeded()
        XCTAssertFalse(allSubviews(in: detail.view).compactMap { $0 as? UITextView }.isEmpty)
        attachScreenshot(window, name: "Request-detail")
    }

    func testBusinessFailureWithHTTP200AffectsQueryStatsAndExport() throws {
        let failed = makeLog(id: "business-failure", status: 200,
                             responseBody: #"{"code":4,"message":"库存不足","data":null}"#)
        let success = makeLog(id: "business-success", status: 200,
                              responseBody: #"{"code":0,"message":"ok","data":{}}"#)
        XCTAssertEqual(failed.businessError?.code, "4")
        XCTAssertEqual(failed.businessError?.message, "库存不足")
        XCTAssertEqual(failed.statusCode, 200)
        XCTAssertNil(failed.error)
        XCTAssertFalse(failed.isSuccess)
        XCTAssertTrue(failed.isFailure)
        XCTAssertTrue(success.isSuccess)
        XCTAssertFalse(success.isFailure)
        var query = SJLogQuery()
        query.onlyFailed = true
        XCTAssertEqual(query.apply(to: [success, failed]).map(\.id), [failed.id])
        query.onlyFailed = false
        query.statusBuckets = [.businessError]
        XCTAssertEqual(query.apply(to: [success, failed]).map(\.id), [failed.id])
        let groups = SJEndpointGroup.build(from: [failed, success])
        XCTAssertEqual(groups.first?.failedCount, 1)
        XCTAssertEqual(groups.first?.successCount, 1)
        XCTAssertEqual(groups.first?.successRate, 0.5)
        XCTAssertTrue(failed.generateLogText().contains("Business Message: 库存不足"))
        let har = try XCTUnwrap(SJLogExporter.har(for: [failed]).data(using: .utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: har) as? [String: Any])
        let harLog = try XCTUnwrap(json["log"] as? [String: Any])
        let entry = try XCTUnwrap((harLog["entries"] as? [[String: Any]])?.first)
        XCTAssertEqual((entry["response"] as? [String: Any])?["status"] as? Int, 200)
        XCTAssertEqual((entry["_businessResult"] as? [String: Any])?["message"] as? String, "库存不足")
        SJLoggerStorage.shared.addLog(success)
        SJLoggerStorage.shared.addLog(failed)
        let read = expectation(description: "Business failures counted by storage")
        SJLoggerStorage.shared.getStatistics { stats in
            XCTAssertEqual(stats["success"] as? Int, 1)
            XCTAssertEqual(stats["failed"] as? Int, 1)
            read.fulfill()
        }
        wait(for: [read], timeout: 2)
    }

    func testBusinessParserHandlesStringsUnknownBodiesAndWebSocket() {
        for code in [1, 2, 4, 5, 98, 99] {
            let log = makeLog(responseBody: "{\"code\":\(code),\"message\":\"服务端错误\"}")
            XCTAssertTrue(log.isFailure)
        }
        let stringCode = makeLog(responseBody: #"{"code":"5","msg":"登录已过期"}"#)
        XCTAssertEqual(stringCode.businessError?.code, "5")
        for body in [#"{"code":true,"message":"flag"}"#, #"{"code":4}"#,
                     #"{"code":null,"message":"missing"}"#, #"{"code":4.5,"message":"invalid"}"#,
                     #"{"data":{"code":4,"message":"nested"}}"#, "not-json", "[]"] {
            let log = makeLog(responseBody: body)
            XCTAssertNil(log.businessResult, body)
            XCTAssertTrue(log.isSuccess, body)
        }
        let ws = SJLoggerModel(type: .websocket, url: "wss://example.com/socket")
        ws.responseBody = Data(#"{"code":4,"message":"event"}"#.utf8)
        XCTAssertNil(ws.businessResult)
        XCTAssertNil(makeLog(status: nil).businessResult)
        let httpFailure = makeLog(status: 500, responseBody: #"{"code":0,"message":"ok"}"#)
        XCTAssertFalse(httpFailure.isSuccess)
        XCTAssertTrue(httpFailure.isFailure)
    }

    func testBusinessResultUsesDecryptedBodyAndSurvivesPersistence() throws {
        let encrypted = Data("encrypted-test-payload".utf8)
        SJLoggerConfig.shared.bodyDecryptor = { data in
            data == encrypted ? #"{"code":99,"message":"服务器内部错误"}"# : nil
        }
        let log = makeLog(status: 200)
        log.responseBody = encrypted
        XCTAssertEqual(log.businessError?.code, "99")
        XCTAssertEqual(log.responseBody, encrypted)
        let decoded = try JSONDecoder().decode(SJLoggerModel.self, from: JSONEncoder().encode(log))
        XCTAssertEqual(decoded.businessError?.message, "服务器内部错误")
        XCTAssertEqual(decoded.snapshot().businessError, log.businessError)
        XCTAssertEqual(decoded.responseBody, encrypted)
        log.responseBody = Data(#"{"code":0,"message":"ok"}"#.utf8)
        XCTAssertTrue(log.isSuccess)
        XCTAssertNil(log.businessError)
    }

    func testBusinessParserCanBeScopedCustomizedAndDisabled() {
        let failure = makeLog(responseBody: #"{"code":4,"message":"失败"}"#)
        SJLoggerConfig.shared.businessResultParser = nil
        XCTAssertNil(failure.businessResult)
        XCTAssertTrue(failure.isSuccess)
        SJLoggerConfig.shared.businessResultParser = { log in
            guard log.host == "api.example.com" else { return nil }
            return SJBusinessResult(code: "E_STOCK", message: "库存不足", isSuccess: false)
        }
        XCTAssertNil(failure.businessResult)
        let custom = makeLog(url: "https://api.example.com/items", responseBody: "custom-envelope")
        XCTAssertEqual(custom.businessError?.code, "E_STOCK")
        XCTAssertFalse(custom.isSuccess)
        var query = SJLogQuery()
        query.keyword = "库存不足"
        XCTAssertEqual(query.apply(to: [custom, failure]).map(\.id), [custom.id])
    }

    func testBusinessFailureIsVisibleInListDetailAndClearedOnCellReuse() throws {
        let log = makeLog(status: 200, responseBody: #"{"code":4,"message":"库存不足，请减少购买数量"}"#)
        let cell = SJLogCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: log)
        let label = try XCTUnwrap(allSubviews(in: cell).first {
            $0.accessibilityIdentifier == "logger.businessError"
        } as? UILabel)
        XCTAssertFalse(label.isHidden)
        XCTAssertTrue(label.text?.contains("库存不足") == true)
        XCTAssertTrue(cell.accessibilityLabel?.contains("业务失败") == true)
        cell.configure(with: makeLog(responseBody: #"{"code":0,"message":"ok"}"#))
        XCTAssertTrue(label.isHidden)
        XCTAssertNil(label.text)

        let vc = SJLogListViewController(title: "业务错误", logs: [log])
        let window = makeTestWindow(size: CGSize(width: 320, height: 568))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: vc.view))
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        XCTAssertGreaterThan(table.rectForRow(at: IndexPath(row: 0, section: 0)).height, 80)
        attachScreenshot(window, name: "Business-error-list")
        let detail = SJLogDetailViewController(log: log, updatesFromStorage: false)
        window.rootViewController = detail
        window.layoutIfNeeded()
        XCTAssertTrue(allSubviews(in: detail.view).compactMap { $0 as? UITextView }.contains {
            $0.text.contains("业务码: 4") && $0.text.contains("库存不足")
        })
        attachScreenshot(window, name: "Business-error-detail")
    }

    func testBusinessErrorAppearsWhenPendingResponseCompletes() throws {
        SJLoggerConfig.shared.defaultRefreshMode = .live
        let pending = makeLog(id: "pending-business", status: nil)
        SJLoggerStorage.shared.addLog(pending)
        let list = SJLogListViewController()
        list.loadViewIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: list.view))
        waitUntil { table.numberOfRows(inSection: 0) == 1 }
        let filter: SJCompactFilterBar = try XCTUnwrap(firstSubview(in: list.view))
        filter.onSelect?(1)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 0)
        let detail = SJLogDetailViewController(log: pending)
        detail.loadViewIfNeeded()
        SJLoggerStorage.shared.updateLog(byId: pending.id) {
            $0.statusCode = 200
            $0.responseBody = Data(#"{"code":5,"message":"登录已过期"}"#.utf8)
            $0.endTime = Date()
        }
        waitUntil { table.numberOfRows(inSection: 0) == 1 }
        waitUntil { self.allSubviews(in: detail.view).compactMap { $0 as? UITextView }.contains {
            $0.text.contains("业务码: 5")
        } }
    }

    func testTextShareExportsAReadableFileWithOnlyRequestedLogs() throws {
        let first = makeLog(id: "included", responseBody: #"{"code":4,"message":"库存不足"}"#)
        let file = try SJLogExporter.exportFile(for: [first])
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertTrue(file.isFileURL)
        XCTAssertEqual(file.pathExtension, "txt")
        let content = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(content.contains("日志数量: 1"))
        XCTAssertTrue(content.contains("ID: included"))
        XCTAssertTrue(content.contains("Business Message: 库存不足"))
        XCTAssertThrowsError(try SJLogExporter.exportFile(for: []))
    }

    func testHARShareExportsJSONFileAndRepeatedExportsDoNotOverwrite() throws {
        let log = makeLog(status: 200, responseBody: #"{"code":4,"message":"业务错误"}"#)
        let first = try SJLogExporter.exportFile(for: [log], format: .har)
        let second = try SJLogExporter.exportFile(for: [log], format: .har)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.pathExtension, "har")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: first)) as? [String: Any])
        let har = try XCTUnwrap(root["log"] as? [String: Any])
        let entries = try XCTUnwrap(har["entries"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual((entries[0]["response"] as? [String: Any])?["status"] as? Int, 200)
        XCTAssertEqual((entries[0]["_businessResult"] as? [String: Any])?["code"] as? String, "4")
        XCTAssertEqual(try Data(contentsOf: first), try Data(contentsOf: second))
    }

    func testExportFileCleanupPreservesRecentAttachmentsAndWriteErrorsPropagate() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("SJLogger-export-test-" + UUID().uuidString)
        defer { try? fm.removeItem(at: folder) }
        let old = try SJLogExporter.writeFile(contents: "old", format: .text, directory: folder)
        let unrelated = folder.appendingPathComponent("unrelated.txt")
        try Data("keep".utf8).write(to: unrelated)
        let expiry = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        try fm.setAttributes([.modificationDate: expiry], ofItemAtPath: old.path)
        try fm.setAttributes([.modificationDate: expiry], ofItemAtPath: unrelated.path)
        let current = try SJLogExporter.writeFile(contents: "current", format: .text, directory: folder)
        _ = try SJLogExporter.writeFile(contents: "next", format: .har, directory: folder)
        XCTAssertFalse(fm.fileExists(atPath: old.path))
        XCTAssertEqual(try String(contentsOf: current), "current")
        XCTAssertTrue(fm.fileExists(atPath: unrelated.path))
        XCTAssertThrowsError(try SJLogExporter.writeFile(contents: "fail", format: .text, directory: current))
    }

    func testDetailSharePresentsFileAndKeepsAttachmentAfterCancel() throws {
        let marker = "share-file-" + UUID().uuidString
        let vc = SJLogDetailViewController(log: makeLog(id: marker), updatesFromStorage: false)
        let window = makeTestWindow(size: CGSize(width: 390, height: 844))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        _ = vc.perform(NSSelectorFromString("shareLog"))
        waitUntil { vc.presentedViewController is UIActivityViewController }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SJLogger-Exports")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let file = try XCTUnwrap(files.first {
            (try? String(contentsOf: $0, encoding: .utf8).contains(marker)) == true
        })
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(file.pathExtension, "txt")
        let sheet = try XCTUnwrap(vc.presentedViewController as? UIActivityViewController)
        sheet.completionWithItemsHandler?(nil, false, nil, nil)
        vc.dismiss(animated: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testCancellationIsSeparateFromFailureAcrossQueryStatsAndExport() throws {
        let cancelled = makeLog(id: "cancelled", status: 200)
        cancelled.error = "cancelled"
        cancelled.errorDomain = NSURLErrorDomain
        cancelled.errorCode = NSURLErrorCancelled
        cancelled.cancellationSource = "URLProtocol.stopLoading"
        let timeout = makeLog(id: "timeout", status: nil)
        timeout.error = "timed out"
        timeout.errorDomain = NSURLErrorDomain
        timeout.errorCode = NSURLErrorTimedOut
        let otherDomain = makeLog(id: "other-domain", status: nil)
        otherDomain.error = "-999 from another subsystem"
        otherDomain.errorDomain = "ExampleErrorDomain"
        otherDomain.errorCode = -999
        let success = makeLog(id: "success")
        let pending = makeLog(id: "pending", status: nil)
        let logs = [cancelled, timeout, otherDomain, success, pending]
        XCTAssertTrue(cancelled.isCancelled)
        XCTAssertFalse(cancelled.isSuccess)
        XCTAssertFalse(cancelled.isFailure)
        XCTAssertTrue(timeout.isFailure)
        XCTAssertFalse(otherDomain.isCancelled)
        XCTAssertTrue(otherDomain.isFailure)
        var query = SJLogQuery()
        query.onlyFailed = true
        XCTAssertEqual(query.apply(to: logs).map(\.id), [timeout.id, otherDomain.id])
        query.onlyFailed = false
        query.statusBuckets = [.cancelled]
        XCTAssertEqual(query.apply(to: logs).map(\.id), [cancelled.id])
        query.statusBuckets = [.error]
        XCTAssertEqual(query.apply(to: logs).map(\.id), [timeout.id, otherDomain.id])
        query.onlyCancelled = true
        XCTAssertTrue(query.apply(to: logs).isEmpty)
        let group = try XCTUnwrap(SJEndpointGroup.build(from: logs).first)
        XCTAssertEqual(group.cancelledCount, 1)
        XCTAssertEqual(group.failedCount, 2)
        XCTAssertEqual(group.successRate, 1.0 / 3.0, accuracy: 0.001)
        for log in logs { SJLoggerStorage.shared.addLog(log) }
        let statsRead = expectation(description: "Cancellation statistics")
        SJLoggerStorage.shared.getStatistics { stats in
            XCTAssertEqual(stats["total"] as? Int, 5)
            XCTAssertEqual(stats["success"] as? Int, 1)
            XCTAssertEqual(stats["failed"] as? Int, 2)
            XCTAssertEqual(stats["cancelled"] as? Int, 1)
            statsRead.fulfill()
        }
        wait(for: [statsRead], timeout: 2)
        XCTAssertTrue(cancelled.generateLogText().contains("Result: 已取消"))
        let json = try XCTUnwrap(SJLogExporter.har(for: [cancelled]).data(using: .utf8))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let har = try XCTUnwrap(root["log"] as? [String: Any])
        let entry = try XCTUnwrap((har["entries"] as? [[String: Any]])?.first)
        XCTAssertEqual(entry["_cancelled"] as? Bool, true)
        XCTAssertEqual(entry["_errorCode"] as? Int, -999)
        XCTAssertEqual(entry["_errorDomain"] as? String, NSURLErrorDomain)
        XCTAssertEqual(entry["_cancellationSource"] as? String, "URLProtocol.stopLoading")
    }

    func testCancellationMetadataSurvivesSnapshotsAndLegacyDecoding() throws {
        let log = makeLog(status: nil)
        log.error = "localized cancellation message"
        log.errorDomain = NSURLErrorDomain
        log.errorCode = NSURLErrorCancelled
        log.cancellationSource = "URLSession.didCompleteWithError"
        let encoded = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(SJLoggerModel.self, from: encoded)
        XCTAssertTrue(decoded.isCancelled)
        XCTAssertTrue(decoded.snapshot().isCancelled)
        XCTAssertEqual(decoded.snapshot().cancellationSource, log.cancellationSource)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "errorDomain")
        legacy.removeValue(forKey: "errorCode")
        legacy.removeValue(forKey: "cancellationSource")
        let old = try JSONDecoder().decode(SJLoggerModel.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(old.errorCode)
        XCTAssertFalse(old.isCancelled) // 不从本地化文本猜测历史错误类型。
        XCTAssertTrue(old.isFailure)
    }

    func testCancelledRequestHasNeutralUIAndOwnQuickFilter() throws {
        let cancelled = makeLog(status: nil)
        cancelled.error = "cancelled"
        cancelled.errorDomain = NSURLErrorDomain
        cancelled.errorCode = NSURLErrorCancelled
        let cell = SJLogCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: cancelled)
        XCTAssertTrue(cell.accessibilityLabel?.contains("已取消") == true)
        let status = try XCTUnwrap(allSubviews(in: cell).compactMap { $0 as? UILabel }.first { $0.text == "已取消" })
        XCTAssertEqual(status.textColor, UIColor.secondaryLabel)
        cell.configure(with: makeLog())
        XCTAssertFalse(cell.accessibilityLabel?.contains("已取消") == true)
        let detail = SJLogDetailViewController(log: cancelled, updatesFromStorage: false)
        detail.loadViewIfNeeded()
        XCTAssertTrue(allSubviews(in: detail.view).compactMap { $0 as? UITextView }.contains {
            $0.text.contains("错误码: -999") && $0.text.contains("具体业务原因未知")
        })
        let list = SJLogListViewController(title: "取消分类", logs: [cancelled, makeLog(), makeLog(status: 500)])
        list.loadViewIfNeeded()
        let table: UITableView = try XCTUnwrap(firstSubview(in: list.view))
        let filter: SJCompactFilterBar = try XCTUnwrap(firstSubview(in: list.view))
        filter.onSelect?(SJQuickFilter.cancelled.rawValue)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        let row = try XCTUnwrap(list.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? SJLogCell)
        XCTAssertTrue(row.accessibilityLabel?.contains("已取消") == true)
        filter.onSelect?(SJQuickFilter.failed.rawValue)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
    }

    func testCompletionReenteringStopLoadingPreservesSuccessfulResponse() throws {
        try exerciseProtocolCompletion(cancelOnResponse: false)
    }

    func testStoppingDuringResponseRecordsCancellationOnlyOnce() throws {
        try exerciseProtocolCompletion(cancelOnResponse: true)
    }

    private func exerciseProtocolCompletion(cancelOnResponse: Bool) throws {
        let server = try RedirectHTTPServer()
        defer { server.stop() }
        let ready = expectation(description: "Local server ready")
        server.start { error in
            XCTAssertNil(error)
            ready.fulfill()
        }
        wait(for: [ready], timeout: 3)
        let url = try XCTUnwrap(URL(string: server.baseURLString + "/final"))
        let client = ReentrantProtocolClient()
        let intercepted = SJURLProtocol(request: URLRequest(url: url), cachedResponse: nil, client: client)
        let completed = expectation(description: "Protocol reaches expected callback")
        client.onResponse = { instance in
            if cancelOnResponse {
                instance.stopLoading()
                completed.fulfill()
            }
        }
        client.onFinish = { instance in
            XCTAssertFalse(cancelOnResponse, "No completion callback after cancellation")
            instance.stopLoading() // 确定性复现原先先回调、后保存导致的 -999 覆盖。
            completed.fulfill()
        }
        client.onError = { error in XCTFail("Unexpected client error: \(error)") }
        intercepted.startLoading()
        wait(for: [completed], timeout: 5)
        intercepted.stopLoading() // 重复 stop 不应覆盖第一次终态。
        let read = expectation(description: "Final log stored once")
        SJLoggerStorage.shared.getAllLogs { logs in
            let matching = logs.filter { $0.url == url.absoluteString }
            XCTAssertEqual(matching.count, 1)
            let log = matching.first
            XCTAssertNotNil(log?.endTime)
            XCTAssertEqual(log?.isCancelled, cancelOnResponse)
            XCTAssertEqual(log?.isFailure, false)
            if cancelOnResponse {
                XCTAssertEqual(log?.errorCode, NSURLErrorCancelled)
                XCTAssertEqual(log?.cancellationSource, "URLProtocol.stopLoading")
            } else {
                XCTAssertEqual(log?.statusCode, 200)
                XCTAssertEqual(log?.responseBodyString, "redirect-ok")
                XCTAssertEqual(log?.isSuccess, true)
                XCTAssertNil(log?.error)
            }
            read.fulfill()
        }
        wait(for: [read], timeout: 2)
    }

    private func makeTestWindow(size: CGSize) -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(origin: .zero, size: size))
        }
        window.frame = CGRect(origin: .zero, size: size)
        return window
    }

    private func attachScreenshot(_ window: UIWindow, name: String) {
        window.layoutIfNeeded()
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.layer.render(in: UIGraphicsGetCurrentContext()!)
        })
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func allSubviews(in view: UIView) -> [UIView] {
        return [view] + view.subviews.flatMap { allSubviews(in: $0) }
    }

    private func waitUntil(file: StaticString = #filePath, line: UInt = #line,
                           _ condition: @escaping () -> Bool) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 3), .completed, file: file, line: line)
    }

    private func firstSubview<T: UIView>(in view: UIView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match: T = firstSubview(in: subview) { return match }
        }
        return nil
    }

    private func makeLog(
        id: String = UUID().uuidString,
        url: String = "https://example.com/path",
        method: SJHTTPMethod? = .get,
        status: Int? = 200,
        durationMs: Double? = nil,
        requestBody: String? = nil,
        responseBody: String? = nil,
        startTime: Date = Date()
    ) -> SJLoggerModel {
        let type: SJLogType = url.lowercased().hasPrefix("https") ? .https : .http
        let log = SJLoggerModel(
            id: id,
            type: type,
            url: url,
            method: method,
            requestBody: requestBody?.data(using: .utf8),
            startTime: startTime
        )
        log.statusCode = status
        log.responseBody = responseBody?.data(using: .utf8)
        if let durationMs = durationMs {
            log.endTime = startTime.addingTimeInterval(durationMs / 1000)
        }
        return log
    }
}

private final class RedirectHTTPServer {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.sjlogger.tests.redirect-server")
    private var port: NWEndpoint.Port?

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    var baseURLString: String {
        guard let port = port else { return "" }
        return "http://127.0.0.1:\(port.rawValue)"
    }

    var redirectURL: URL? {
        return URL(string: baseURLString + "/redirect")
    }

    func start(ready: @escaping (Error?) -> Void) {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.port = self.listener.port
                self.listener.stateUpdateHandler = nil
                ready(nil)
            case .failed(let error):
                self.listener.stateUpdateHandler = nil
                ready(error)
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self = self,
                  let data = data,
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let response: String
            if request.contains(" /redirect ") {
                response = "HTTP/1.1 302 Found\r\nLocation: \(self.baseURLString)/final\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            } else {
                let body = "redirect-ok"
                response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            }

            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}


private final class ReentrantProtocolClient: NSObject, URLProtocolClient {
    var onResponse: ((URLProtocol) -> Void)?
    var onFinish: ((URLProtocol) -> Void)?
    var onError: ((Error) -> Void)?
    func urlProtocol(_ instance: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) { onResponse?(instance) }
    func urlProtocolDidFinishLoading(_ instance: URLProtocol) { onFinish?(instance) }
    func urlProtocol(_ instance: URLProtocol, didFailWithError error: Error) { onError?(error) }
    func urlProtocol(_ instance: URLProtocol, didLoad data: Data) {}
    func urlProtocol(_ instance: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {}
    func urlProtocol(_ instance: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {}
    func urlProtocol(_ instance: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {}
    func urlProtocol(_ instance: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {}
}
