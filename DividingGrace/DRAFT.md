# Dividing Grace（推恩令）草稿

本目录是**草稿**，不是可用的 mod：

- 不含 `.modinfo`，游戏不会加载它；
- 未列入 [README.md](../README.md) / [README.en.md](../README.en.md)，也没有封面；
- 不要求完成，也不要求合并到 `main`。

完整计划见仓库根目录的 [DividingGrace Refactor Direction.md](../DividingGrace%20Refactor%20Direction.md)。

## 来源

阶段 A 从 People's War 原样摘出推恩令实现，随后 People's War 在本分支移除了该机制。本目录是该实现的唯一副本。

| 文件 | 来源 |
| --- | --- |
| `UI/RazeCity_PeoplesWar.lua` / `.xml` | `PeoplesWar/UI/`（原样复制） |
| `UI/RazeCity_Disabled.lua` | `PeoplesWar/UI/`（原样复制） |
| `UI/DisloyalCityChooser_PeoplesWar.lua` / `.xml` | `PeoplesWar/UI/`（原样复制） |
| `UI/DisloyalCityChooser_Disabled.lua` | `PeoplesWar/UI/`（原样复制） |
| `Gameplay/DividingGrace_Gameplay.lua` | `PeoplesWar/Gameplay/PeoplesWar_Gameplay.lua` 中的推恩令部分 |
| `Gameplay/DividingGrace_Localization.sql` | `PeoplesWar/Gameplay/PeoplesWar_Localization.sql` 中的 4 条文案 |

## 阶段 A 的已知差异

- 标识符与属性名仍是 `PEOPLES_WAR_*`，阶段 B 再统一改为 `DIVIDING_GRACE_*`；UI 文件名也保持 `_PeoplesWar` 后缀。
- 草稿只保留推恩令逻辑；人口增幅（单位战斗力、城市远程/防御/反间谍）留在 People's War，因此草稿中的 `RequestPlayerUpdate` 是空实现，人口事件批处理标记 `m_batching` / `m_updateRequested` 已去掉。
- 按钮文案已按新术语写为“推恩令”/“Dividing Grace”。

## 下一步（阶段 B）

1. 补 `DividingGrace.modinfo`：新 UUID、`RULESET_EXPANSION_2`、两个 `ReplaceUIScript`（`LoadOrder 100721`）、`AddUserInterfaces`、`ImportFiles` 与 `<Files>`。
2. 按计划的改名对照表统一文件与标识符。
3. 独立验证 UI 入口、人口分配与存档重载行为。
