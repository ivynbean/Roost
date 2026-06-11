import Foundation

/// Fetches the human-readable <title> of a saved web page so bookmarks get
/// names like "Never Gonna Give You Up - YouTube" instead of
/// "www.youtube.com / watch". One small GET per captured link, nothing stored
/// or sent anywhere else.
enum PageTitleFetcher {
    static func fetchTitle(for url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }

        let snippet = data.prefix(512 * 1024)
        guard let html = String(data: snippet, encoding: .utf8) ?? String(data: snippet, encoding: .isoLatin1) else {
            return nil
        }

        return title(fromHTML: html)
    }

    static func title(fromHTML html: String) -> String? {
        guard let match = html.range(of: "<title[^>]*>[\\s\\S]*?</title>", options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }

        var raw = String(html[match])
        raw = raw.replacingOccurrences(of: "<title[^>]*>", with: "", options: [.regularExpression, .caseInsensitive])
        raw = raw.replacingOccurrences(of: "</title>", with: "", options: [.caseInsensitive])

        let cleaned = decodeEntities(raw)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(120))
    }

    private static func decodeEntities(_ string: String) -> String {
        var result = string
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&#x27;": "'", "&apos;": "'", "&nbsp;": " ",
            "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&middot;": "·"
        ]
        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }

        while let range = result.range(of: "&#[0-9]{1,7};", options: .regularExpression) {
            let digits = result[range].dropFirst(2).dropLast()
            if let value = UInt32(digits), let scalar = Unicode.Scalar(value) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            } else {
                result.replaceSubrange(range, with: "")
            }
        }

        return result
    }
}
