import Cocoa
import Carbon

/// キーイベントを監視し、左右Commandキー単独押しで英数/かな切り替えを行う
final class KeyHandler {

    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // 左Commandキーの状態
    private var leftCmdPressed = false
    private var leftCmdPressTime: Date?

    // 右Commandキーの状態
    private var rightCmdPressed = false
    private var rightCmdPressTime: Date?

    // 他のキーが押されたかどうか（誤動作防止）
    private var otherKeyPressed = false

    // 単独押しと判定する最大時間（ミリ秒）
    private let maxTapDuration: TimeInterval = 0.3

    // シングルトン
    static let shared = KeyHandler()

    private init() {}

    // MARK: - Public Methods

    /// イベント監視を開始
    func start() -> Bool {
        // すでに開始している場合は停止
        stop()

        // 監視するイベントマスク（キーダウン、キーアップ、フラグ変更）
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                      (1 << CGEventType.keyDown.rawValue)

        // コールバックをCクロージャとして渡す
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let handler = Unmanaged<KeyHandler>.fromOpaque(refcon).takeUnretainedValue()
            return handler.handleEvent(proxy: proxy, type: type, event: event)
        }

        // イベントタップを作成
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Please grant Accessibility permission.")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("KeyHandler started successfully")
            return true
        }

        return false
    }

    /// イベント監視を停止
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Private Methods

    /// イベントを処理
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {

        // タップが無効化された場合は再有効化
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // キーダウンイベント → 他のキーが押されたとマーク
        if type == .keyDown {
            otherKeyPressed = true
            return Unmanaged.passUnretained(event)
        }

        // フラグ変更イベント（修飾キーの状態変化）
        if type == .flagsChanged {
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // 左Command (keyCode: 55)
            if keyCode == 55 {
                handleLeftCommand(isPressed: flags.contains(.maskCommand))
            }
            // 右Command (keyCode: 54)
            else if keyCode == 54 {
                handleRightCommand(isPressed: flags.contains(.maskCommand))
            }
        }

        return Unmanaged.passUnretained(event)
    }

    /// 左Commandキーの処理
    private func handleLeftCommand(isPressed: Bool) {
        if isPressed {
            // 押された
            leftCmdPressed = true
            leftCmdPressTime = Date()
            otherKeyPressed = false
        } else {
            // 離された
            if leftCmdPressed, !otherKeyPressed, let pressTime = leftCmdPressTime {
                let duration = Date().timeIntervalSince(pressTime)
                if duration <= maxTapDuration {
                    // 単独短押し → 英数キーを送信
                    sendEisuKey()
                }
            }
            leftCmdPressed = false
            leftCmdPressTime = nil
        }
    }

    /// 右Commandキーの処理
    private func handleRightCommand(isPressed: Bool) {
        if isPressed {
            // 押された
            rightCmdPressed = true
            rightCmdPressTime = Date()
            otherKeyPressed = false
        } else {
            // 離された
            if rightCmdPressed, !otherKeyPressed, let pressTime = rightCmdPressTime {
                let duration = Date().timeIntervalSince(pressTime)
                if duration <= maxTapDuration {
                    // 単独短押し → かなキーを送信
                    sendKanaKey()
                }
            }
            rightCmdPressed = false
            rightCmdPressTime = nil
        }
    }

    /// 英数キー (keyCode: 102) を送信
    private func sendEisuKey() {
        sendKey(keyCode: 102)
    }

    /// かなキー (keyCode: 104) を送信
    private func sendKanaKey() {
        sendKey(keyCode: 104)
    }

    /// キーイベントを送信
    private func sendKey(keyCode: Int) {
        let source = CGEventSource(stateID: .hidSystemState)

        // キーダウン
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) {
            keyDown.post(tap: .cgAnnotatedSessionEventTap)
        }

        // キーアップ
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) {
            keyUp.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
