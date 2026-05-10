# Native macOS OGame 发布成熟度审计与执行计划

## 当前结论

当前版本已经达到“可内部私测 / RC 前置版”的成熟度，但还不是适合公开分发给普通 Mac 用户的最终版。

- 私测可发布度：约 80%。核心玩法、存档、打包、资源、自动验证都已经跑通。
- 公开发布可发布度：约 65%。主要差距在签名公证、完整手动 playtest、README/发布说明、存档导入导出入口、以及大文件 UI/AppModel 拆分。

## 已具备能力

- SwiftUI 原生 macOS 单机版已经可运行。
- 核心玩法包含资源、能源、建筑、科技、舰队、侦察、探索、战斗、殖民、月球、AI、胜利路线、自动托管。
- `bash scripts/verify-release.sh` 已能串联核心测试、持久化测试、平衡工具、构建、打包和资源检查。
- `dist/OGameMac.app` 与 `dist/OGameMac.zip` 已能生成。
- 存档采用 schema envelope，未来 schema 会被拒绝，备份、导出、导入能力在 persistence 层已有测试覆盖。
- UI 已中文化，主要系统有解释文本和玩家指南。

## 发布阻塞项

### P0：RC 必须完成

1. 发布包元数据不完整。
   - `.app` 的 Info.plist 需要版本号、构建号、显示名称、类别和高分屏声明。
   - 验证脚本需要检查这些元数据，避免打出不可追踪的包。

2. 项目 README 仍偏向原 PHP 服务端说明。
   - 需要改成 Native OGame macOS 说明，保留 PHP 代码作为参考来源。
   - 普通测试者需要知道如何运行、如何打包、已知限制是什么。

3. 发布状态文档需要明确。
   - 需要把“离最终版还有多少差距”落成可追踪路线。
   - 清单要区分已自动验证、待手动验证、待证书/公证。

### P1：公开发布前必须完成

1. 手动完整局 playtest。
   - 至少完成一局新档，记录第一次造船、第一次舰队、第一次战斗、第一次殖民、第一次月球、胜利时间和卡点。

2. 存档管理 UI 补齐导入/导出/验证。
   - Repository 已有能力，但设置页目前主要展示备份和打开文件夹。
   - 发布前要把导入导出做成可发现的安全流程。

3. 签名、公证和 stapling。
   - 目前包适合本机或熟悉 Gatekeeper 的私测。
   - 公开发给普通用户前需要 Developer ID 签名、公证并 staple。

4. 大文件拆分。
   - `ContentView.swift` 超过 5,000 行，`AppModel.swift` 超过 3,000 行。
   - 这不阻塞私测，但会增加后续修 bug 和 UI 优化成本。

### P2：成熟商业/公开版本增强

1. App 图标、发布说明、崩溃/日志说明。
2. 更多新手引导和内置百科。
3. 长局性能与报告列表压力测试。
4. 更多舰队策略和 AI 行为调优。
5. UI 视觉统一与可访问性扫尾。

## 执行计划

### 阶段 1：发行硬化首批改动

目标：让自动验证能证明“这个包至少是可追踪、可私测、资源完整的 macOS 包”。

- [ ] 先修改 `scripts/verify-release.sh`，加入 Info.plist 版本/构建号/类别/可执行文件检查。
- [ ] 运行 `bash scripts/verify-release.sh`，确认当前包因缺少元数据失败。
- [ ] 修改 `script/build_and_run.sh`，写入可配置版本号、构建号、显示名称、类别和高分屏字段。
- [ ] 更新 `scripts/package-macos.sh`，说明版本环境变量和签名公证下一步。
- [ ] 更新 `README.md`，把入口从 PHP 服务端改成 Native macOS 版本。
- [ ] 更新 `final-release-checklist.md`，同步当前差距。
- [ ] 运行完整验证并提交。

### 阶段 2：存档导入导出 UI

目标：让普通测试者不用打开 Finder 手动复制 JSON。

- 在设置页加入“导出当前存档”“导入存档”“验证备份”。
- 导入前先迁移和验证 schema，导入成功后刷新槽位和状态。
- 导入失败不能覆盖 autosave。
- 增加 AppModel 层可测试包装，避免 UI 直接吞掉错误。

### 阶段 3：RC 手动验收

目标：形成 `native-ogame-v1-rc1` 前的证据。

- 按玩家指南打一局新档。
- 记录关键时间点和平衡卡点。
- 保存、退出、重开，确认离线补算可信。
- 若发现阻塞 bug，先补测试再修。

### 阶段 4：公开发行

目标：从私测包升级到普通用户可下载版本。

- 配置正式 bundle id、版本号和发布说明。
- 用 Developer ID Application 签名。
- 使用 notarytool 公证。
- staple 公证票据。
- 生成最终 zip 或 dmg，并创建 Git tag。

## 本轮执行范围

本轮执行阶段 1。完成后，项目会更接近 RC：自动验证更严格，包元数据可追踪，README 能直接指导 Mac 私测者。

## 本轮执行记录

- [x] 修改 `scripts/verify-release.sh`，加入 Info.plist 版本/构建号/类别/可执行文件检查。
- [x] 运行 `bash scripts/verify-release.sh`，确认旧包因缺少 `CFBundleShortVersionString` 失败。
- [x] 修改 `script/build_and_run.sh`，写入可配置版本号、构建号、显示名称、类别和高分屏字段。
- [x] 更新 `scripts/package-macos.sh`，说明版本环境变量和签名公证下一步。
- [x] 更新 `README.md`，把入口从 PHP 服务端改成 Native macOS 版本。
- [x] 更新 `final-release-checklist.md`，同步当前差距。
- [x] 重新运行 `bash scripts/verify-release.sh`，发布验证通过。
