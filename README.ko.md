# Mac Coffee 2.0

[English](README.md) · [Русский](README.ru.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [Español](README.es.md)

Mac Coffee는 가벼운 네이티브 macOS 메뉴 막대 앱입니다. 사용자가 깨우기 모드를 명시적으로 켠 동안에만 유휴 상태로 인한 자동 잠자기를 방지합니다.

## 기능

- 끄기, Mac 깨우기 유지, 디스플레이 깨우기 유지의 세 가지 모드.
- 30분, 1/2/4/8시간 또는 무제한 세션.
- 10%~30%로 설정 가능한 배터리 보호(기본값 15%).
- `SMAppService`를 사용한 로그인 시 실행.
- 앱을 다시 시작하거나 활성 세션을 중단하지 않고 8개 언어를 즉시 전환.
- 설정, 알림, 오류, 정보, 종료 확인 및 VoiceOver 텍스트 현지화.
- 종료 버튼과 `⌘Q`가 동일한 확인 절차를 사용.
- Direct 및 App Store 빌드를 분리하고 Sparkle은 Direct 빌드에만 포함.
- 관리자 권한, 특권 도우미, 계정, 분석 또는 서버가 필요 없음.

Mac Coffee는 유휴 상태로 인한 잠자기만 방지합니다. 수동 잠자기, 덮개 닫기, 시스템 종료 및 macOS 안전 보호는 항상 적용됩니다.

## 설치

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

메뉴 막대에서 현재 모드 아이콘을 열고 모드와 시간을 선택하세요. 설정에서 언어, 배터리 임계값 및 로그인 시 실행을 변경할 수 있습니다. 로컬 빌드는 ad-hoc 서명이므로 공식 배포에 사용할 수 없습니다.

전체 빌드, 테스트, 개인정보 보호 및 App Store 지침은 [영문 README](README.md)를 참조하세요. 지원 및 오류 신고: [GitHub Issues](https://github.com/rekurt/Mac-Coffee/issues). 라이선스: [MIT](LICENSE).
