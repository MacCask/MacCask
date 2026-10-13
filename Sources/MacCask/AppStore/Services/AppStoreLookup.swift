import Foundation

/// 商店查询集中限速、复用请求并缓存五分钟；不影响本地应用扫描。
actor AppStoreLookup {
    static let shared = AppStoreLookup()
    private struct Entry {
        let app: StoreApp?
        let date: Date
    }
    private var cache: [String: Entry] = [:]
    private var pending: [String: Task<StoreApp?, Error>] = [:]
    private var nextRequest = Date.distantPast

    /// 按 Bundle ID 和地区查询，只接受完全匹配的 macOS 软件。
    func lookup(bundleID: String, country: String, forceRefresh: Bool = false) async throws -> StoreApp? {
        let key = country + ":" + bundleID
        if !forceRefresh, let entry = cache[key], Date().timeIntervalSince(entry.date) < 300 { return entry.app }
        if let task = pending[key] { return try await task.value }
        let delay = max(0, nextRequest.timeIntervalSinceNow)
        nextRequest = Date().addingTimeInterval(delay + 3.1)
        let task = Task<StoreApp?, Error> {
            if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
            // Apple 边缘缓存可能按客户端保留旧目录，独立请求标识避免复用旧响应。
            var components = URLComponents(url: Self.url(bundleID: bundleID, country: country), resolvingAgainstBaseURL: false)!
            components.queryItems?.append(URLQueryItem(name: "_", value: UUID().uuidString))
            let url = components.url!
            // 避免 URLSession 再用一层旧响应缓存，实际请求交给 Apple 判断。
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            return try Self.parse(data, bundleID: bundleID)
        }
        pending[key] = task
        defer { pending[key] = nil }
        let app = try await task.value
        cache[key] = Entry(app: app, date: Date())
        return app
    }

    /// 查询参数由 URLComponents 编码，避免 Bundle ID 破坏请求。
    nonisolated static func url(bundleID: String, country: String) -> URL {
        var url = URLComponents(string: "https://itunes.apple.com/lookup")!
        url.queryItems = [URLQueryItem(name: "bundleId", value: bundleID),
                         URLQueryItem(name: "entity", value: "macSoftware"),
                         URLQueryItem(name: "country", value: country)]
        return url.url!
    }

    /// 不把同名应用、iOS 软件或缺失版本的数据误认为可用更新。
    nonisolated static func parse(_ data: Data, bundleID: String) throws -> StoreApp? {
        struct Response: Decodable { let results: [StoreApp] }
        return try JSONDecoder().decode(Response.self, from: data).results.first {
            $0.bundleId == bundleID && $0.kind == "mac-software" && $0.trackId > 0 && !$0.version.isEmpty
        }
    }
}
