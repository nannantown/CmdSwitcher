import Foundation
import Cocoa

/// GitHub Releaseから最新バージョンをチェックし、アップデート通知を表示
final class UpdateChecker {

    // MARK: - Properties

    static let shared = UpdateChecker()

    private let repoOwner = "nannantown"
    private let repoName = "CmdSwitcher"
    private let lastCheckKey = "lastUpdateCheck"
    private let skipVersionKey = "skipVersion"

    // 最小チェック間隔（秒）- 1日に1回
    private let minCheckInterval: TimeInterval = 86400

    private init() {}

    // MARK: - Public Methods

    /// 起動時のアップデートチェック（1日1回）
    func checkForUpdatesIfNeeded() {
        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        let now = Date().timeIntervalSince1970

        // 前回チェックから十分時間が経っていない場合はスキップ
        if now - lastCheck < minCheckInterval {
            return
        }

        checkForUpdates(silent: true)
    }

    /// 手動でアップデートチェック
    func checkForUpdatesManually() {
        checkForUpdates(silent: false)
    }

    // MARK: - Private Methods

    private func checkForUpdates(silent: Bool) {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleResponse(data: data, error: error, silent: silent)
            }
        }.resume()

        // チェック時刻を記録
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
    }

    private func handleResponse(data: Data?, error: Error?, silent: Bool) {
        if let error = error {
            if !silent {
                showAlert(
                    title: "Update Check Failed",
                    message: "Could not check for updates: \(error.localizedDescription)",
                    style: .warning
                )
            }
            return
        }

        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            if !silent {
                showAlert(
                    title: "Update Check Failed",
                    message: "Could not parse update information.",
                    style: .warning
                )
            }
            return
        }

        let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        if isVersion(latestVersion, newerThan: currentVersion) {
            // スキップ設定を確認
            let skipVersion = UserDefaults.standard.string(forKey: skipVersionKey)
            if silent && skipVersion == latestVersion {
                return
            }

            let htmlUrl = json["html_url"] as? String ?? "https://github.com/\(repoOwner)/\(repoName)/releases"
            showUpdateAvailable(latestVersion: latestVersion, currentVersion: currentVersion, releaseUrl: htmlUrl)
        } else if !silent {
            showAlert(
                title: "You're Up to Date",
                message: "CmdSwitcher \(currentVersion) is the latest version.",
                style: .informational
            )
        }
    }

    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let v1Parts = v1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(v1Parts.count, v2Parts.count) {
            let part1 = i < v1Parts.count ? v1Parts[i] : 0
            let part2 = i < v2Parts.count ? v2Parts[i] : 0

            if part1 > part2 { return true }
            if part1 < part2 { return false }
        }

        return false
    }

    private func showUpdateAvailable(latestVersion: String, currentVersion: String, releaseUrl: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "CmdSwitcher \(latestVersion) is available.\nYou are currently using version \(currentVersion).\n\nWould you like to download the update?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Download
            if let url = URL(string: releaseUrl) {
                NSWorkspace.shared.open(url)
            }
        case .alertThirdButtonReturn:
            // Skip this version
            UserDefaults.standard.set(latestVersion, forKey: skipVersionKey)
        default:
            break
        }
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }
}
