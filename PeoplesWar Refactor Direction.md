## 改动目标

将 People's War 的“解放”从征服城市 UI 按钮重构为**城市 Project**：

```text
城市生产“解放”项目
→ 项目完成
→ 最终校验
→ 删除城市
→ 将人口按现有规则重新分配
```

核心目标是：

- 移除对 `RazeCity` / `DisloyalCityChooser` 等共享 UI 的接管；
- 降低与其他 UI Mod 的冲突；
- 保留现有“删除城市 + 人口重新分配”的核心玩法。

------

## 已确认事项

- **开放范围**：所有 `city:CanRaze()` 为真的城市均可使用。
- **不额外限制首都**：完全遵循游戏自身的 `CanRaze()` 规则。
- **人口分配规则**：完全沿用当前 People's War 实现。
- **项目成本**采用二次凸函数：

$C(k,e)=40+a_e k+q_e\frac{k(k-1)}2$

其中：

$a_e=\max(2,10-e)$$q_e=\max(1,4-\lfloor e/2\rfloor)$

- $e=0\sim8$：远古至未来时代。

- $k=1\sim32$：当前使用档位。

- **32 次以后不禁止使用**，永久使用第 32 档。

- 需要生成 **9 × 32 = 288 个 Project**。

- **Project 开始生产后锁定成本**：

  - 时代变化不追溯修改；
  - 其他城市先完成解放导致次数增加，也不影响已经开始的项目。

- 允许多个城市同时生产同一档项目。

- 只有城市真正删除并完成分配后：

  ```text
  success_count += 1
  ```

- 项目完成必须由生产完成事件即时处理，不能依赖回合开始，以支持砍树、收获资源等即时生产力。

- 项目完成时重新读取真实状态进行最终校验。

- 如果没有合法人口接收城市：

  - 城市不删除；

  - `success_count` 不增加；

  - 返还：

    ⌊0.32C⌋\lfloor0.32C\rfloor

    生产力。

- 失败返还模仿奇观失败机制：

  - 暂存生产力；
  - 下一次开始生产时注入；
  - 发送自定义的原生样式“生产力已回收”通知。

- 不要求保留正常 RAZE 的外交惩罚、时代得分等副作用；没有反而可以接受。

- 同回合多个城市完成项目：

  - 不保证处理顺序；
  - 每个事件独立重新校验；
  - 以实现简单为优先。

- 计划删除原有 `RazeCity` / `DisloyalCityChooser` UI 接管代码。

## 待实验问题

### 1. 288 个 Project 的动态解锁

验证能否根据：

```text
当前时代
+ success_count
+ city:CanRaze()
```

只向城市开放正确的 Project，同时：

- 已经开始生产的旧档位不会失效；
- 存档重载后状态正确；
- 多城市并行生产正常。

这是目前最重要的 PoC。

### 2. 失败生产力返还

验证：

```text
Property 暂存 refund
→ 玩家选择下一生产项
→ BuildQueue:AddProgress(refund)
```

是否稳定，包括：

- 队列为空；
- 同回合重新选择生产；
- 存档重载；
- 不会重复返还。

### 3. 城市删除方式

优先实验：

```lua
CityManager.DestroyCity(city)
```

确认：

- Gameplay Script 中可正常执行；
- `CityRemovedFromMap` 正常触发；
- 城市对象、区域、地块等正常清理；
- 不产生残留状态。

若不可用，再考虑隐藏 UI bridge：

```text
Gameplay
→ UI bridge
→ CityManager.RequestCommand(...DESTROY...)
```

### 4. 同回合多项目完成的事件时序

观察 `DestroyCity()` 与 `CityRemovedFromMap` 是同步还是延迟触发。

如果删除存在延迟，增加简单的**玩家级 dissolve transaction lock**；如果同步，则无需额外处理。