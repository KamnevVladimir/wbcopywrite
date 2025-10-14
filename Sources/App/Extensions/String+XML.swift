import Foundation

extension String {
    var xmlEscaped: String {
        var s = self
        s = s.replacingOccurrences(of: "&", with: "&amp;")
        s = s.replacingOccurrences(of: "<", with: "&lt;")
        s = s.replacingOccurrences(of: ">", with: "&gt;")
        s = s.replacingOccurrences(of: "\"", with: "&quot;")
        s = s.replacingOccurrences(of: "'", with: "&apos;")
        return s
    }
    
    var htmlEscapedNoMarkdown: String {
        // Убираем Markdown символы, чтобы не конфликтовали с HTML parse_mode
        let stripped = self.replacingOccurrences(of: "*", with: "")
                           .replacingOccurrences(of: "_", with: "")
                           .replacingOccurrences(of: "`", with: "")
        return stripped.xmlEscaped
    }
}


