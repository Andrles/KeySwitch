import Foundation

struct SemanticVersion: Comparable, Equatable {
    let components: [Int]

    init?(_ value: String) {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let core = normalized.split(separator: "-", maxSplits: 1).first ?? ""
        let parsed = core.split(separator: ".").compactMap { Int($0) }
        guard !parsed.isEmpty,
              parsed.count == core.split(separator: ".").count else {
            return nil
        }
        components = parsed
    }

    static func < (left: SemanticVersion, right: SemanticVersion) -> Bool {
        let count = max(left.components.count, right.components.count)
        for index in 0..<count {
            let lhs = index < left.components.count ? left.components[index] : 0
            let rhs = index < right.components.count ? right.components[index] : 0
            if lhs != rhs { return lhs < rhs }
        }
        return false
    }

    static func == (left: SemanticVersion, right: SemanticVersion) -> Bool {
        !(left < right) && !(right < left)
    }
}

struct AvailableUpdate: Equatable {
    let version: String
    let releaseURL: URL
    let downloadURL: URL
    let notes: String
}

enum UpdateCheckResult: Equatable {
    case upToDate
    case available(AvailableUpdate)
}

final class UpdateChecker {
    static let shared = UpdateChecker()

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let htmlURL: URL
        let body: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
            case assets
        }
    }

    private let preferences = Preferences.shared
    private let endpoint = URL(
        string: "https://api.github.com/repos/Andrles/KeySwitch/releases/latest"
    )!
    private let session: URLSession
    private(set) var lastResult: UpdateCheckResult?
    private(set) var lastError: Error?
    private(set) var isChecking = false

    private init(session: URLSession = .shared) {
        self.session = session
    }

    var shouldCheckAutomatically: Bool {
        guard preferences.automaticallyChecksForUpdates else { return false }
        guard let lastCheck = preferences.lastUpdateCheck else { return true }
        return Date().timeIntervalSince(lastCheck) >= 24 * 60 * 60
    }

    func check(completion: @escaping (Result<UpdateCheckResult, Error>) -> Void) {
        guard !isChecking else { return }
        isChecking = true
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("KeySwitch/\(AppVersion.short)",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json",
                         forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            let result: Result<UpdateCheckResult, Error>
            do {
                if let error { throw error }
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let data else {
                    throw URLError(.badServerResponse)
                }
                let release = try JSONDecoder().decode(GitHubRelease.self,
                                                       from: data)
                result = .success(try self.evaluate(release))
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                self.isChecking = false
                self.preferences.lastUpdateCheck = Date()
                switch result {
                case let .success(value):
                    self.lastResult = value
                    self.lastError = nil
                case let .failure(error):
                    self.lastError = error
                }
                NotificationCenter.default.post(name: .keySwitchUpdateStateChanged,
                                                object: self)
                completion(result)
            }
        }.resume()
    }

    private func evaluate(_ release: GitHubRelease) throws -> UpdateCheckResult {
        guard let current = SemanticVersion(AppVersion.short),
              let latest = SemanticVersion(release.tagName) else {
            throw URLError(.cannotParseResponse)
        }
        guard current < latest else { return .upToDate }
        let preferredAsset = release.assets.first(where: { $0.name == "KeySwitch.pkg" })
            ?? release.assets.first(where: { $0.name.hasSuffix(".pkg") })
            ?? release.assets.first(where: { $0.name == "KeySwitch.zip" })
            ?? release.assets.first(where: { $0.name.hasSuffix(".zip") })
        let downloadURL = preferredAsset?.browserDownloadURL ?? release.htmlURL
        return .available(AvailableUpdate(
            version: release.tagName.trimmingCharacters(
                in: CharacterSet(charactersIn: "vV")
            ),
            releaseURL: release.htmlURL,
            downloadURL: downloadURL,
            notes: release.body ?? ""
        ))
    }
}

extension Notification.Name {
    static let keySwitchUpdateStateChanged = Notification.Name("keySwitchUpdateStateChanged")
}
