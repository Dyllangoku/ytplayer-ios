import Foundation

extension Notification.Name {
    static let ytScriptUpdated = Notification.Name("ytScriptUpdated")
}

/// 차단 스크립트 관리: 앱에 들어있는 기본본 ↔ 인터넷에서 받은 최신본 중 새 것을 사용
final class ScriptManager {
    static let shared = ScriptManager()

    enum Result {
        case updated(String)
        case latest(String)
        case failed(String)
    }

    private(set) var source: String
    var version: String { Self.version(of: source) }

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("youtube.js")
    }()

    /// 빌드할 때 GitHub 저장소 이름(owner/repo)이 Info.plist의 ScriptRepo에 들어간다
    var remoteURL: URL? {
        guard let repo = Bundle.main.object(forInfoDictionaryKey: "ScriptRepo") as? String,
              repo.contains("/"), !repo.contains("$") else { return nil }
        // ?t= 붙여서 GitHub 서버의 5분 캐시를 건너뛰고 항상 최신본을 받는다
        return URL(string: "https://raw.githubusercontent.com/\(repo)/main/scripts/youtube.js?t=\(Int(Date().timeIntervalSince1970))")
    }

    private init() {
        let bundled = Bundle.main.url(forResource: "youtube", withExtension: "js")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let cached = try? String(contentsOf: cacheURL, encoding: .utf8)
        if let cached, ScriptManager.compare(ScriptManager.version(of: cached), ScriptManager.version(of: bundled)) > 0 {
            source = cached
        } else {
            source = bundled
        }
    }

    func checkForUpdate(completion: ((Result) -> Void)? = nil) {
        let finish: (Result) -> Void = { result in DispatchQueue.main.async { completion?(result) } }
        guard let url = remoteURL else {
            finish(.failed("업데이트 주소가 설정되지 않았어요"))
            return
        }
        let current = version
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let data, let text = String(data: data, encoding: .utf8),
                  text.hasPrefix("// ==UserScript=="), data.count < 300_000 else {
                finish(.failed(error?.localizedDescription ?? "새 버전을 받아오지 못했어요"))
                return
            }
            let newVersion = Self.version(of: text)
            guard Self.compare(newVersion, current) > 0 else {
                finish(.latest(current))
                return
            }
            try? text.write(to: self.cacheURL, atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                self.source = text
                NotificationCenter.default.post(name: .ytScriptUpdated, object: nil)
                completion?(.updated(newVersion))
            }
        }.resume()
    }

    static func version(of script: String) -> String {
        for line in script.split(separator: "\n").prefix(30) where line.contains("@version") {
            return line.components(separatedBy: "@version").last?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
        }
        return "0"
    }

    /// "1.2.0" 같은 버전 비교: a가 크면 1, 같으면 0, 작으면 -1
    static func compare(_ a: String, _ b: String) -> Int {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0
            let r = i < y.count ? y[i] : 0
            if l != r { return l < r ? -1 : 1 }
        }
        return 0
    }
}
