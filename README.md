# CmdSwitcher

左右のCommandキー単独押しで英数/かなを切り替えるmacOSアプリ

## 特徴

- **軽量**: バイナリサイズ 172KB、メモリ使用量最小
- **安定**: 誤動作防止ロジック搭載
- **ユニバーサル**: Intel Mac / Apple Silicon Mac 両対応
- **シンプル**: メニューバーアイコンのみ、設定不要

## 動作

| キー操作 | 結果 |
|---------|------|
| 左Command 単独押し | 英数入力に切り替え |
| 右Command 単独押し | かな入力に切り替え |
| Command + 他のキー | 通常のショートカット（切り替えなし） |

## 誤動作防止

- Command + C, V, Z などのショートカット時は発動しない
- 300ms以上の長押しでは発動しない
- 他のキーと同時押しでは発動しない

## インストール

```bash
# ビルド
./build.sh

# アプリケーションフォルダにコピー
cp -r build/CmdSwitcher.app /Applications/
```

## 初回起動時の設定

1. アプリを起動
2. 「アクセシビリティの権限が必要です」というダイアログが表示される
3. 「システム設定 > プライバシーとセキュリティ > アクセシビリティ」を開く
4. CmdSwitcher を許可リストに追加

## メニューバー操作

メニューバーの `⌘` アイコンをクリック:

- **Disable/Enable**: 機能のON/OFF切り替え
- **Launch at Login**: ログイン時に自動起動
- **Open Accessibility Settings...**: 権限設定を開く
- **Quit**: アプリを終了

## 動作要件

- macOS 12.0 (Monterey) 以降
- アクセシビリティ権限

## ビルド要件

- Xcode Command Line Tools
- Swift 5.5+

## ライセンス

MIT License
