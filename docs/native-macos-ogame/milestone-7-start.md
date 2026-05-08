# Milestone 7 Start: 全线推进计划

当前阶段目标：在 Milestone 4-6 的基础上，同时启动体验、平衡、UI 图片、发行存档、后期内容五条线。

## 1. Beta 体验闭环

- 已开始：总览页新增“指挥官简报”，根据资源、建筑、科研、舰队、胜利进度给出下一步建议。
- 已开始：胜利后显示结算面板，保留继续沙盒推进与重新开局入口。
- 后续：增加新手局前 15 分钟的事件链、失败复盘、局后统计与最佳时间记录。

## 2. 快节奏单机平衡

- 已开始：新增 `OGameBalanceTool`，可用 `swift run OGameBalanceTool` 输出多难度、多时长的局面 CSV。
- 后续：把 30/60/120/240 分钟样本固化成平衡基线，调整 AI 经济、殖民、进攻和胜利目标曲线。

## 3. UI 与服务端图片复刻

- 已开始：新增 `GameAssets`，映射原始 XNova `skins/xnova` 图片资源。
- 已开始：星球、月球、残骸、资源、建筑、科技、舰船、防御、导弹列表使用服务端图片。
- 后续：继续按原服务端页面风格优化战报、星图、舰队派遣和胜利页的图像密度与信息层级。

## 4. 存档与 macOS 发行

- 已开始：打包脚本会复制 `skins/xnova` 到 `.app/Contents/Resources`。
- 已开始：`script/build_and_run.sh --package` 可生成 `dist/OGameMac.zip`。
- 已开始：存档管理面板新增“打开文件夹”。
- 后续：补应用图标、签名/公证说明、版本号和可发布 DMG。

## 5. 后期内容

- 已开始：现有月球、导弹、残骸系统开始获得专属图片表现。
- 后续：补月球建筑、感应阵、跳跃门、星际导弹拦截弹、更多舰船与更完整的后期科技链。

## 验证命令

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift run OGameBalanceTool
swift build
./script/build_and_run.sh --verify
./script/build_and_run.sh --package
```
