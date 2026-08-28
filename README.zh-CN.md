# Mac Coffee 2.0

[English](README.md)

Mac Coffee 是一款轻量级原生 macOS 菜单栏应用，可在你需要时阻止空闲休眠。2.0 版移除了旧版的特权 helper 和持久化 `pmset` 修改，改用由应用进程持有的公开 IOKit 电源断言。

## 功能

- 关闭、保持 Mac 唤醒、保持屏幕唤醒三种明确状态
- 30 分钟、1/2/4/8 小时以及无限时长
- 10%–30% 可调的低电量保护，默认 15%
- 事件驱动的电池与系统生命周期监听，无空闲轮询
- 使用 `SMAppService` 的登录启动
- 英语和俄语本地化及 VoiceOver 标识
- 无 root helper、守护进程、分析、账号或后台服务
- Direct 与 Mac App Store 独立目标；Sparkle 仅存在于 Direct 版本
- 通用 `arm64` + `x86_64` 构建

Mac Coffee 只阻止因空闲导致的休眠，不会绕过手动休眠、合盖、温控保护、关机或其他 macOS 安全机制。

## 从源码构建

需要 macOS 13+、完整 Xcode、Homebrew 和 XcodeGen 2.46.0。

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

生成本地测试 DMG：

```sh
./scripts/package-dmg.sh
open dist/local/MacCoffee-2.0.0.dmg
```

构建不含 Sparkle 的 App Store 版本并验证两个包：

```sh
./scripts/build-local.sh app-store
./scripts/verify-bundles.sh
```

本地构建使用 ad-hoc 签名，只用于本机测试，不应作为正式版本发布。正式 Direct 发布脚本在缺少 Developer ID、notarytool 配置、HTTPS appcast 或 Sparkle EdDSA 密钥时会立即停止。

## 从 1.x 升级

2.0 不会安装或调用旧版特权 helper。如果安装过 1.x，请阅读[旧版清理指南](docs/LEGACY_CLEANUP.md)。清理脚本独立运行、需要管理员明确授权，并且不会被应用自动执行。

## 隐私

Mac Coffee 不收集数据、不跟踪用户。Direct 版本仅在用户主动检查签名更新时访问网络；App Store 版本不包含第三方更新器。

## 许可证

[MIT](LICENSE)
