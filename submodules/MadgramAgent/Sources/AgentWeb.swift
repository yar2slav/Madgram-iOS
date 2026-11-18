import Foundation

private final class AgentWebRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https", let host = url.host, AgentWeb.isPublicHost(host) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

public enum AgentWeb {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20.0
        configuration.timeoutIntervalForResource = 40.0
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            "Accept-Language": "ru,en;q=0.8"
        ]
        return URLSession(configuration: configuration)
    }()

    public static let searchToolName = "web_search"
    public static let fetchToolName = "web_fetch"

    public static var toolSpecs: [AgentToolSpec] {
        return [
            AgentToolSpec(
                name: AgentWeb.searchToolName,
                description: "Search the web (DuckDuckGo). Returns up to 8 results with title, url and snippet. Use web_fetch to read a page.",
                schema: [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string"]
                    ],
                    "required": ["query"],
                    "additionalProperties": false
                ]
            ),
            AgentToolSpec(
                name: AgentWeb.fetchToolName,
                description: "Download a web page by its http(s) url and return its readable text (trimmed).",
                schema: [
                    "type": "object",
                    "properties": [
                        "url": ["type": "string"]
                    ],
                    "required": ["url"],
                    "additionalProperties": false
                ]
            )
        ]
    }

    private static func decodeEntities(_ value: String) -> String {
        var result = value
        let map = ["&amp;": "&", "&quot;": "\"", "&#x27;": "'", "&#39;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&#x2F;": "/", "&hellip;": "…", "&mdash;": "—", "&ndash;": "–", "&laquo;": "«", "&raquo;": "»"]
        for (key, replacement) in map {
            result = result.replacingOccurrences(of: key, with: replacement)
        }
        if let regex = try? NSRegularExpression(pattern: "&#(x?[0-9a-fA-F]+);") {
            let ns = result as NSString
            var output = ""
            var last = 0
            for match in regex.matches(in: result, range: NSRange(location: 0, length: ns.length)) {
                output += ns.substring(with: NSRange(location: last, length: match.range.location - last))
                let code = ns.substring(with: match.range(at: 1))
                let scalarValue = code.hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code, radix: 10)
                if let scalarValue, let scalar = Unicode.Scalar(scalarValue) {
                    output.append(Character(scalar))
                } else {
                    output += ns.substring(with: match.range)
                }
                last = match.range.location + match.range.length
            }
            output += ns.substring(from: last)
            result = output
        }
        return result
    }

    private static func stripTags(_ html: String) -> String {
        var text = html
        for pattern in ["(?is)<script.*?</script>", "(?is)<style.*?</style>", "(?is)<noscript.*?</noscript>", "(?is)<svg.*?</svg>", "(?is)<head.*?</head>"] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: "(?i)<br\\s*/?>|</p>|</div>|</li>|</h[1-6]>|</tr>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decodeEntities(text)
        text = text.replacingOccurrences(of: "[ \\t\\u{00A0}]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s*\\n\\s*(\\n\\s*)+", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func search(_ query: String) async -> (String, Bool) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: "https://html.duckduckgo.com/html/") else {
            return ("Пустой запрос.", true)
        }
        components.queryItems = [URLQueryItem(name: "q", value: trimmed), URLQueryItem(name: "kl", value: "ru-ru")]
        guard let url = components.url else {
            return ("Кривой запрос.", true)
        }
        do {
            let (data, _) = try await AgentWeb.session.data(from: url)
            let html = String(decoding: data, as: UTF8.self)
            guard let linkRegex = try? NSRegularExpression(pattern: "<a[^>]*class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>", options: [.dotMatchesLineSeparators]),
                  let snippetRegex = try? NSRegularExpression(pattern: "class=\"result__snippet\"[^>]*>(.*?)</a>", options: [.dotMatchesLineSeparators]) else {
                return ("Поиск недоступен.", true)
            }
            let ns = html as NSString
            let links = linkRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            let snippets = snippetRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            var lines: [String] = []
            for (index, match) in links.prefix(8).enumerated() {
                var href = decodeEntities(ns.substring(with: match.range(at: 1)))
                if href.hasPrefix("//") {
                    href = "https:" + href
                }
                if let hrefComponents = URLComponents(string: href), let target = hrefComponents.queryItems?.first(where: { $0.name == "uddg" })?.value {
                    href = target
                }
                if href.contains("duckduckgo.com/y.js") {
                    continue
                }
                let title = stripTags(ns.substring(with: match.range(at: 2)))
                var snippet = ""
                if index < snippets.count {
                    snippet = stripTags(ns.substring(with: snippets[index].range(at: 1)))
                }
                lines.append("\(lines.count + 1). \(title)\n\(href)\n\(snippet)")
            }
            if lines.isEmpty {
                return ("Ничего не нашлось по «\(trimmed)».", false)
            }
            return (lines.joined(separator: "\n\n"), false)
        } catch {
            return ("Поиск не удался: \(error.localizedDescription)", true)
        }
    }

    static func isPublicIPv4(_ address: UInt32) -> Bool {
        let a = address >> 24
        let b = (address >> 16) & 0xff
        switch a {
        case 0, 10, 127:
            return false
        case 100 where b >= 64 && b < 128:
            return false
        case 169 where b == 254:
            return false
        case 172 where b >= 16 && b < 32:
            return false
        case 192 where b == 168:
            return false
        case 192 where b == 0 && ((address >> 8) & 0xff) == 0:
            return false
        case 198 where b == 18 || b == 19:
            return false
        default:
            return a < 224
        }
    }

    static func isPublicIPv6(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else {
            return false
        }
        let embedded = UInt32(bytes[12]) << 24 | UInt32(bytes[13]) << 16 | UInt32(bytes[14]) << 8 | UInt32(bytes[15])
        if bytes[0..<10].allSatisfy({ $0 == 0 }) && bytes[10] == 0xff && bytes[11] == 0xff {
            return isPublicIPv4(embedded)
        }
        if bytes[0] == 0x00 && bytes[1] == 0x64 && bytes[2] == 0xff && bytes[3] == 0x9b && bytes[4..<12].allSatisfy({ $0 == 0 }) {
            return isPublicIPv4(embedded)
        }
        if bytes[0..<15].allSatisfy({ $0 == 0 }) {
            return false
        }
        if (bytes[0] & 0xfe) == 0xfc || bytes[0] == 0xff || (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) {
            return false
        }
        return true
    }

    static func isPublicHost(_ value: String) -> Bool {
        let host = value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]."))
        if host.isEmpty || host == "localhost" || [".localhost", ".local", ".internal", ".lan", ".home.arpa"].contains(where: { host.hasSuffix($0) }) {
            return false
        }
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else {
            return false
        }
        defer {
            freeaddrinfo(first)
        }
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let info = cursor {
            guard let address = info.pointee.ai_addr else {
                return false
            }
            switch info.pointee.ai_family {
            case AF_INET:
                let value = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
                if !isPublicIPv4(value) {
                    return false
                }
            case AF_INET6:
                let bytes = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
                    return withUnsafeBytes(of: pointer.pointee.sin6_addr) { Array($0) }
                }
                if !isPublicIPv6(bytes) {
                    return false
                }
            default:
                return false
            }
            cursor = info.pointee.ai_next
        }
        return true
    }

    public static func fetch(_ value: String) async -> (String, Bool) {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https", let host = url.host?.lowercased() else {
            return ("Нужна ссылка http(s).", true)
        }
        if url.user != nil || url.password != nil || !AgentWeb.isPublicHost(host) {
            return ("Локальные адреса открывать нельзя.", true)
        }
        do {
            let (bytes, response) = try await AgentWeb.session.bytes(from: url, delegate: AgentWebRedirectGuard())
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count > 3 * 1024 * 1024 {
                    break
                }
            }
            let mime = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            let raw = String(decoding: data, as: UTF8.self)
            var text: String
            if mime.contains("html") || raw.lowercased().contains("<html") {
                var title = ""
                if let range = raw.range(of: "(?is)<title[^>]*>(.*?)</title>", options: .regularExpression) {
                    title = stripTags(String(raw[range]))
                }
                text = (title.isEmpty ? "" : "\(title)\n\n") + stripTags(raw)
            } else if mime.hasPrefix("text/") || mime.contains("json") || mime.contains("xml") {
                text = raw
            } else {
                return ("Это не текстовая страница (\(mime)).", true)
            }
            if text.count > 20000 {
                text = String(text.prefix(20000)) + "\n…обрезано."
            }
            return (text.isEmpty ? "Страница пустая." : text, false)
        } catch {
            return ("Не открылось: \(error.localizedDescription)", true)
        }
    }
}
