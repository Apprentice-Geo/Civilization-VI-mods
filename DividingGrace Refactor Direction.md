# Dividing Grace（推恩令）开发计划

## 背景

“推恩令”最初以“解放”为名内嵌在 People's War 中：占领或因忠诚度归附的城市可在征服弹窗中选择该动作，效果是撤销城市建制，并把全部人口重新分配给其他已确定保留的城市。该机制与 People's War 的人口增强主题无关，且接管了原版 `RazeCity`、`DisloyalCityChooser` 两个共享 UI Context，因此拆分为独立 mod。

本计划与 [PeoplesWar Refactor Direction.md](PeoplesWar%20Refactor%20Direction.md) 配套：People's War 先行交付并合并到 `main`，推恩令只留存草稿。

## 发布状态与分支策略

| 项 | 要求 |
| --- | --- |
| 完成度 | **不要求完成**，当前只保留草稿 |
| 合并 | **不要求合并到 `main`**，不阻塞 People's War 的 PR |
| 草稿位置 | 仓库根目录 `DividingGrace/`，**不含 `.modinfo`**，因此游戏不会将其识别为 mod |
| 草稿标记 | 目录内 `DRAFT.md` 说明“草稿、未发布、不参与游戏加载” |
| README | 不新增推恩令小节（未发布） |
| 封面 | 不创建；提示词见下文“封面（发布时使用）” |

草稿可以随 People's War 的提交一起留在 `main`（它是纯代码存档，不影响 mod 加载与发布）；如果你希望 `main` 保持干净，把草稿单独留在长期分支即可，两种做法都不影响本计划的后续步骤。

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 阶段 A | 草稿留存：从 People's War 原样复制现有实现 | 已完成（随 People's War 交付） |
| 阶段 B | 正式 mod 化：命名空间改名、补 `.modinfo`、独立验证 | 待实施（不设期限） |
| 阶段 C | 重构为城市 Project，取消共享 UI 接管 | 设计稿（见下） |

## 命名

| 项 | 取值 |
| --- | --- |
| 中文名 | 推恩令 |
| 英文名 | Dividing Grace |
| 目录 | `DividingGrace` |
| 属性 / 事件前缀 | `DIVIDING_GRACE_` / `DividingGrace_` |
| 本地化前缀 | `LOC_DIVIDING_GRACE_` |

## 阶段 A：草稿留存

从 People's War 剥离前，先把现有实现原样复制到 `DividingGrace/`。此阶段**不改文件名、不改标识符**，尽量保持与原代码逐字一致，方便阶段 B 做可控的重命名。

| 来源（People's War） | 草稿去向（DividingGrace） |
| --- | --- |
| `UI/RazeCity_PeoplesWar.lua` | `UI/RazeCity_PeoplesWar.lua` |
| `UI/RazeCity_PeoplesWar.xml` | `UI/RazeCity_PeoplesWar.xml` |
| `UI/RazeCity_Disabled.lua` | `UI/RazeCity_Disabled.lua` |
| `UI/DisloyalCityChooser_PeoplesWar.lua` | `UI/DisloyalCityChooser_PeoplesWar.lua` |
| `UI/DisloyalCityChooser_PeoplesWar.xml` | `UI/DisloyalCityChooser_PeoplesWar.xml` |
| `UI/DisloyalCityChooser_Disabled.lua` | `UI/DisloyalCityChooser_Disabled.lua` |
| `PeoplesWar_Gameplay.lua` 中的推恩令事务代码 | `Gameplay/DividingGrace_Gameplay.lua` |
| `PeoplesWar_Localization.sql` 中的 4 条文案 | `Gameplay/DividingGrace_Localization.sql` |
| —— | `DRAFT.md`（状态说明） |

草稿中的 Gameplay 脚本只包含推恩令逻辑，因此需要从 [PeoplesWar_Gameplay.lua](PeoplesWar/Gameplay/PeoplesWar_Gameplay.lua) 摘出以下部分：`DecodePlotSet`、`EncodePlotSet`、`GetCityAtPlotIndex`、`GetCityPlotIndex`、`CleanPendingPlots`、`AddPendingCity`、`RemovePendingCity`、`ClearTransaction`、`PrepareDissolve`、`ResolveCapture`、`OnCityOperation`、`OnCityConquered`、`ValidateRecipientCities`、`CommitDissolve`、`OnCityRemovedFromMap`，以及它们依赖的 `Log`、`GetNumberProperty`、`IsTargetPlayer` 与 `OnPlayerTurnStarted` 中的事务过期清理。

## 阶段 B：正式 mod 化

### modinfo 要点

- 新 UUID，不得与 `PeoplesWar` 的 `7e6dfc8c-a7a4-4d1b-a96e-df7a24d70445` 重复。
- `AffectsSavedGames` 1、`SupportsMultiplayer` 1、`SupportsHotSeat` 1、`CompatibleVersions` 2.0。
- `ActionCriteria` 限 `RULESET_EXPANSION_2`。
- `AddGameplayScripts`：`Gameplay/DividingGrace_Gameplay.lua`。
- `UpdateText`：`Gameplay/DividingGrace_Localization.sql`。
- `ReplaceUIScript` ×2（`RazeCity`、`DisloyalCityChooser`，`LoadOrder 100721`）配合两个 `_Disabled.lua`。
- `AddUserInterfaces` ×2（`Context = InGame`）、`ImportFiles`（4 个 UI 文件）。
- `<Files>` 覆盖随包发布的全部文件。

### 文件重命名

| 草稿（阶段 A） | 正式（阶段 B） |
| --- | --- |
| `UI/RazeCity_PeoplesWar.lua` | `UI/RazeCity_DividingGrace.lua` |
| `UI/RazeCity_PeoplesWar.xml` | `UI/RazeCity_DividingGrace.xml` |
| `UI/DisloyalCityChooser_PeoplesWar.lua` | `UI/DisloyalCityChooser_DividingGrace.lua` |
| `UI/DisloyalCityChooser_PeoplesWar.xml` | `UI/DisloyalCityChooser_DividingGrace.xml` |
| `UI/RazeCity_Disabled.lua` / `UI/DisloyalCityChooser_Disabled.lua` | 名称不变 |

### 命名空间改名对照

| 旧（People's War） | 新（Dividing Grace） |
| --- | --- |
| `PEOPLES_WAR_PENDING_CITY_PLOTS` | `DIVIDING_GRACE_PENDING_CITY_PLOTS` |
| `PEOPLES_WAR_DISSOLVE_READY` | `DIVIDING_GRACE_READY` |
| `PEOPLES_WAR_DISSOLVE_COMMITTED` | `DIVIDING_GRACE_COMMITTED` |
| `PEOPLES_WAR_DISSOLVE_TX_ID` | `DIVIDING_GRACE_TX_ID` |
| `PEOPLES_WAR_DISSOLVE_TX_CITY_ID` | `DIVIDING_GRACE_TX_CITY_ID` |
| `PEOPLES_WAR_DISSOLVE_TX_TARGET_PLOT` | `DIVIDING_GRACE_TX_TARGET_PLOT` |
| `PEOPLES_WAR_DISSOLVE_TX_POPULATION` | `DIVIDING_GRACE_TX_POPULATION` |
| `PEOPLES_WAR_DISSOLVE_TX_RECIPIENTS` | `DIVIDING_GRACE_TX_RECIPIENTS` |
| `PEOPLES_WAR_DISSOLVE_TX_TURN` | `DIVIDING_GRACE_TX_TURN` |
| `PeoplesWar_CityOperation` | `DividingGrace_CityOperation` |
| `LOC_PEOPLES_WAR_DISSOLVE_BUTTON` | `LOC_DIVIDING_GRACE_BUTTON` |
| `LOC_PEOPLES_WAR_DISSOLVE_DESCRIPTION` | `LOC_DIVIDING_GRACE_DESCRIPTION` |
| `LOC_PEOPLES_WAR_DISSOLVE_NO_RECIPIENTS` | `LOC_DIVIDING_GRACE_NO_RECIPIENTS` |
| `LOC_PEOPLES_WAR_DISSOLVE_COMMAND_BLOCKED` | `LOC_DIVIDING_GRACE_COMMAND_BLOCKED` |

改名时保持既有交互契约不变：

- UI 通过 `UI.RequestPlayerOperation(..., PlayerOperations.EXECUTE_SCRIPT, parameters)` 调用 gameplay，`OnStart = DividingGrace_CityOperation`。
- 玩家属性保存事务快照；地块属性 `DIVIDING_GRACE_READY` / `DIVIDING_GRACE_COMMITTED` 作为 UI 与 gameplay 之间的握手信号。
- 人口均分规则不变：整除后按人口升序每城补 1。
- `CityRemovedFromMap` 是删除权威；事务必须在发起回合内完成，过期即清理。

### 文案

| 键 | zh_Hans_CN | en_US |
| --- | --- | --- |
| `LOC_DIVIDING_GRACE_BUTTON` | 推恩令 | Dividing Grace |
| `LOC_DIVIDING_GRACE_DESCRIPTION` | 撤销该城市的城市建制，并将全部人口重新分配至帝国其他已确定保留的城市。无法均分的余数依次分配给其中人口最少的城市，每座城市一个人口。 | Dissolve this city and redistribute its entire population among your other retained cities. Any remainder is assigned one population each to the least-populous eligible cities. |
| `LOC_DIVIDING_GRACE_NO_RECIPIENTS` | 没有其他已确定保留的城市可以接收人口。 | No other retained city can receive this population. |
| `LOC_DIVIDING_GRACE_COMMAND_BLOCKED` | 当前游戏状态不允许对该城市施行推恩令。 | The current game state does not allow Dividing Grace in this city. |

## 与其他 mod 的关系

- People's War 与 Dividing Grace 互相独立、可单独启用；“征服城市人口不会损失”留在 People's War。
- 只启用 Dividing Grace 时，被征服城市的人口已按原版规则损失，可再分配的人口更少。README 与 modinfo 应建议与 People's War 同时启用。
- 与 [RazeOriginalCapital](RazeOriginalCapital/RazeOriginalCapital.modinfo) 的交互：它把 [`COMBAT_RAZE_ANY_CITY`](RazeOriginalCapital/RazeOriginalCapital.sql#L7-L10) 设为 true，放宽 `CanRaze()`，使更多城市（含原始首都）可用推恩令。属于玩家自主组合，不做限制。
- 阶段 C 完成后，Dividing Grace 不再替换任何共享 UI Context，与其他 UI mod 的冲突面归零。

## 阶段 C：重构为城市 Project

### 改动目标

将推恩令从征服城市 UI 按钮重构为**城市 Project**：

```text
城市生产“推恩令”项目
→ 项目完成
→ 最终校验
→ 删除城市
→ 将人口按现有规则重新分配
```

核心目标：

- 移除对 `RazeCity` / `DisloyalCityChooser` 等共享 UI 的接管；
- 降低与其他 UI Mod 的冲突；
- 保留现有“删除城市 + 人口重新分配”的核心玩法。

### 已确认事项

- **开放范围**：所有 `city:CanRaze()` 为真的城市均可使用。
- **不额外限制首都**：完全遵循游戏自身的 `CanRaze()` 规则。
- **人口分配规则**：完全沿用当前实现。
- **项目成本**采用二次凸函数：

```text
C(k, e) = 40 + a_e * k + q_e * k * (k - 1) / 2
a_e = max(2, 10 - e)
q_e = max(1, 4 - floor(e / 2))
```

- `e = 0..8`：远古至未来时代。
- `k = 1..32`：当前使用档位。
- **32 次以后不禁止使用**，永久使用第 32 档。
- 需要生成 **9 × 32 = 288 个 Project**。
- **Project 开始生产后锁定成本**：时代变化不追溯修改；其他城市先完成推恩令导致次数增加，也不影响已经开始的项目。
- 允许多个城市同时生产同一档项目。
- 只有城市真正删除并完成分配后：`success_count += 1`。
- 项目完成必须由生产完成事件即时处理，不能依赖回合开始，以支持砍树、收获资源等即时生产力。
- 项目完成时重新读取真实状态进行最终校验。
- 如果没有合法人口接收城市：城市不删除；`success_count` 不增加；返还 `floor(0.32 * C)` 生产力。
- 失败返还模仿奇观失败机制：暂存生产力；下一次开始生产时注入；发送自定义的原生样式“生产力已回收”通知。
- 不要求保留正常 RAZE 的外交惩罚、时代得分等副作用；没有反而可以接受。
- 同回合多个城市完成项目：不保证处理顺序；每个事件独立重新校验；以实现简单为优先。
- 计划删除原有的 `RazeCity` / `DisloyalCityChooser` UI 接管代码。

### Project 数据落点（实施时确认）

- 288 个项目需写入 `Types`（`KIND_PROJECT`）与 `Projects` 表；成本列、是否需要 `PrereqTech` / `PrereqCivic`、是否受 `GameInfo.Projects` 既有列约束，实施时对照 `GameInfo.Projects` 与本地游戏数据文件核对。
- 项目命名建议：`PROJECT_DIVIDING_GRACE_E{e}_K{k}`（`e` 为 0..8，`k` 为 1..32），显示名与说明按档位生成本地化文案。
- 动态解锁：只向城市开放与当前时代、`success_count`、`city:CanRaze()` 匹配的档位；已经开始生产的旧档位不得失效。

### 待实验问题

1. **288 个 Project 的动态解锁**（最重要的 PoC）
   验证能否根据“当前时代 + `success_count` + `city:CanRaze()`”只向城市开放正确的 Project，同时已经开始生产的旧档位不会失效、存档重载后状态正确、多城市并行生产正常。
2. **失败生产力返还**
   验证 `Property 暂存 refund → 玩家选择下一生产项 → BuildQueue:AddProgress(refund)` 是否稳定，包括队列为空、同回合重新选择生产、存档重载，以及不会重复返还。
3. **城市删除方式**
   优先实验 `CityManager.DestroyCity(city)`，确认 Gameplay Script 中可正常执行、`CityRemovedFromMap` 正常触发、城市对象与区域、地块正常清理、不产生残留状态。若不可用，再考虑 Gameplay → UI bridge → `CityManager.RequestCommand(... DESTROY ...)`。
4. **同回合多项目完成的事件时序**
   观察 `DestroyCity()` 与 `CityRemovedFromMap` 是同步还是延迟触发。若删除存在延迟，增加简单的玩家级 dissolve transaction lock；若同步，则无需额外处理。

## 封面（发布时使用）

草稿阶段不创建封面。正式发布时按下表生成；提示词只约束画幅比例，不指定像素。

| 项 | 规格 |
| --- | --- |
| 画幅 | **1:1 正方形**（只约束比例，不指定像素） |
| 存放 | 原始图 `origincovers/推恩令.png`，压缩图 `covers/DividingGrace.png`（压缩沿用仓库现有封面 512×512 规格） |
| 美术风格 | **中国写实古风**，取《三国杀》牌面插画一路的写实厚涂质感；**不使用**文明 6 领袖立绘那种夸张卡通风格 |
| 标题 | **画面中直接绘制文字**：主标题「推恩令」位于中心偏上、左右居中，其下为小字号英文副标题「Dividing Grace」；字体棱角分明（汉隶 / 魏碑 / 刀刻感），不要圆润可爱，标题两端各有一条短横线衬托 |
| 意象 | 汉代帝王、竹简诏书、大城分裂为多座小城（众建诸侯而少其力） |

### 推荐提示词（中文，主用）

```text
生成一张 1:1 正方形比例的 mod 封面，用于 Steam 创意工坊展示。

【标题文字】画面中直接绘制标题文字，位置在中心偏上、左右居中：主标题为中文“推恩令”，字号最大；
主标题正下方为小字号英文副标题“Dividing Grace”。两种标题都使用棱角分明、笔画硬朗的字体
（汉隶、魏碑或刀刻感标题字），不要圆润可爱的字体；标题左右两端各有一条短横线衬托。
中文必须是“推恩令”三个字，不得出现错字、多字、漏字或镜像文字，英文不得拼错。

【主题意象】封面表现推恩令：撤销既有的诸侯城市，把人口分散给其他城市。画面为一位身着汉代黑红
冕服的帝王立于高台之上，双手展开一卷竹简诏书；台下中原大地上，一座宏伟的诸侯城池正在分裂为
若干座更小的城池，各自升起旗帜，新城之间以新修道路相连。整体传达“众建诸侯而少其力”、
以恩泽之名行削藩之实的意味。

【美术风格】中国写实古风插画，取《三国杀》牌面插画一路的写实厚涂质感：写实的人物比例与面部
刻画、厚重有笔触感的厚涂上色、精致考究的汉代冠冕与纹饰、戏剧性的强对比光影、暗沉背景配金红
高光、绢帛与古纸的颗粒质感。不要文明6那种夸张卡通、大头小身的领袖立绘风格，不要日系二次元、
不要 Q 版、不要 3D 渲染的塑料感人物，也不要照片级写实人像。

【构图配色】正方形构图、低视角仰拍，主体位于下半部，上方留出标题空间；主色为漆器黑、朱红、
青铜金与土黄，暖色逆光勾出人物轮廓，远处河谷薄雾；可加一圈汉代云纹或漆器纹样的装饰边框。

【负面要求】不要水印、签名、logo、二维码、界面元素、现代物品；不要多余文字；不要横构图或
非正方形输出。
```

### 推荐提示词（英文，备用）

```text
Generate a 1:1 square mod cover image for Steam Workshop.

TEXT (rendered inside the image): Chinese main title “推恩令” horizontally centered in the upper-middle
area as the largest element; directly below it a small English subtitle “Dividing Grace”. Use a sharp,
angular, carved typeface (Han clerical script or Wei stele style), never rounded or cute, with a short
horizontal dash flanking each side of the main title. The Chinese characters must be exactly “推恩令”,
with no wrong, extra or mirrored glyphs, and no English misspelling.

SUBJECT: the edict of pushing grace — a Han-dynasty emperor in black-and-red ceremonial robes stands on a
high terrace unrolling a bamboo-slip edict, while below him one great walled feudal city on the Central
Plains splits into several smaller walled towns, each raising its own banner, newly built roads linking them.

ART STYLE: realistic Chinese historical illustration in the vein of Sanguosha-style card art — realistic
proportions and faces, thick painterly gouache brushwork, ornate Han ceremonial dress and bronze ornament
detail, dramatic chiaroscuro, dark background with gold and vermilion highlights, silk and aged-paper grain.
NOT Civilization VI's exaggerated cartoon leader portraits, no anime, no chibi, no glossy 3D-render look,
no photographic portrait.

COMPOSITION: square, dramatic low angle, main subject in the lower half, clear space above for the title;
palette of lacquer black, vermilion red, bronze gold and earth yellow, warm rim light, river-valley haze,
optional decorative border of Han cloud or lacquer motifs.

NEGATIVE: no watermark, signature, logo, QR code, UI elements or modern objects, no extra text, and no
landscape or non-square framing.
```

### 与既有封面的关系

- 写实古风是有意的风格选择：现有 [covers/PeoplesWar.png](covers/PeoplesWar.png) 与 [covers/RazeOriginalCapital.png](covers/RazeOriginalCapital.png) 走文明 6 宣传画路线，新封面在人物写实度上更进一步，但保留方形构图、暖色厚涂、标题居上这三条共同语言。
- 与“人民战争”封面构成同一主题的两种视角：一个从“人民群像”看帝国，一个从“帝王与诏书”看帝国。
- 画面母题“大城分裂为小城”直接把推恩令机制可视化，与“夷平原始首都”的焚城封面形成一建一毁的对照。

## 实施顺序

1. 阶段 A 草稿留存，随 People's War 的交付一并提交。
2. 后续在草稿上继续开发：阶段 B 补 `.modinfo` 与命名空间改名，使推恩令成为可独立加载的 mod（不要求合并到 `main`）。
3. 阶段 C 先完成“288 Project 动态解锁” PoC，再依次解决失败生产力返还、城市删除方式、同回合时序。

## 验证

- 阶段 A：草稿逐字来自 People's War 现有实现，仅作目录搬迁，可对照 diff 确认无逻辑改动。
- 阶段 B：`.modinfo` XML 可解析；两个 `ReplaceUIScript` 的 `LoadOrder 100721` 生效（本 Mod 界面不被风云变幻的同名替换覆盖）。
- 征服城市与忠诚归附城市两条入口都能弹出推恩令按钮，按钮禁用原因正确。
- 人口分配：整除与余数分配、目标城市失效、无合法接收城市、事务过期清理。
- 存档重载后 pending 状态与事务状态正确。
- 阶段 C 完成后，确认 People's War 与 Dividing Grace 都不再替换共享 UI Context。
- `git diff --check` 无空白问题；发布时 README 中英两版同步。
