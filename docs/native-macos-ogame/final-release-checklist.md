# 最终发布清单

## 自动验证

- [x] `swift run OGameCoreTests`
- [x] `swift run OGamePersistenceTests`
- [x] `swift run OGameBalanceTool`
- [x] `swift build`
- [x] `./script/build_and_run.sh --package`
- [x] `bash scripts/verify-release.sh`
- [x] `./script/build_and_run.sh --verify`

## 手动 Playtest

- [ ] 新档进入总览后能读懂指挥官简报。
- [ ] 15 分钟内能完成升级、研究或造船目标。
- [ ] 能派出至少一支舰队。
- [ ] 能产生侦察、探索、战斗或导弹战报。
- [ ] 能保存、退出、重开并补算离线进度。
- [ ] 胜利后能继续沙盒或重新开局。

## 存档与迁移

- [ ] 当前 schema 存档可读取。
- [ ] 当前 schema 存档可导出和导入。
- [ ] 备份可验证。
- [ ] 未来 schema 会被拒绝，不覆盖自动存档。
- [ ] 损坏存档不会静默覆盖现有文件。

## 包体

- [x] `dist/OGameMac.app` 存在。
- [x] `dist/OGameMac.zip` 存在。
- [x] `.app` 内含 `skins/xnova` 服务端图片。
- [x] 本地可打开运行。
- [ ] 公开发行前完成签名、公证和 stapling。

## 当前已知简化

- 仍是单机确定性宇宙，不含多人服务器。
- 月球设施已有模型和展示，完整建造链后续可继续深化。
- 原 PHP/TPL 浏览器端不再作为运行时，只作为资源与规则参考。
