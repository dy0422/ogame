# Native OGame macOS

这是一个基于 OGame 玩法重新设计的 SwiftUI 原生 macOS 单机版。仓库里保留了早期 PHP/TPL 服务端代码作为规则和美术资源参考，但当前主线运行时是 `NativeOGame` Swift Package。

## 当前状态

- 可运行的 macOS 单机游戏：资源、建筑、科技、舰队、侦察、探索、战斗、殖民、月球、AI 对手、胜利路线和自动托管都已接入。
- 快节奏单机局：目标是在 2 到 4 小时模拟时间内形成完整局面，而不是复刻原版服务器的长等待。
- 已支持自动验证和本地打包：`dist/OGameMac.app` 与 `dist/OGameMac.zip`。
- 当前适合本机/内部私测。公开分发前还需要签名、公证、完整手动 playtest 和发布说明收口。

## 运行

```bash
./script/build_and_run.sh
```

常用模式：

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --package
bash scripts/verify-release.sh
```

`--package` 会生成：

- `dist/OGameMac.app`
- `dist/OGameMac.zip`

## 版本元数据

打包时可以通过环境变量覆盖版本信息：

```bash
NATIVE_OGAME_VERSION=0.1.0 \
NATIVE_OGAME_BUILD_NUMBER=100 \
NATIVE_OGAME_BUNDLE_ID=com.example.NativeOGame \
./script/build_and_run.sh --package
```

默认 bundle id 是 `dev.local.NativeOGame.OGameMac`，适合本地测试；公开发行前应换成正式 bundle id。

## 验证

完整发布验证：

```bash
bash scripts/verify-release.sh
```

该脚本会运行：

- `swift run OGameCoreTests`
- `swift run OGamePersistenceTests`
- `swift run OGameBalanceTool`
- `swift build`
- `.app` 打包
- 服务端图片资源检查
- Info.plist 版本、构建号、类别和高分屏字段检查

## 文档

- 发布成熟度计划：[docs/native-macos-ogame/release-readiness-2026-05-10.md](docs/native-macos-ogame/release-readiness-2026-05-10.md)
- 最终发布清单：[docs/native-macos-ogame/final-release-checklist.md](docs/native-macos-ogame/final-release-checklist.md)
- 玩家指南：[docs/native-macos-ogame/player-guide.md](docs/native-macos-ogame/player-guide.md)
- 平衡测试指南：[docs/native-macos-ogame/balance-playtest-guide.md](docs/native-macos-ogame/balance-playtest-guide.md)

## 已知限制

- 当前是确定性单机宇宙，不包含多人服务器。
- PHP/TPL 代码不再作为主运行时。
- 私测包尚未签名、公证或 staple。
- 存档导入/导出在 persistence 层已实现并测试，设置页的完整安全 UI 仍在发布计划中。
