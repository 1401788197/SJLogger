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

