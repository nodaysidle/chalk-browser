import Foundation

enum SearchEngine: String, CaseIterable {
    case duckduckgo
    case google
    case brave

    func searchURL(for query: String) -> URL? {
        // RFC 3986 unreserved characters only — `.urlQueryAllowed` leaves
        // '&', '+', and '=' raw, which corrupts queries like "fish & chips"
        // (everything after '&' becomes a separate parameter) or "c++"
        // (engines decode '+' as space).
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encoded = query.addingPercentEncoding(withAllowedCharacters: unreserved) ?? query
        switch self {
        case .duckduckgo:
            return URL(string: "https://duckduckgo.com/?q=\(encoded)")
        case .google:
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        case .brave:
            return URL(string: "https://search.brave.com/search?q=\(encoded)")
        }
    }
}

enum NavigationInput {
    static func resolve(_ raw: String, engine: SearchEngine) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }

        if trimmed.contains(" ") {
            return engine.searchURL(for: trimmed)
        }

        let lower = trimmed.lowercased()

        // Only explicit loopback targets default to HTTP. Remote hosts and IPs
        // stay HTTPS-first unless the user types an http:// scheme.
        if isLoopbackTarget(lower) {
            return URL(string: "http://\(trimmed)")
        }

        if trimmed.contains(".") {
            return URL(string: "https://\(trimmed)")
        }

        return engine.searchURL(for: trimmed)
    }

    private static func isLoopbackTarget(_ input: String) -> Bool {
        guard let host = URLComponents(string: "http://\(input)")?.host?.lowercased() else {
            return false
        }
        return host == "localhost"
            || host.hasSuffix(".localhost")
            || host == "127.0.0.1"
            || host == "::1"
            || host == "[::1]"
    }

    static func title(for url: URL?) -> String {
        guard let url else { return "New Tab" }
        if let host = url.host, !host.isEmpty {
            return host
        }
        return url.absoluteString
    }
}
