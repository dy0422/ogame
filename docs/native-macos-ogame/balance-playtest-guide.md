# 平衡测试指南

本项目采用快节奏单机局，不追求原版服务器的真实等待时间。当前目标窗口：

- 首艘舰船：T+10 到 T+25 分钟。
- 首次舰队出航：T+20 到 T+45 分钟。
- 首次冲突：T+45 到 T+90 分钟。
- 首次胜利：T+2 到 T+4 小时。

## 自动基线

运行：

```bash
swift run OGameBalanceTool
```

输出字段：

- `first_ship`
- `first_fleet`
- `first_espionage`
- `first_exploration`
- `first_conflict`
- `first_colony`
- `first_moon`
- `first_moon_action`
- `victory_at`
- `ai_attacks`
- `automation_actions`
- `player_rank`
- `events`
- `reports`

`OGameBalanceTool` 使用 `BalanceScenarioRunner`，包含轻量玩家引导脚本，用来验证一局新档可以稳定走到造舰、出航、侦察/探索、冲突、殖民和胜利。新增字段用于观察舰队槽、探索事件、月球系统和自动托管是否把节奏推离目标窗口。

## 手动 Playtest 记录

每次完整手动局记录：

- 第一次升级矿场的时间。
- 第一次造船的时间。
- 第一次侦察或探索的时间。
- 第一次舰队召回的时间。
- 第一次战斗的时间。
- 第一次殖民的时间。
- 第一次月球和第一次月球动作的时间。
- 胜利路线和胜利时间。
- 卡住、看不懂、需要更多提示的界面。
- 保存、读取、离线补算是否可信。

## 调参原则

- 玩家开局不能等太久，10 分钟内应看到明确目标。
- AI 必须主动发展，但离线期间不能连续攻击到让玩家无从挽回。
- 经济胜利不能只靠囤资源过早触发。
- 后期舰船成本应明显高于巡洋舰/战列舰，但在快节奏局中仍可见。
