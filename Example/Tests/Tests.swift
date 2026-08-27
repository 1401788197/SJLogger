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

    override func setUp() {
        super.setUp()
        let config = SJLoggerConfig.shared
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
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
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
