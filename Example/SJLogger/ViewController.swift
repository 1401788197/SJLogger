//
//  ViewController.swift
//  SJLogger
//
//  Created by Hicreate on 01/05/2026.
//  Copyright (c) 2026 Hicreate. All rights reserved.
//

import UIKit
import SJLogger

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        runSelfTestIfNeeded()
    }
    
    // MARK: - 自测入口（仅当设置环境变量 SJ_SELFTEST 时触发）
    
    private func runSelfTestIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        guard env["SJ_SELFTEST"] == "1" else { return }
        seedSampleLogs()
        let screen = env["SJ_SCREEN"] ?? "list"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            switch screen {
            case "settings":
                SJLogger.shared.showSettings(from: self)
            case "filter":
                let vc = SJLogFilterViewController(query: SJLogQuery())
                self.present(UINavigationController(rootViewController: vc), animated: true)
            default:
                SJLogger.shared.showLogList(from: self)
            }
        }
    }
    
    private func seedSampleLogs() {
        func mk(_ type: SJLogType, _ method: SJHTTPMethod?, _ url: String, status: Int?, ms: Double, req: String? = nil, resp: String? = nil, ws: SJWSDirection? = nil, event: String? = nil) {
            let start = Date().addingTimeInterval(-ms/1000.0)
            let log = SJLoggerModel(type: type, url: url, method: method, requestBody: req?.data(using: .utf8), startTime: start)
            log.statusCode = status
            log.responseBody = resp?.data(using: .utf8)
            log.responseHeaders = ["Content-Type": "application/json"]
            log.endTime = Date()
            log.wsDirection = ws
            log.wsEventName = event
            SJLogger.shared.storage.addLog(log)
        }
        let json = "{\"code\":0,\"data\":{\"id\":123,\"name\":\"SJLogger\",\"tags\":[\"a\",\"b\"],\"ok\":true},\"msg\":null}"
        mk(.https, .get, "https://api.example.com/api/user/profile", status: 200, ms: 120, resp: json)
        mk(.https, .get, "https://api.example.com/api/user/profile", status: 200, ms: 340, resp: json)
        mk(.https, .post, "https://api.example.com/api/user/login", status: 200, ms: 95, req: "{\"u\":\"a\",\"p\":\"b\"}", resp: json)
        mk(.https, .post, "https://api.example.com/api/user/login", status: 401, ms: 60, resp: "{\"err\":\"bad\"}")
        mk(.https, .get, "https://api.example.com/api/feed/list", status: 500, ms: 2300, resp: "{\"err\":\"server\"}")
        mk(.https, .get, "https://api.example.com/api/feed/list", status: 200, ms: 1800, resp: json)
        mk(.http, .delete, "https://api.example.com/api/item/9", status: 204, ms: 70)
        mk(.websocket, nil, "wss://ws.example.com/live", status: 200, ms: 5, resp: "{\"type\":\"tick\"}", ws: .received, event: "Recv (Text)")
        mk(.websocket, nil, "wss://ws.example.com/live", status: 200, ms: 5, req: "{\"act\":\"sub\"}", ws: .sent, event: "Send (Text)")
    }
    
    private func setupUI() {
        title = "SJLogger Demo"
        
        // 创建按钮
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
        
        // 测试按钮
        addButton(to: stackView, title: "发送GET请求", action: #selector(sendGetRequest))
        addButton(to: stackView, title: "发送POST请求", action: #selector(sendPostRequest))
        addButton(to: stackView, title: "发送失败请求", action: #selector(sendFailRequest))
        addButton(to: stackView, title: "查看日志", action: #selector(showLogs))
        addButton(to: stackView, title: "清除日志", action: #selector(clearLogs))
    }
    
    private func addButton(to stackView: UIStackView, title: String, action: Selector) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: action, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.addArrangedSubview(button)
    }
    
    // MARK: - 测试网络请求
    
    @objc private func sendGetRequest() {
        guard let url = URL(string: "https://api.github.com/users/github") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                } else {
                    self.showAlert(title: "Success", message: "GET request completed")
                }
            }
        }
        task.resume()
    }
    
    @objc private func sendPostRequest() {
        guard let url = URL(string: "https://httpbin.org/post") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": "SJLogger", "version": "1.0.0", "platform": "iOS"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                } else {
                    self.showAlert(title: "Success", message: "POST request completed")
                }
            }
        }
        task.resume()
    }
    
    @objc private func sendFailRequest() {
        guard let url = URL(string: "https://httpbin.org/status/500") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.showAlert(title: "Request Sent", message: "Check logs for error response")
            }
        }
        task.resume()
    }
    
    @objc private func showLogs() {
        SJLogger.shared.showLogList(from: self)
    }
    
    @objc private func clearLogs() {
        let alert = UIAlertController(title: "清除日志", message: "确定要清除所有日志吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { _ in
            SJLogger.shared.clearLogs()
            self.showAlert(title: "Success", message: "All logs cleared")
        })
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

