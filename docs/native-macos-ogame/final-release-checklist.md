# 最终发布清单

当前发布成熟度：

- 私测 / RC 前置版：约 80%，可生成可运行包，自动验证已通过。
- 公开发布版：约 65%，仍需签名公证、完整手动 playtest、存档导入导出 UI 和发布说明收口。

## 自动验证

- [x] `swift run OGameCoreTests`
- [x] `swift run OGamePersistenceTests`
- [x] `swift run OGameBalanceTool`
- [x] `swift build`
- [x] `./script/build_and_run.sh --package`
- [x] `bash scripts/verify-release.sh`
- [x] `./script/build_and_run.sh --verify`
- [x] `.app` Info.plist 包含版本号、构建号、显示名称、类别和高分屏字段。

## 手动 Playtest

- [ ] 新档进入总览后能读懂指挥官简报。
- [ ] 15 分钟内能完成升级、研究或造船目标。
- [ ] 能派出至少一支舰队。
- [ ] 能产生侦察、探索、战斗或导弹战报。
- [ ] 能保存、退出、重开并补算离线进度。
- [ ] 胜利后能继续沙盒或重新开局。

## 存档与迁移

- [ ] 当前 schema 存档可读取。
- [x] 当前 schema 存档可导出和导入。
- [x] 备份可验证。
- [x] 未来 schema 会被拒绝，不覆盖自动存档。
- [ ] 设置页提供完整导入/导出/验证入口。
- [x] 损坏存档不会静默覆盖现有文件。

## 包体

- [x] `dist/OGameMac.app` 存在。
- [x] `dist/OGameMac.zip` 存在。
- [x] `.app` 内含 `skins/xnova` 服务端图片。
- [x] 本地可打开运行。
- [x] 本地包可追踪版本号和构建号。
- [ ] 公开发行前完成签名、公证和 stapling。

## 当前已知简化

- 仍是单机确定性宇宙，不含多人服务器。
- 月球设施已有模型和展示，完整建造链后续可继续深化。
- 原 PHP/TPL 浏览器端不再作为运行时，只作为资源与规则参考。
- 当前私测包未签名，普通用户首次打开可能受到 Gatekeeper 提醒。
