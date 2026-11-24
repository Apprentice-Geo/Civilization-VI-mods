# Steam ID 速查

导入已有条目时，把下表的工坊 ID 传给 `import <mod目录> <工坊ID>`。填写 `required_dlc` 时使用 DLC 的 Steam App ID，填写 `required_items` 时使用必需条目的工坊 ID。游戏本体 App ID 是 `289070`，文明 VI 开发工具 App ID 是 `404350`。`.modinfo` 的 `ModId` 是游戏内使用的 UUID。

## 仓库已有 mod

条目通过 Steam 返回的 `ModId` 与仓库 `.modinfo` 的 UUID 一一匹配。需要更新协作条目时，请使用它的所有者账号。

| Mod 目录 | 工坊 ID | 备注 |
| --- | --- | --- |
| `AdditionalPolicySlots` | [3676464950](https://steamcommunity.com/sharedfiles/filedetails/?id=3676464950) | |
| `BarbarianWard` | [3674527197](https://steamcommunity.com/sharedfiles/filedetails/?id=3674527197) | |
| `BetterRockBandLens` | [3783818017](https://steamcommunity.com/sharedfiles/filedetails/?id=3783818017) | 协作条目，所需 DLC 为风云变幻 `947510` |
| `DividingGrace` | [3843561777](https://steamcommunity.com/sharedfiles/filedetails/?id=3843561777) | |
| `GreatSynthesizer` | [3783934479](https://steamcommunity.com/sharedfiles/filedetails/?id=3783934479) | |
| `HegemonyVictory` | [3844238879](https://steamcommunity.com/sharedfiles/filedetails/?id=3844238879) | |
| `MovementEnhance` | [3673428378](https://steamcommunity.com/sharedfiles/filedetails/?id=3673428378) | |
| `OpeningTechsAndCivicCompletion` | [3756080001](https://steamcommunity.com/sharedfiles/filedetails/?id=3756080001) | |
| `PeoplesWar` | [3765144430](https://steamcommunity.com/sharedfiles/filedetails/?id=3765144430) | |
| `PopulationYields` | [3777420523](https://steamcommunity.com/sharedfiles/filedetails/?id=3777420523) | |
| `RazeOriginalCapital` | [3656066003](https://steamcommunity.com/sharedfiles/filedetails/?id=3656066003) | |
| `SightEnhance` | [3679334483](https://steamcommunity.com/sharedfiles/filedetails/?id=3679334483) | |

## 常见 DLC

根据 mod 实际使用的规则集、文明或游戏模式选填 DLC。需要新纪元季票中的某个游戏模式时，可以填写对应内容包的 App ID。

| DLC | Steam App ID | 游戏模式 |
| --- | --- | --- |
| 迭起兴衰（Rise and Fall） | [645402](https://store.steampowered.com/app/645402/) | |
| 风云变幻（Gathering Storm） | [947510](https://store.steampowered.com/app/947510/) | |
| 新纪元季票（New Frontier Pass） | [1308090](https://store.steampowered.com/app/1308090/) | |
| 领袖季票（Leader Pass） | [2158250](https://store.steampowered.com/app/2158250/) | |
| 玛雅与大哥伦比亚包 | [1253990](https://store.steampowered.com/app/1253990/) | 天启模式 |
| 埃塞俄比亚包 | [1270540](https://store.steampowered.com/app/1270540/) | 秘密结社模式 |
| 拜占庭与高卢包 | [1284470](https://store.steampowered.com/app/1284470/) | 时代剧变模式 |
| 巴比伦包 | [1388850](https://store.steampowered.com/app/1388850/) | 英雄与传奇模式 |
| 越南与忽必烈包 | [1436950](https://store.steampowered.com/app/1436950/) | 垄断与公司模式 |
| 葡萄牙包 | [1478300](https://store.steampowered.com/app/1478300/) | 丧尸围城模式 |

## 常见工坊物品

只有 mod 实际需要这些物品时才填入 `required_items`。仅做兼容适配时，依赖列表按 mod 自身的安装要求填写。

| 物品 | 工坊 ID |
| --- | --- |
| CQUI - Community Quick User Interface | [2115302648](https://steamcommunity.com/sharedfiles/filedetails/?id=2115302648) |
| Sukritact's Simple UI Adjustments | [939149009](https://steamcommunity.com/sharedfiles/filedetails/?id=939149009) |
| Better Report Screen (UI) | [1312585482](https://steamcommunity.com/sharedfiles/filedetails/?id=1312585482) |
| More Lenses | [871712879](https://steamcommunity.com/sharedfiles/filedetails/?id=871712879) |
