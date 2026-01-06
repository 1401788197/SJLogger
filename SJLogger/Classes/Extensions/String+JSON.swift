import Foundation

// MARK: - String JSON扩展
/// 提供JSON格式化功能
extension String {
    
    /// 判断字符串是否为JSON格式
    var isJSON: Bool {
        guard let data = self.data(using: .utf8) else { return false }
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return true
        } catch {
            return false
        }
    }
    
    /// 格式化JSON字符串
    var prettyJSON: String? {
        guard let data = self.data(using: .utf8) else { return nil }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    /// 压缩JSON字符串（移除空格和换行）
    var compactJSON: String? {
        guard let data = self.data(using: .utf8) else { return nil }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            let compactData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            return String(data: compactData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - Data JSON扩展
extension Data {
    
    /// 判断Data是否为JSON格式
    var isJSON: Bool {
        do {
            _ = try JSONSerialization.jsonObject(with: self, options: [])
            return true
        } catch {
            return false
        }
    }
    
    /// 格式化JSON Data
    var prettyJSON: String? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: self, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
