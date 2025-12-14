import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var isEnabled = true

    // UserDefaults keys
    private let launchAtLoginKey = "launchAtLogin"
    private let isEnabledKey = "isEnabled"

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 状態を復元
        isEnabled = UserDefaults.standard.object(forKey: isEnabledKey) as? Bool ?? true

        // メニューバーアイテムを作成
        setupStatusItem()

        // キーハンドラを開始
        if isEnabled {
            startKeyHandler()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyHandler.shared.stop()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            updateStatusIcon()
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // メニューを作成
        let menu = NSMenu()

        // 有効/無効切り替え
        let toggleItem = NSMenuItem(title: isEnabled ? "Disable" : "Enable", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.tag = 1
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // ログイン時に起動
        let launchAtLogin = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = launchAtLogin ? .on : .off
        launchItem.tag = 2
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        // アクセシビリティ設定を開く
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings...", action: #selector(openAccessibilitySettings), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 終了
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            // SF Symbolsを使用（macOS 11+）
            if #available(macOS 11.0, *) {
                let symbolName = isEnabled ? "command.circle.fill" : "command.circle"
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "CmdSwitcher")?
                    .withSymbolConfiguration(config)
            } else {
                // フォールバック: テキスト表示
                button.title = isEnabled ? "⌘" : "⌘̸"
            }
        }
    }

    // MARK: - Actions

    @objc private func statusItemClicked() {
        statusItem.button?.performClick(nil)
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        UserDefaults.standard.set(isEnabled, forKey: isEnabledKey)

        if isEnabled {
            startKeyHandler()
        } else {
            KeyHandler.shared.stop()
        }

        updateStatusIcon()
        updateMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        let currentState = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        let newState = !currentState

        if #available(macOS 13.0, *) {
            do {
                if newState {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                UserDefaults.standard.set(newState, forKey: launchAtLoginKey)
                updateMenu()
            } catch {
                showAlert(title: "Error", message: "Failed to change login item: \(error.localizedDescription)")
            }
        } else {
            // macOS 12以前のフォールバック
            SMLoginItemSetEnabled("com.cmdswitcher.launcher" as CFString, newState)
            UserDefaults.standard.set(newState, forKey: launchAtLoginKey)
            updateMenu()
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    private func startKeyHandler() {
        if !KeyHandler.shared.start() {
            showAccessibilityAlert()
        }
    }

    private func updateMenu() {
        guard let menu = statusItem.menu else { return }

        // Toggle item
        if let toggleItem = menu.item(withTag: 1) {
            toggleItem.title = isEnabled ? "Disable" : "Enable"
        }

        // Launch at login item
        if let launchItem = menu.item(withTag: 2) {
            launchItem.state = UserDefaults.standard.bool(forKey: launchAtLoginKey) ? .on : .off
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "CmdSwitcher needs Accessibility permission to monitor keyboard events.\n\nPlease enable it in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
