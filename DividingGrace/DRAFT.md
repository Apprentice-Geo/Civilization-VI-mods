# Dividing Grace（推恩令）草稿

本目录留存人民战争旧版推恩令的代码。草稿缺少 `.modinfo`，游戏无法加载。弹窗方案已取消，后续直接讨论阶段 C 的城市生产项目。现有代码供人口分配与城市移除逻辑的设计参考。 [推恩令开发计划](../DividingGrace%20Refactor%20Direction.md)

## 来源

阶段 A 从 People's War 摘出推恩令实现，随后 People's War 5.0 移除了该机制。

| 文件 | 来源 |
| --- | --- |
| `UI/RazeCity_PeoplesWar.lua` / `.xml` | `PeoplesWar/UI/`（原样复制） |
| `UI/RazeCity_Disabled.lua` | `PeoplesWar/UI/`（原样复制） |
| `UI/DisloyalCityChooser_PeoplesWar.lua` / `.xml` | `PeoplesWar/UI/`（原样复制） |
| `UI/DisloyalCityChooser_Disabled.lua` | `PeoplesWar/UI/`（原样复制） |
| `Gameplay/DividingGrace_Gameplay.lua` | `PeoplesWar/Gameplay/PeoplesWar_Gameplay.lua` 中的推恩令部分 |
| `Gameplay/DividingGrace_Localization.sql` | `PeoplesWar/Gameplay/PeoplesWar_Localization.sql` 中的 4 条文案 |

## 阶段 A 的已知差异

- 标识符与属性名仍是 `PEOPLES_WAR_*`，UI 文件名也保持 `_PeoplesWar` 后缀。
- 草稿只保留推恩令逻辑；人口增幅（单位战斗力、城市远程/防御/反间谍）留在 People's War，因此草稿中的 `RequestPlayerUpdate` 是空实现，人口事件批处理标记 `m_batching` / `m_updateRequested` 已去掉。
- 按钮文案已按新术语写为“推恩令”/“Dividing Grace”。
