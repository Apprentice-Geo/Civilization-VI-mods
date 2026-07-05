# 仓库协作规则

## 仓库结构

- 每个 Civilization VI mod 独立放在自己的目录中，通常包含一个 `.modinfo` 文件，以及对应的 `.sql` 或 `.lua` 实现文件。
- `covers/` 只存放 README 和发布页面使用的封面图。
- `README.md` 和 `README.en.md` 是面向用户的总览文档；修改 mod 后需要同步新 mod 行为到两个 `README` 文档中。

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

- Civilization VI Modding Knowledge Base: https://sukritact.github.io/Civilization-VI-Modding-Knowledge-Base/
