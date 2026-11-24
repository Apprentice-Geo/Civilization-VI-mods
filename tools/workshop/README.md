# 文明 VI 创意工坊发布工具

从仓库根目录运行以下命令。需要 Rust 1.89 或更新版本。`list`、`import`、`status` 和 `publish` 使用已登录的 Steam 客户端，需要当前账号拥有《文明 VI 开发工具》的许可。覆盖更新时，当前账号必须是条目所有者。

```powershell
cargo run --locked --manifest-path tools/workshop/Cargo.toml -- list --limit 20
cargo run --locked --manifest-path tools/workshop/Cargo.toml -- import BarbarianWard 3674527197
cargo run --locked --manifest-path tools/workshop/Cargo.toml -- plan BarbarianWard
cargo run --locked --manifest-path tools/workshop/Cargo.toml -- status BarbarianWard
cargo run --locked --manifest-path tools/workshop/Cargo.toml -- publish BarbarianWard --note "更新说明"
```

- `list` 只读列出当前账号的《文明 VI》工坊条目，按创建时间从新到旧排序，默认最多 20 条。输出包含工坊 ID、创建时间（UTC）、标题、可见性、文件字节数、`ModId` 和所有权。Steam 也可能返回协作条目，以 `owned_by_current_account` 判断当前账号能否用本工具覆盖更新。
- `import` 读取条目的完整中英文文案、可见性、分类和依赖，创建 `workshop.json`。输出包含线上封面 URL。仓库中有 `covers/<目录名>.png` 时会引用它，否则请补填 `cover`。Steam 为两种语言返回相同文案时，请核对是否发生了语言回退。
- `plan` 离线校验发布配置并列出将要上传的文件与工坊字段。打包保留 `.modinfo` 和顶层 `<Files>` 清单中各文件的相对路径。
- `status` 读取绑定条目的当前配置、封面 URL 和 `.modinfo` 的 `ModId`、`ModVersion` 标签。
- `publish` 提交英文文案、内容、封面、可见性、标签和可选更新说明，随后提交简体中文文案并同步依赖。首次分配的工坊 ID 会立即写入配置。

## 发布配置

将 `workshop.json` 放在 mod 目录中。首次发布时可参考以下 `BarbarianWard` 配置。已有条目先用 `import` 绑定。中英文标题和完整描述沿用 `.modinfo` 中对应语言的 `Name` 和 `Description` 表述。根据 mod 的实际类型、分类和依赖调整其余字段。

```json
{
  "workshop_id": null,
  "cover": "../covers/BarbarianWard.png",
  "visibility": "private",
  "type": "Mod",
  "tags": ["Gameplay", "Base Game"],
  "english": {
    "title": "Barbarian Ward",
    "description": "Human combat units gain a 99 advantage when combating barbarian units."
  },
  "schinese": {
    "title": "蛮族退散",
    "description": "人类战斗单位与蛮族单位战斗时获得99战斗力增益。"
  },
  "required_items": [],
  "required_dlc": []
}
```

`cover` 的相对路径以 mod 目录为起点。`visibility` 支持 `public`、`friends_only`、`private` 和 `unlisted`。`type` 支持 `Mod` 和 `Map`，省略时为 `Mod`。`tags` 填 `UI`、`Gameplay` 等分类标签，发布时会与 `type` 合并提交。填写必需物品的工坊 ID 和所需 DLC 的 Steam App ID，例如风云变幻的 `947510`。依赖数组表示完整目标清单，`[]` 会清空线上对应依赖。

仓库已有条目、常见 DLC 和工坊物品的数字 ID 见 [Steam ID 速查](IDS.md)。

## 失败后核对

成功结果以 JSON 写到标准输出，上传阶段、字节进度和错误写到标准错误。提交失败或超时后，已取得工坊 ID 时，先用 `status` 核对线上状态，再按目标配置重提。如果更新说明已发布，重提时省略 `--note`。

首次创建超时且尚未取得 ID 时，运行 `list`，把 `created_at` 与 mod 目录下 `.workshop.lock` 记录的请求时间（UTC）比较。较早版本留下的锁只记录待确认状态，可用原命令的运行时间比对。优先检查 `owned_by_current_account` 为 `true` 且创建时间接近的条目。Steam 可能返回标题为空、文件字节数为零的条目，因为标题和文件是在创建之后上传的。确认候选后将 ID 填入 `workshop_id`，再运行 `status` 核对。没有结果或有多个无法区分的候选时，保留锁和「结果未知」状态。另有证据确认 Steam 没有创建条目时，可以删除 `.workshop.lock` 后重新创建。

```powershell
cargo test --locked --manifest-path tools/workshop/Cargo.toml
```
