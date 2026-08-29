# Mac Coffee 2.0

[English](README.md) · [Русский](README.ru.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [简体中文](README.zh-Hans.md) · [한국어](README.ko.md) · [Español](README.es.md)

Mac Coffee は、軽量でネイティブな macOS メニューバーアプリです。ユーザーが明示的に有効にした間だけ、アイドル状態による自動スリープを防ぎます。

## 機能

- オフ、Mac をスリープさせない、ディスプレイをスリープさせないの 3 モード。
- 30 分、1/2/4/8 時間、または無制限のセッション。
- 10%〜30% で調整できるバッテリー保護（デフォルト 15%）。
- `SMAppService` によるログイン時の起動。
- アプリの再起動や進行中のセッションの中断なしで、8 言語を即座に切り替え。
- 設定、通知、エラー、情報、終了確認、VoiceOver テキストを完全にローカライズ。
- 終了ボタンと `⌘Q` に共通の確認フロー。
- Direct 版と App Store 版を分離し、Sparkle は Direct 版だけに搭載。
- 管理者権限、特権ヘルパー、アカウント、解析、サーバーは不要。

Mac Coffee が防ぐのはアイドル状態によるスリープだけです。手動スリープ、蓋を閉じる操作、システム終了、macOS の安全保護は常に有効です。

## インストール

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

メニューバーに表示された現在のモードアイコンを開き、モードと時間を選択します。設定では言語、バッテリーしきい値、ログイン時の起動を変更できます。ローカルビルドは ad-hoc 署名のため、正式配布には使用できません。

ビルド、テスト、プライバシー、App Store の詳細は[英語版 README](README.md)をご覧ください。サポート：[GitHub Issues](https://github.com/rekurt/Mac-Coffee/issues)。ライセンス：[MIT](LICENSE)。
