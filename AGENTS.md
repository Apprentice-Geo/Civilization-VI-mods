# AGENTS.md

## 仓库结构

- 每个 Civilization VI mod 独立放在自己的目录中，通常包含一个 `.modinfo` 文件，以及对应的 `.sql` 或 `.lua` 实现文件。
- `covers/` 只存放 README 和发布页面使用的封面图。
- `README.md` 和 `README.en.md` 是面向用户的总览文档，发布 mod 前需要同步新 mod 行为到两个 `README` 文档中。

## modinfo 字段说明

`.modinfo` 是 XML 格式的 mod 入口声明。常见根节点和元数据字段如下：

| 字段 | 常见取值 | 说明 |
| --- | --- | --- |
| `<Mod id="..." version="...">` | `id` 通常为 UUID；`version` 为整数或小数 | `id` 必须在不同 mod 间保持唯一；行为更新时递增 `version`。 |
| `<Name>` | 文本或本地化键 | mod 名称。 |
| `<Description>` | 文本或本地化键 | 完整功能说明。 |
| `<Teaser>` | 文本或本地化键 | 在附加内容界面显示的简短摘要。 |
| `<Authors>` | 文本 | 作者名称。 |
| `<Created>` | Unix 时间戳（秒） | mod 的创建时间。 |
| `<AffectsSavedGames>` | `0`：不标记为存档依赖；`1`：标记为存档依赖 | 表示存档是否需要记录并依赖该 mod；设为 `0` 不代表运行中的存档一定可以安全增删该 mod。 |
| `<CompatibleVersions>` | `1.2`、`2.0` 或 `1.2,2.0` | 声明兼容的 Civ VI mod 系统版本；`1.2` 常用于较早版本，`2.0` 用于风云变幻更新后的版本。该字段不用于限制规则集。 |
| `<EnabledByDefault>` | `0`：默认禁用；`1`：默认启用 | mod 首次被发现时的默认启用状态。 |
| `<SupportsSinglePlayer>` | `0`：不支持；`1`：支持 | 是否支持单人游戏。 |
| `<SupportsMultiplayer>` | `0`：不支持；`1`：支持 | 是否支持多人游戏。 |
| `<SupportsHotSeat>` | `0`：不支持；`1`：支持 | 是否支持热座模式。 |

常见顶层结构如下：

| 结构 | 说明 |
| --- | --- |
| `<Files>` | 列出随 mod 打包的全部文件；仅列在这里不会使文件自动加载。 |
| `<InGameActions>` | 声明进入游戏后执行的 gameplay、文本和 UI 动作。 |
| `<FrontEndActions>` | 声明在主菜单和游戏设置等前端环境执行的动作。 |
| `<ActionCriteria>` | 定义动作的执行条件；动作通过 `criteria` 属性引用 `<Criteria id="...">`。 |
| `<Dependencies>` | 声明必须存在并启用的其他 mod，同时使当前 mod 的同加载顺序动作排在依赖项之后。 |
| `<References>` | 当被引用 mod 同时启用时建立加载顺序，但不强制其存在或启用。 |

`ActionCriteria` 中常用的条件字段如下：

| 字段 | 常见取值 | 说明 |
| --- | --- | --- |
| `<RuleSetInUse>` | `RULESET_STANDARD`、`RULESET_EXPANSION_1`、`RULESET_EXPANSION_2` | 分别表示标准规则、迭起兴衰和风云变幻；多个允许值使用逗号分隔。 |
| `<ModInUse>` | mod 的 `id` | 仅在指定 mod 已启用时满足条件。 |

`InGameActions` 和 `FrontEndActions` 中常见的动作如下：

| 动作 | 说明 |
| --- | --- |
| `<UpdateDatabase>` | 将 SQL 或 XML 文件应用到当前环境的数据库。 |
| `<UpdateText>` | 将本地化 SQL 或 XML 文件应用到文本数据库。 |
| `<AddGameplayScripts>` | 在 gameplay Lua 环境加载脚本。 |
| `<AddUserInterfaces>` | 注册新的 UI Context，通常需要在动作属性中指定 `<Context>`。 |
| `<ReplaceUIScript>` | 使用 `<LuaContext>` 指定目标 UI Context，并通过 `<LuaReplace>` 指定替换脚本。 |
| `<ImportFiles>` | 导入 Lua 或 UI 运行时需要直接访问的文件。 |
| `<UpdateIcons>`、`<UpdateColors>`、`<UpdateArt>` | 分别加载图标、颜色和美术资源数据。 |

- 每个动作的 `id` 应在 mod 内唯一；`criteria` 必须引用已定义的条件。
- `<File>` 使用相对于 mod 根目录的路径。需要发布的文件必须列入 `<Files>`，并放入负责加载它的动作中。
- 动作的 `<Properties><LoadOrder>` 默认为 `0`。仅在确有覆盖或依赖顺序时设置；数值越大越晚执行，优先使用依赖或引用表达跨 mod 顺序。
- 规则集限制使用 `ActionCriteria` / `RuleSetInUse`，不要用 `CompatibleVersions` 代替。

## 修改原则

- 修改某个 mod 时，默认只触碰该 mod 目录下的文件。
- 行为变化必须同步检查 `.modinfo` 中的 `version`、`Description` 和 `Teaser`，确保用户看到的说明与实际行为一致。
- 中英文说明应表达同一行为；不要只改一种语言，也不要让两种语言出现范围、触发时机或限制条件差异。
- 保持现有文件风格和最小改动范围，不做无关格式化、重排或重构。
- 不要回滚或覆盖工作区中与当前任务无关的已有修改。

## Civilization VI Mod 开发注意事项

- `.modinfo` 是 mod 的入口声明。数据库类改动通常通过 SQL 参与游戏数据库更新；Lua gameplay 脚本通常通过 `InGameActions` / `AddGameplayScripts` 加载。
- 区分 gameplay Lua 和 UI Lua。需要修改游戏状态时，优先使用 gameplay 脚本环境和 gameplay 事件。
- 事件回调可能在每回合、加载存档、多人局或多个玩家上下文中触发。一次性效果应使用玩家属性或游戏属性做幂等保护。
- 涉及玩家效果时，显式判断适用对象，例如人类玩家、AI、主要文明、城邦和蛮族，避免误影响非目标玩家。
- 涉及时机条件时，明确处理回合开始、建城、单位创建、战斗、研究完成等事件差异，不要只依赖函数名猜测触发语义。
- 涉及时代、科技、市政、政策、单位、能力、修正器等类型时，优先通过 `GameInfo` 查询，并处理条目不存在的情况。
- SQL 修改应尽量使用明确的类型名和条件，避免影响全局表中过宽的记录范围。
- Lua 日志应简短说明关键分支或最终效果，便于在游戏日志中定位问题。

## 验证建议

- `.modinfo` 修改后，至少确认 XML 可解析。
- 行为或文案修改后，用搜索确认旧触发词、旧描述或旧类型名没有残留在目标 mod 中。
- 提交前运行 `git diff --check` 检查空白和换行问题。
- Civilization VI mod 的运行效果通常需要游戏内人工验收；静态检查不能替代实际开局、存档加载和目标场景测试。

## 参考资料

以下是 mod 开发过程中可以参考的资料，但是不保证单个资料的信息正确，尽量多方面比对确认信息。

- Civilization VI Modding Knowledge Base: https://sukritact.github.io/Civilization-VI-Modding-Knowledge-Base/
- Civ VI 原版数据文件 GitHub 镜像: https://github.com/mrobaczyk/civ6, https://github.com/Swiftwork/civ6-explorer
- CivFanatics Forums / Resources: https://forums.civfanatics.com/
- Civ6ModdingNotes / Civilization VI Lua 手册: https://github.com/Hemmelfort/Civ6ModdingNotes
- Civilization VI Wiki : https://civilization.fandom.com/wiki/Civilization_VI
- 本地游戏资源目录，禁止修改，相对于 steam 的路径一般为 `steam\steamapps\common\Sid Meier's Civilization VI`
- 本地游戏运行信息，其中包含 log，路径一般为 `%USERNAME%\AppData\Local\Firaxis Games\Sid Meier's Civilization VI`

## 提交信息

需要写 commit message 时使用 [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)，例如：

```text
docs: update project agent instructions
```
