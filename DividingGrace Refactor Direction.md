# Dividing Grace（推恩令）开发计划

## 背景

“推恩令”最初以“解放”为名内嵌在 People's War 中：占领或因忠诚度归附的城市可在征服弹窗中选择该动作，效果是撤销城市建制，并把全部人口重新分配给其他已确定保留的城市。该机制与 People's War 的人口增强主题无关，且接管了原版 `RazeCity`、`DisloyalCityChooser` 两个共享 UI Context，因此拆分为独立 mod。

人民战争 5.0 已把推恩令拆出，旧实现随该版本合入 `main`，见 [草稿说明](DividingGrace/DRAFT.md)。推恩令后续直接从阶段 C 的城市生产项目继续设计，具体规则仍待讨论。

## 开发状态

| 项 | 要求 |
| --- | --- |
| 当前状态 | `DividingGrace/` 保留历史草稿，缺少 `.modinfo`，尚未发布 |
| 后续入口 | 城市生产队列中的「推恩令」项目 |
| 发布资料 | 正式发布时补齐中英文 README 与封面 |

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 阶段 A | 从 People's War 摘出旧实现并留存 | 已完成 |
| 阶段 B | 将弹窗版做成独立 Mod | 已取消 |
| 阶段 C | 将推恩令设计为城市生产项目 | 设计讨论中 |

## 命名

| 项 | 取值 |
| --- | --- |
| 中文名 | 推恩令 |
| 英文名 | Dividing Grace |
| 目录 | `DividingGrace` |
| 属性 / 事件前缀 | `DIVIDING_GRACE_` / `DividingGrace_` |
| 本地化前缀 | `LOC_DIVIDING_GRACE_` |

## 与其他 mod 的关系

- People's War 与 Dividing Grace 互相独立、可单独启用；“征服城市人口不会损失”留在 People's War。
- 只启用 Dividing Grace 时，被征服城市的人口已按原版规则损失，可再分配的人口更少。README 与 modinfo 应建议与 People's War 同时启用。
- 与 [RazeOriginalCapital](RazeOriginalCapital/RazeOriginalCapital.modinfo) 的交互：它把 [`COMBAT_RAZE_ANY_CITY`](RazeOriginalCapital/RazeOriginalCapital.sql#L7-L10) 设为 true，放宽 `CanRaze()`，使更多城市（含原始首都）可用推恩令。属于玩家自主组合，不做限制。

## 阶段 C：重构为城市 Project

### 改动目标

通过城市生产队列启动推恩令，保留原版 `RazeCity` / `DisloyalCityChooser` 界面。

```text
城市生产“推恩令”项目
→ 项目完成
→ 最终校验
→ 删除城市
→ 将人口按现有规则重新分配
```

### 玩法草案（待讨论）

- **开放范围**：所有 `city:CanRaze()` 为真的城市均可使用。
- **不额外限制首都**：完全遵循游戏自身的 `CanRaze()` 规则。
- **人口分配规则**：均分给同一玩家名下其他合格城市，余数依人口升序逐城分配，同人口按地块编号排序。
- **项目成本**：首版使用一个项目，`Cost = 100`、`CostProgressionModel = COST_PROGRESSION_GAME_PROGRESS`、`CostProgressionParam1 = 200`。成本随原版科技、市政进度增长，标准速度下为 100–200 生产力，并由引擎按游戏速度缩放。
- 项目通过完工事件即时处理，以支持砍树、收获资源等即时生产力。每次完工都重新检查城市资格和接收城市。
- **失败返还**：完工时若没有合法接收城市，保留原城和人口，返还本次实际完工成本的 50%，向下取整。返还量暂存在原城，等该城下一项生产开始后发放一次，并发送「生产力已回收」通知。
- 不要求保留正常 RAZE 的外交惩罚、时代得分等副作用；没有反而可以接受。
- 同回合多个城市完成项目：不保证处理顺序；每个事件独立重新校验；以实现简单为优先。

### 首版验证

1. 向 `Types`（`KIND_PROJECT`）和 `Projects` 写入一个 `PROJECT_DIVIDING_GRACE`，通过原版生产队列验证能开工。检查 `city:CanRaze()` 在自建城市、选择保留的征服城市和首都上的行为。
2. 用 `Events.CityProjectCompleted` 接收完工并重新校验。分别通过正常生产与砍树完工，确认没有合格接收城市时原城与人口保留。
3. 用 `CityManager.DestroyCity(city)` 验证撤城。检查城市、区域和地块的清理，观察 `CityRemovedFromMap` 的触发时序，确认人口只在撤城成功后分配一次。
4. 验证人口整除、余数分配、接收城市易主、同回合多城完工和在建项目存档重载。
5. 核对完工时的实际成本与返还量。验证用 `BuildQueue:AddProgress` 将暂存生产力发放给下一项生产，覆盖空队列、同回合切换和读档后只发一次，并确认通知正常显示。

### 后续定价

原方案为远古至未来共 9 个时代，每个时代按成功次数设 32 个成本档，合计 `9 × 32 = 288` 个项目。根据首版试玩结果，再决定是否需要分段定价、成功计数和在建项目锁价。

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

1. 将项目版做成独立 Mod，使用新的 UUID 和 `DIVIDING_GRACE_*` 命名空间。入口声明限定「风云变幻」，加载项目数据、本地化和 gameplay 脚本。
2. 先跑通单个项目从开工、完工校验、撤城到人口分配的过程，再验证失败返还。两条路径均纳入首版交付。
3. 根据试玩结果决定是否需要分段定价。

## 验证

- `.modinfo` XML 可解析，项目从生产队列进入，原版征服与归附界面正常打开。
- 验证成本随研发进度和游戏速度变化、即时生产力完成项目，以及存档重载后的在建状态。
- 验证城市撤销、人口分配与失败返还，场景见「首版验证」。
- `git diff --check` 无空白问题；发布时 README 中英两版同步。
