import Foundation
import Cocoa

/// GitHub Releaseから最新バージョンをチェックし、自動アップデートを行う
final class UpdateChecker {

    // MARK: - Properties

    static let shared = UpdateChecker()

    private let repoOwner = "nannantown"
    private let repoName = "CmdSwitcher"
    private let lastCheckKey = "lastUpdateCheck"
    private let skipVersionKey = "skipVersion"

    // 最小チェック間隔（秒）- 1日に1回
    private let minCheckInterval: TimeInterval = 86400

    // アップデート情報を保持
    private var latestDownloadUrl: String?
    private var latestVersion: String?

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

        // アセットからダウンロードURLを取得
        var downloadUrl: String?
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String,
                   name.hasSuffix(".zip"),
                   let url = asset["browser_download_url"] as? String {
                    downloadUrl = url
                    break
                }
            }
        }

        self.latestVersion = latestVersion
        self.latestDownloadUrl = downloadUrl

        if isVersion(latestVersion, newerThan: currentVersion) {
            // スキップ設定を確認
            let skipVersion = UserDefaults.standard.string(forKey: skipVersionKey)
            if silent && skipVersion == latestVersion {
                return
            }

            showUpdateAvailable(latestVersion: latestVersion, currentVersion: currentVersion)
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

    private func showUpdateAvailable(latestVersion: String, currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "CmdSwitcher \(latestVersion) is available.\nYou are currently using version \(currentVersion).\n\nWould you like to update now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Update Now
            performUpdate()
        case .alertThirdButtonReturn:
            // Skip this version
            UserDefaults.standard.set(latestVersion, forKey: skipVersionKey)
        default:
            break
        }
    }

    // MARK: - Auto Update

    private var progressWindow: NSWindow?
    private var progressIndicator: NSProgressIndicator?

    private func performUpdate() {
        guard let downloadUrl = latestDownloadUrl,
              let url = URL(string: downloadUrl) else {
            showAlert(title: "Update Failed", message: "Download URL not found.", style: .warning)
            return
        }

        // プログレスウィンドウを表示
        showProgressWindow()

        // 非同期でダウンロード開始
        let task = URLSession.shared.downloadTask(with: url) { [weak self] localUrl, response, error in
            DispatchQueue.main.async {
                self?.hideProgressWindow()

                if let error = error {
                    self?.showAlert(title: "Download Failed", message: error.localizedDescription, style: .warning)
                    return
                }

                guard let localUrl = localUrl else {
                    self?.showAlert(title: "Download Failed", message: "Could not download the update.", style: .warning)
                    return
                }

                self?.installUpdate(from: localUrl)
            }
        }

        task.resume()
    }

    private func showProgressWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Updating CmdSwitcher"
        window.center()

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))

        let label = NSTextField(labelWithString: "Downloading update...")
        label.frame = NSRect(x: 20, y: 55, width: 260, height: 20)
        label.alignment = .center
        contentView.addSubview(label)

        let indicator = NSProgressIndicator(frame: NSRect(x: 50, y: 25, width: 200, height: 20))
        indicator.style = .bar
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        contentView.addSubview(indicator)

        window.contentView = contentView
        window.level = .floating
        window.makeKeyAndOrderFront(nil)

        self.progressWindow = window
        self.progressIndicator = indicator
    }

    private func hideProgressWindow() {
        progressIndicator?.stopAnimation(nil)
        progressWindow?.close()
        progressWindow = nil
        progressIndicator = nil
    }

    private func installUpdate(from zipUrl: URL) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            // 一時ディレクトリを作成
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // zipファイルを一時ディレクトリにコピー
            let zipPath = tempDir.appendingPathComponent("update.zip")
            try fileManager.copyItem(at: zipUrl, to: zipPath)

            // unzipコマンドで解凍
            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipProcess.arguments = ["-o", zipPath.path, "-d", tempDir.path]
            unzipProcess.standardOutput = nil
            unzipProcess.standardError = nil
            try unzipProcess.run()
            unzipProcess.waitUntilExit()

            guard unzipProcess.terminationStatus == 0 else {
                throw NSError(domain: "UpdateChecker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract update."])
            }

            // 解凍されたappを探す
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newAppUrl = contents.first(where: { $0.pathExtension == "app" }) else {
                throw NSError(domain: "UpdateChecker", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find app in update package."])
            }

            // 現在のアプリのパス
            let currentAppUrl = URL(fileURLWithPath: Bundle.main.bundlePath)
            let appName = currentAppUrl.lastPathComponent
            let parentDir = currentAppUrl.deletingLastPathComponent()

            // バックアップを作成
            let backupUrl = parentDir.appendingPathComponent("\(appName).backup")
            if fileManager.fileExists(atPath: backupUrl.path) {
                try fileManager.removeItem(at: backupUrl)
            }

            // 現在のアプリをバックアップにリネーム
            try fileManager.moveItem(at: currentAppUrl, to: backupUrl)

            // 新しいアプリを移動
            let destinationUrl = parentDir.appendingPathComponent(appName)
            try fileManager.moveItem(at: newAppUrl, to: destinationUrl)

            // バックアップを削除
            try? fileManager.removeItem(at: backupUrl)

            // 一時ディレクトリを削除
            try? fileManager.removeItem(at: tempDir)

            // アプリを再起動
            restartApp(at: destinationUrl)

        } catch {
            // エラー時はクリーンアップ
            try? fileManager.removeItem(at: tempDir)
            showAlert(title: "Update Failed", message: error.localizedDescription, style: .warning)
        }
    }

    private func restartApp(at appUrl: URL) {
        // 少し待ってから新しいアプリを起動
        let script = """
        sleep 1
        open "\(appUrl.path)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", script]
        try? task.run()

        // 現在のアプリを終了
        NSApp.terminate(nil)
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }
}
