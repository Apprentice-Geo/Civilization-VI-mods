# People's War 改造方向：纯人口增强 Mod

## 改动目标

把 People's War 收敛为只做人口增强的 mod，并把内嵌的推恩令机制整体迁出。本版是 People's War 的**最终交付版本**，推恩令不在本次交付范围内。

改造后 People's War 保留三类效果：

| 效果 | 数值 | 作用对象 |
| --- | --- | --- |
| 帝国总人口 → 单位战斗力 | 每 10 帝国总人口 +1 普通与宗教战斗力，上限 +100 | 人类主要玩家 |
| 每座城市人口 → 城市增幅 | 每 5 人口一档：+2 远程攻击、+2 防御、+1 反间谍等级，上限 +40 / +40 / +20 | 人类主要玩家 |
| 征服城市人口不损失 | 征服人口损失豁免 100% | 人类主要玩家 |

推恩令机制的留存与后续开发见 [DividingGrace Refactor Direction.md](DividingGrace%20Refactor%20Direction.md)。

## 已确认事项

- 推恩令机制**原样迁出**，本次不改造成城市 Project；其代码以草稿形式留存，不阻塞本版交付。
- “征服城市人口不会损失”**留在 People's War**，不随推恩令迁出。
- 帝国总人口 → 单位战斗力**保持不变**（每 10 人口 +1，上限 +100）；本次只加强城市增幅。
- **采用破坏性兼容**：不要求旧存档平滑升级，modifier 与属性 ID 可自由重建，旧存档加成异常可接受。
- **不保留版本号后缀**：属性命名统一为纯 `PEOPLES_WAR_*`，现有 `PEOPLES_WAR_V2_CITY_MODIFIERS_ATTACHED` 去掉 `V2`。
- 项目内“解放”表述一律改称“推恩令”，包括 UI 文案、计划文档与代码注释。

## 数值规格

### 城市增幅（本次加强）

阈值 `1 + 5 × (k - 1)`，k = 1..20 → 1、6、11、…、96：

| 城市人口 | 档位 | 远程攻击 | 防御 | 反间谍等级 |
| --- | --- | --- | --- | --- |
| 1–5 | 1 | +2 | +2 | +1 |
| 6–10 | 2 | +4 | +4 | +2 |
| 11–15 | 3 | +6 | +6 | +3 |
| … | … | … | … | … |
| 91–95 | 19 | +38 | +38 | +19 |
| 96+ | 20 | +40 | +40 | +20 |

沿用现有“同阈值 modifier 堆叠”实现（[PeoplesWar_CityEffects.sql](PeoplesWar/Gameplay/PeoplesWar_CityEffects.sql)）：20 个 `REQUIREMENT_CITY_HAS_X_POPULATION`、20 个 `RequirementSet`、60 个 modifier，其中远程攻击 `Amount = 2`、防御 `Amount = 2`、反间谍级别 `Amount = 1`。

### 帝国单位战斗力（不变）

等级 = `ceil(帝国总人口 / 10)`，上限 100，由 `ABILITY_PEOPLES_WAR_COMBAT_n` / `ABILITY_PEOPLES_WAR_RELIGIOUS_n` 承载，Lua 按等级切换。

## 文件级改动清单

| 文件 | 改动 |
| --- | --- |
| [PeoplesWar.modinfo](PeoplesWar/PeoplesWar.modinfo) | `version` 4.0 → 5.0；改写 `Description` / `Teaser`；删除 5 个推恩令相关动作与 6 个 UI 文件条目 |
| [PeoplesWar_Gameplay.lua](PeoplesWar/Gameplay/PeoplesWar_Gameplay.lua) | 删除推恩令事务代码；城市档位 10 → 20 |
| [PeoplesWar_Abilities.sql](PeoplesWar/Gameplay/PeoplesWar_Abilities.sql) | 重新生成，保留单位能力与 `PEOPLES_WAR_NO_POPULATION_LOSS_AFTER_CONQUEST` |
| [PeoplesWar_CityEffects.sql](PeoplesWar/Gameplay/PeoplesWar_CityEffects.sql) | 重新生成 20 档 |
| [PeoplesWar_Localization.sql](PeoplesWar/Gameplay/PeoplesWar_Localization.sql) | 删除 4 条推恩令文案 |
| [generate_peoples_war_abilities.py](PeoplesWar/Tools/generate_peoples_war_abilities.py) | 更新档位常量与 modifier 数值；删除推恩令文案生成 |
| `PeoplesWar/UI/`（6 个文件） | 先原样复制为草稿，再从本 mod 删除 |
| [README.md](README.md) / [README.en.md](README.en.md) | 人民战争小节改写；不新增推恩令小节 |

### modinfo 动作删除清单

- `PeoplesWar_DisableBaseRazeCity`、`PeoplesWar_DisableBaseDisloyalCityChooser`（`ReplaceUIScript`）
- `PeoplesWar_DisloyalCityChooser`、`PeoplesWar_RazeCity`（`AddUserInterfaces`）
- `PeoplesWar_UIFiles`（`ImportFiles`）
- `<Files>` 中 6 个 UI 文件条目

### Gameplay Lua 删除清单

常量与变量：

- `DISSOLVE_READY_PLOT_PROPERTY`、`DISSOLVE_COMMITTED_PLOT_PROPERTY`、`PLOT_SET_ENCODING_PREFIX`
- `PROPERTY_PENDING_PLOTS`、`PROPERTY_TX_ID`、`PROPERTY_TX_CITY_ID`、`PROPERTY_TX_TARGET_PLOT`、`PROPERTY_TX_POPULATION`、`PROPERTY_TX_RECIPIENTS`、`PROPERTY_TX_TURN`
- `m_batching`、`CommitDissolve` 前向声明

函数：

- `DecodePlotSet`、`EncodePlotSet`、`GetCityAtPlotIndex`、`GetCityPlotIndex`
- `CleanPendingPlots`、`AddPendingCity`、`RemovePendingCity`
- `ClearTransaction`、`PrepareDissolve`、`ResolveCapture`、`OnCityOperation`
- `ValidateRecipientCities`、`CommitDissolve`、`OnCityRemovedFromMap`
- `UpdatePlayerNow` 中的 `CleanPendingPlots(player)` 调用
- `OnPlayerTurnStarted` 中的 `PROPERTY_TX_ID` 过期清理
- `RequestPlayerUpdate` 中的 `m_batching` 分支
- `Initialize` 中的 `GameEvents.PeoplesWar_CityOperation`、`Events.CityRemovedFromMap` 注册

保留：

- `IsTargetPlayer`、`GetTotalPopulation`、`GetCappedLevel`、`GetNumberProperty`、`Log`
- 单位能力相关：`IsReligiousUnit`、`IsCombatUnit`、`SetAbilityCount`、`ApplyUnitLevel`、`ApplyLevelToAllUnits`
- `AttachPlayerModifiers`、`UpdatePlayerNow`、`RequestPlayerUpdate`
- `OnCityPopulationChanged`、`OnCityChanged`、`OnUnitCreated`、`OnCityConquered`（简化为只调用 `RequestPlayerUpdate`）、`OnPlayerTurnStarted`、`Initialize`

### 城市档位改动

- `CITY_POPULATION_EFFECT_LEVELS`：10 → 20
- 阈值公式：`1 + ((level - 1) * 10)` → `1 + ((level - 1) * 5)`
- 附着标志：`PEOPLES_WAR_V2_CITY_MODIFIERS_ATTACHED` → `PEOPLES_WAR_CITY_MODIFIERS_ATTACHED`

附着标志必须去掉 `V2` 换名：旧存档中 `V2` 标志为 1 时，新的 20 档 modifier 不会被附着，只会保留旧的 10 档加成。换名后的破坏性影响见下节。

### 生成器改动

- `CITY_POPULATION_THRESHOLDS = tuple(range(1, 97, 5))`
- `generate_city_effects` 的 modifier 循环带上数值：远程攻击 2、防御 2、反间谍级别 1
- `generate_localization` 只保留 `LOC_PEOPLES_WAR_PREVIEW_*`

### 文案规格

`Description`：

- zh：仅限风云变幻。人类主要玩家从1人口起，每10点帝国总人口获得+1普通与宗教战斗力，最高+100。每座城市从1人口起、每增加5人口获得+2远程攻击与防御，最高+40；并获得+1反间谍等级，最高+20。征服城市人口不会损失。
- en：Gathering Storm only. Starting at 1 population, human major players gain +1 normal and religious combat strength per 10 total population, capped at +100. Starting at 1 population, each city gains +2 ranged strike and defense per 5 population, capped at +40, and +1 counter-spy level per 5 population, capped at +20. Conquered cities lose no population.

`Teaser`：

- zh：基于人口数量强化单位与城市。
- en：Strengthen units and cities based on population.

README 人民战争小节（两条数值描述 + 征服不掉人口），并删除其中的推恩令条目；中英两版表述必须一致。推恩令尚未发布，两条 README 都不新增其小节。

## 已知影响（破坏性兼容，接受）

- 旧存档中已附着的 10 档城市 modifier 继续生效：SQL 中同 ID 的 modifier 依旧存在，只是 `Amount` 由 1 改为 2。
- 新的 `PEOPLES_WAR_CITY_MODIFIERS_ATTACHED` 未设置，代码会重新附着完整的 20 档；其中 10 个 ID 与旧存档已有的重复，而重复附着会叠加（现有实现的附着标志正是为此而设）。
- 结果：旧存档的城市加成会超出新上限，远程 / 防御最高约 +60、反间谍等级约 +30。
- 这是本版有意接受的破坏性结果，不额外写清理逻辑；需要干净数值时开新存档即可。

## 实施顺序

People's War 先行交付，推恩令不阻塞本次合并：

1. **留存草稿**：把现有推恩令实现（`PeoplesWar/UI/` 6 个文件 + Gameplay 事务代码 + 4 条本地化文案）原样复制到草稿目录 `DividingGrace/`，不带 `.modinfo`，供后续继续开发（见 [DividingGrace Refactor Direction.md](DividingGrace%20Refactor%20Direction.md) 阶段 A）。
2. **剥离推恩令**：删除 5 个 modinfo 动作、6 个 UI 文件条目，以及 [PeoplesWar_Gameplay.lua](PeoplesWar/Gameplay/PeoplesWar_Gameplay.lua) 中的事务代码与 4 条本地化文案。
3. **加强城市增幅**：更新生成器与 Lua 档位（10 → 20 档），重新生成三个 SQL。
4. **同步文案**：`version` 5.0、`Description`、`Teaser` 与 [README.md](README.md) / [README.en.md](README.en.md) 中英两版。
5. **交付**：静态检查 + 游戏内验证后，通过 PR 或直接 merge 到 `main`。

草稿目录与推恩令的后续开发不要求合并到 `main`，其正式 mod 化与 Project 重构见其计划文档阶段 B / C。

## 风险与待验证

1. **附着标志换名**：必须去掉 `V2`；旧存档的具体影响已记录在“已知影响（破坏性兼容）”。
2. **征服后的人口刷新**：已保留简化版 `OnCityConquered`，只调用 `RequestPlayerUpdate` 刷新人口增幅（不再登记 pending 地块）。建议在游戏内确认征服瞬间的单位战斗力等级即时更新。
3. **单位能力等级切换**：`OnUnitCreated` 读取玩家属性 `PEOPLES_WAR_COMBAT_LEVEL`，该属性语义不变。
4. **草稿可用性**：草稿目录不含 `.modinfo`，游戏不会加载它；阶段 B 之前它只是代码存档。
5. **README 一致性**：中英两版的范围、触发时机、上限必须表达同一行为。

## 验证

- `.modinfo` XML 可解析，`version` 为 5.0。
- 搜索确认 People's War 目录内不再有 `DISSOLVE` 与“解放”残留。
- 重新生成三个 SQL 后 `git diff` 只包含预期变化。
- 游戏内：新建 1 人口城市立即获得 +2 远程 / +2 防御 / +1 反间谍；6、96 人口档位正确；96 人口以上稳定在 +40 / +40 / +20；征服城市人口不损失；单位战斗力仍为每 10 人口 +1、上限 +100。
- 确认原版 `RazeCity` / `DisloyalCityChooser` 不再被 People's War 替换。
- `git diff --check` 无空白问题。
