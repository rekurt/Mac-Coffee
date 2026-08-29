# Mac Coffee 2.0

[English](README.md) · [Русский](README.ru.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Mac Coffee 是一款轻量的原生 macOS 菜单栏应用。只有在你明确启用唤醒模式时，它才会阻止 Mac 因闲置而自动睡眠。

## 功能

- 关闭、保持 Mac 唤醒、保持显示器唤醒三种模式。
- 30 分钟、1/2/4/8 小时或无限时长。
- 10%–30% 可调的电量保护，默认 15%。
- 通过 `SMAppService` 登录时启动。
- 无需重启应用或中断活动会话，即可在八种语言之间即时切换。
- 已本地化设置、通知、错误、关于、退出确认和 VoiceOver 文本。
- 底部退出按钮与 `⌘Q` 使用同一个确认流程。
- Direct 与 App Store 构建完全分离；Sparkle 仅用于 Direct 构建。
- 不需要管理员权限、特权 helper、账户、分析或服务器。

Mac Coffee 只阻止因闲置而进入睡眠。手动睡眠、合上盖子、关机以及 macOS 的安全保护始终有效。

## 安装

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

打开菜单栏中的当前模式图标，选择模式和时长。你可以在“设置”中更改语言、电量阈值和登录启动。该本地构建仅使用 ad-hoc 签名，不能作为正式版本分发。

完整的构建、测试、隐私和 App Store 说明请参阅[英文 README](README.md)。帮助与错误报告：[GitHub Issues](https://github.com/rekurt/Mac-Coffee/issues)。许可证：[MIT](LICENSE)。
