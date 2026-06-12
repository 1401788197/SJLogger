import UIKit

// MARK: - JSON语法高亮
/// 将JSON文本渲染为带语法高亮的NSAttributedString（自动适配深浅色）
public enum SJSyntaxHighlighter {
    
    /// 高亮配色
    private struct Palette {
        let key: UIColor
        let string: UIColor
        let number: UIColor
        let bool: UIColor
        let null: UIColor
        let punctuation: UIColor
        let base: UIColor
    }
    
    private static var palette: Palette {
        Palette(
            key: UIColor(dynamicLight: UIColor(red: 0.61, green: 0.13, blue: 0.58, alpha: 1),
                         dark: UIColor(red: 0.93, green: 0.55, blue: 0.85, alpha: 1)),
            string: UIColor(dynamicLight: UIColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1),
                            dark: UIColor(red: 0.98, green: 0.55, blue: 0.48, alpha: 1)),
            number: UIColor(dynamicLight: UIColor(red: 0.11, green: 0.30, blue: 0.85, alpha: 1),
                            dark: UIColor(red: 0.51, green: 0.75, blue: 1.0, alpha: 1)),
            bool: UIColor(dynamicLight: UIColor(red: 0.0, green: 0.46, blue: 0.46, alpha: 1),
                          dark: UIColor(red: 0.40, green: 0.85, blue: 0.80, alpha: 1)),
            null: .systemGray,
            punctuation: .secondaryLabel,
            base: .label
        )
    }
    
    /// 对JSON字符串进行语法高亮；若不是合法JSON则返回普通等宽文本
    /// - Parameters:
    ///   - jsonString: 原始JSON文本（可未格式化）
    ///   - fontSize: 字号
    public static func highlight(_ jsonString: String, fontSize: CGFloat = 12) -> NSAttributedString {
        let pretty = jsonString.prettyJSON ?? jsonString
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let p = palette
        let result = NSMutableAttributedString(
            string: pretty,
            attributes: [.font: font, .foregroundColor: p.base]
        )
        
        // 只有合法JSON才上色，避免误伤普通文本
        guard jsonString.isJSON else { return result }
        
        let ns = pretty as NSString
        let full = NSRange(location: 0, length: ns.length)
        
        func apply(_ pattern: String, color: UIColor, group: Int = 0) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            regex.enumerateMatches(in: pretty, options: [], range: full) { match, _, _ in
                guard let m = match, m.numberOfRanges > group else { return }
                result.addAttribute(.foregroundColor, value: color, range: m.range(at: group))
            }
        }
        
        // 字符串值
        apply("\"(?:[^\"\\\\]|\\\\.)*\"", color: p.string)
        // 键（字符串后紧跟冒号）
        apply("(\"(?:[^\"\\\\]|\\\\.)*\")\\s*:", color: p.key, group: 1)
        // 数字
        apply("(?<![\\w\"])-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?", color: p.number)
        // 布尔
        apply("\\b(true|false)\\b", color: p.bool, group: 1)
        // null
        apply("\\bnull\\b", color: p.null)
        
        return result
    }
}

// MARK: - 动态颜色辅助
extension UIColor {
    /// 根据浅色/深色生成动态颜色
    convenience init(dynamicLight light: UIColor, dark: UIColor) {
        self.init { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}
