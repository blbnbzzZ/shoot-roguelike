# 子弹反射系统 - 完整游戏设计文档 (GDD)
## Game Designer: GameDesigner | 项目: Roguelike Shooter (元气骑士类)

---

## 📋 文档信息

**系统名称**: 子弹反射系统（Bullet Reflection System）  
**版本**: v0.1 (2026-06-08)  
**状态**: 设计阶段（待Playtest验证）  
**目标平台**: PC (Steam/itch.io) + 移动端（后期）  

---

## 🎯 设计支柱（Design Pillars）

**核心体验目标**（所有设计决策必须服务这些支柱）：

1. **主动性**（Proactivity） - 玩家主动应对子弹，而非被动躲避
2. **高风险高回报**（High Risk, High Reward） - 反射有风险，但成功极其满足
3. **技能成长感**（Skill Mastery） - 玩家能感受到自己技术进步
4. **爽快感**（Satisfaction） - 反射成功必须产生强烈的视听反馈
5. **易学难精**（Easy to Learn, Hard to Master） - 新手能偶然触发，高手能精准控制

---

## 🎮 核心玩法循环（Core Gameplay Loop）

### Moment-to-Moment Loop (0-30秒)
```
玩家看到子弹 → 判断时机 → 按下闪避键 → 
成功：子弹反射 + 暴击伤害 + "完美！"提示 → 多巴胺分泌
失败：受伤 + 挫败感 → 想再来一次
```

**详细流程**：
1. **子弹接近** - 玩家感知威胁
2. **决策窗口** - 玩家决定是否反射（基于子弹类型、自身血量、动量等）
3. **时机判断** - 子弹进入"反射窗口"时，闪避键变为"反射"
4. **执行** - 按下闪避键
5. **反馈** - 成功/失败都有强烈反馈

### Session Loop (5-30分钟)
```
进入房间 → 清除敌人 → 收集奖励 → 决定是否赌博（运气系统） → 
进入下一房间 → 遇到精英怪/Boss → 反射成为关键战术 → 
通关/死亡 → 永久进度提升 → "再玩一局"
```

### Long-Term Loop (小时-周)
```
解锁新角色/武器 → 挑战更高难度 → 完成成就 → 
登上排行榜 → 获取赛季奖励 → 等待新内容更新
```

---

## ⚡ 机制详细规格

### Mechanic 1: 子弹反射（Bullet Reflection）

```markdown
## Mechanic: 子弹反射

**Purpose**: 
- 让玩家从"被动躲避"变为"主动应对"
- 创造高风险高回报的决策空间
- 提供技能上限（高手能反射更多子弹）

**Player Fantasy**: 
- "我是弹幕大师，能在子弹雨中跳舞"
- "我的反应速度超越常人"

**Input**: 
- 按下闪避键（空格/Space）时，如果子弹在"反射窗口"内，触发反射
- 完美窗口：0.1秒（子弹距玩家20-30单位）
- 好窗口：0.2秒（子弹距玩家30-50单位）
- 失败窗口：>0.2秒（子弹已过反射点）

**Output**: 
- 成功（完美）：子弹反射 + 3倍伤害 + "完美！"浮动文字 + 慢镜头0.1秒
- 成功（好）：子弹反射 + 1.5倍伤害 + "好！"浮动文字
- 失败：玩家受到伤害 + 屏幕红色闪烁 + 挫败感

**Success Condition**: 
- 玩家能清晰感知反射窗口（视觉提示）
- 反射成功率达30-50%（新手）→ 60-80%（老手）
- 玩家感到"只要我反应够快，就能反射所有子弹"

**Failure State**: 
- 反射窗口太宽松（玩家无风险感）
- 反射窗口太严格（玩家感到挫败）
- 反射无反馈（玩家不知道是否成功）

**Edge Cases**:
  - 多颗子弹同时接近：每次按键只反射最近的一颗
  - 反射键与闪避键冲突：反射优先级更高（子弹在窗口内时）
  - 无敌时间内反射：允许，但不触发"完美"（避免滥用）
  - Boss攻击模式切换时：某些攻击不可反射（红色发光提示）

**Tuning Levers**: 
  - 完美窗口大小（Base: 0.1s, [PLACEHOLDER]）
  - 好窗口大小（Base: 0.2s, [PLACEHOLDER]）
  - 反射伤害倍率（完美3x, 好1.5x, [PLACEHOLDER]）
  - 反射冷却时间（Base: 0.5s, [PLACEHOLDER]）
  
**Dependencies**: 
  - 敌人子弹系统（标记哪些可反射）
  - 玩家输入系统（闪避键双重功能）
  - UI反馈系统（浮动文字、慢镜头、屏幕特效）
  - 音效系统（反射成功/失败音效）
```

---

### Mechanic 2: 反射窗口视觉提示（Reflection Window Visuals）

**目的**: 让玩家清晰感知反射时机，避免"我不知道什么时候按"

**实现方式**：
1. **子弹变色** - 可反射子弹接近时，从白色→黄色→金色（完美窗口）
2. **光圈提示** - 玩家周围显示光圈，子弹进入时光圈发光
3. **慢镜头预提示** - 子弹进入完美窗口前0.05秒，时间流速略微降低（0.9x）

**视觉层级**：
```
子弹距玩家 > 50单位：白色子弹，无提示
子弹距玩家 30-50单位：黄色子弹，"好窗口"（1.5x伤害）
子弹距玩家 20-30单位：金色子弹，"完美窗口"（3x伤害）
子弹距玩家 < 20单位：红色子弹，不可反射（会受伤）
```

**Tuning Levers**:
- 变色开始距离（Base: 50单位, [PLACEHOLDER]）
- 完美窗口距离（Base: 20-30单位, [PLACEHOLDER]）
- 光圈大小（Base: 半径60单位, [PLACEHOLDER]）

---

### Mechanic 3: 反射进度系统（Reflection Progress）

**目的**: 让玩家感受到进步，提供长期动力

**实现方式**：
1. **反射计数器** - 每局游戏统计反射次数、完美反射次数
2. **反射评级** - 每局结束后评级（S/A/B/C）
3. **永久进度** - 总反射次数解锁奖励（新角色、新皮肤、新武器）

**评级标准**：
```
S级：完美反射率 > 60%，总反射 > 30次
A级：完美反射率 > 40%，总反射 > 20次
B级：完美反射率 > 20%，总反射 > 10次
C级：完美反射率 < 20%，总反射 < 10次
```

**永久进度奖励**：
```
总反射100次 → 解锁新角色"反射大师"
总反射500次 → 解锁新武器"反射护盾"
总反射1000次 → 解锁成就"弹幕之王"
```

---

### Mechanic 4: Boss反射阶段（Boss Reflection Phase）

**目的**: 让Boss战成为反射系统的高潮时刻

**实现方式**：
1. **Boss血量50%时**，进入"反射阶段"
2. **Boss发射大量可反射子弹**（屏幕被子弹填满）
3. **玩家必须反射子弹**才能对Boss造成伤害
4. **反射阶段持续10秒**，之后Boss进入虚弱状态

**Boss反射阶段设计**：
```
阶段1（100-70% HP）：普通攻击，偶尔可反射
阶段2（70-50% HP）：攻击频率增加，50%子弹可反射
阶段3（50-30% HP）：反射阶段！所有子弹可反射，Boss受伤x2
阶段4（30-0% HP）：Boss狂暴，攻击速度x2，但反射窗口+50%
```

**Tuning Levers**:
- 反射阶段持续时间（Base: 10s, [PLACEHOLDER]）
- 反射阶段Boss受伤倍率（Base: 2x, [PLACEHOLDER]）
- 反射窗口加成（Base: +50%, [PLACEHOLDER]）

---

## 📊 平衡参数表（Balance Parameters）

### 反射系统核心参数

| 参数 | 基础值 | 最小值 | 最大值 | 调整说明 | 状态 |
|------|--------|--------|--------|----------|------|
| 完美窗口大小 | 0.1秒 | 0.05秒 | 0.2秒 | [PLACEHOLDER] - 需要Playtest | 🔧 |
| 好窗口大小 | 0.2秒 | 0.1秒 | 0.3秒 | [PLACEHOLDER] - 需要Playtest | 🔧 |
| 完美反射伤害倍率 | 3x | 2x | 5x | [PLACEHOLDER] - 测试Boss战平衡 | 🔧 |
| 好反射伤害倍率 | 1.5x | 1.2x | 2x | [PLACEHOLDER] - 测试普通房间平衡 | 🔧 |
| 反射冷却时间 | 0.5秒 | 0.2秒 | 1.0秒 | [PLACEHOLDER] - 防止反射滥用 | 🔧 |
| 反射窗口开始距离 | 50单位 | 30单位 | 80单位 | [PLACEHOLDER] - 基于玩家角色大小 | 🔧 |

### 进度系统参数

| 参数 | 基础值 | 最小值 | 最大值 | 调整说明 | 状态 |
|------|--------|--------|--------|----------|------|
| S级完美反射率要求 | 60% | 40% | 80% | [PLACEHOLDER] - 基于玩家技能分布 | 🔧 |
| S级总反射次数要求 | 30次 | 20次 | 50次 | [PLACEHOLDER] - 基于房间大小 | 🔧 |
| 解锁"反射大师"所需总反射 | 100次 | 50次 | 200次 | [PLACEHOLDER] - 测试留存率 | 🔧 |
| Boss反射阶段持续时间 | 10秒 | 5秒 | 15秒 | [PLACEHOLDER] - 测试Boss战节奏 | 🔧 |

---

## 🎨 视觉与音效需求

### 视觉反馈（必须是"爽快感"的核心来源）

#### 反射成功（完美）
```
1. 子弹变色：金色 → 白色（反射轨迹）
2. 慢镜头：0.1秒，时间流速0.3x
3. 屏幕震动：强度10，持续时间0.2秒
4. 粒子特效：金色火花（Bullet反射时）
5. 浮动文字："完美！" + 伤害数字（金色，放大1.5x）
6. 镜头拉伸：Z轴轻微拉伸（0.95x → 1.05x → 1.0x）
```

#### 反射成功（好）
```
1. 子弹变色：黄色 → 白色（反射轨迹）
2. 粒子特效：黄色火花
3. 浮动文字："好！" + 伤害数字（白色，正常大小）
4. 屏幕震动：强度5，持续时间0.1秒
```

#### 反射失败
```
1. 屏幕红色闪烁：0.2秒
2. 玩家受伤动画：0.3秒无敌时间
3. 音效：受伤音效（低沉）
4. 浮动文字："失败"（红色，缩小）
```

### 音效需求

| 事件 | 音效描述 | 优先级 |
|------|----------|--------|
| 完美反射 | 清脆的"叮"声 + 能量释放音效 | P0 |
| 好反射 | "嗖"的反射音效 | P0 |
| 反射失败 | 低沉的受伤音效 | P0 |
| 子弹进入完美窗口 | 轻微的"嗡"提示音（可选） | P1 |
| Boss反射阶段开始 | 激昂的音乐切换 + "反射时刻！"语音 | P1 |

---

## 🚨 实现注意事项（For Programmer）

### 技术约束
1. **性能优化** - 反射检测每帧执行，必须高效
   - 使用Area3D检测，而非射线检测
   - 子弹池化（Object Pooling），避免运行时实例化
   
2. **输入处理** - 闪避键双重功能
   - 检测子弹距离 + 反射窗口
   - 如果子弹在窗口内 → 触发反射
   - 否则 → 触发闪避

3. **帧率独立性** - 反射窗口基于时间，而非帧数
   - 使用`delta`时间计算，而非固定帧数

### 代码片段参考（Godot 4.x）

```gdscript
## Player.gd - 反射系统核心逻辑

var is_in_reflection_window: bool = false
var reflection_window_start_distance: float = 50.0
var perfect_window_distance: float = 20.0
var good_window_distance: float = 50.0

func _physics_process(delta: float) -> void:
  _check_reflection_window()

func _check_reflection_window() -> void:
  ## 检测附近可反射子弹
  var space_state = get_world_3d().direct_space_state
  var query = PhysicsRayQueryParameters3D.create(global_position, global_position + transform.basis.z * reflection_window_start_distance)
  query.collide_with_areas = true
  query.collide_with_bodies = false
  query.collision_mask = 0b10  ## 子弹层
  
  var result = space_state.intersect_ray(query)
  if result:
    var bullet = result.collider as Node3D
    if bullet and bullet.has_method("can_be_reflected") and bullet.can_be_reflected():
      var distance = global_position.distance_to(bullet.global_position)
      is_in_reflection_window = true
      
      if distance <= perfect_window_distance:
        _show_perfect_window_prompt()
      elif distance <= good_window_distance:
        _show_good_window_prompt()
      else:
        _show_reflection_prompt()
    else:
      is_in_reflection_window = false
  else:
    is_in_reflection_window = false

func _input(event: InputEvent) -> void:
  if event.is_action_pressed("dodge"):  ## 闪避键
    if is_in_reflection_window:
      _reflect_bullet()
    else:
      _dodge_roll()

func _reflect_bullet() -> void:
  ## 反射逻辑
  var nearest_bullet = _get_nearest_reflectable_bullet()
  if nearest_bullet:
    var damage_multiplier = 1.0
    var distance = global_position.distance_to(nearest_bullet.global_position)
    
    if distance <= perfect_window_distance:
      damage_multiplier = 3.0
      _show_feedback("完美！", Color.GOLD)
      _trigger_slow_motion(0.3, 0.1)  ## 慢镜头0.1秒
    elif distance <= good_window_distance:
      damage_multiplier = 1.5
      _show_feedback("好！", Color.YELLOW)
    
    ## 反射子弹
    nearest_bullet.reflect(self, damage_multiplier)
    _play_sound("reflection_success")
    
    ## 冷却时间
    await get_tree().create_timer(0.5).timeout
    is_in_reflection_window = false
```

---

## 📝 Playtest计划

### Playtest目标
1. 验证反射窗口大小是否合理（完美0.1s，好0.2s）
2. 验证反射伤害倍率是否平衡（完美3x，好1.5x）
3. 收集玩家反馈（满意度1-10分）

### Playtest流程
```
1. 准备5-10名测试玩家（新手/老手各半）
2. 让玩家玩30分钟（包含教学 + 3-5局游戏）
3. 观察玩家行为（不指导，记录困惑点）
4. 填写问卷：
   - 反射系统是否有趣？（1-10分）
   - 反射是否太难/太简单？（1-10分）
   - 反射成功是否有爽快感？（1-10分）
   - 你是否想继续玩？（是/否）
5. 整理数据，调整参数
```

### 成功标准
- ✅ 反射系统有趣度 > 7/10
- ✅ 反射难度适中（新手成功率30-50%，老手60-80%）
- ✅ 反射爽快感 > 8/10
- ✅ 继续游玩意愿 > 70%

---

## 🎯 下一步行动

### 设计阶段（本周）
- [ ] 完善此GDD（添加更多细节）
- [ ] 创建反射系统流程图（Visual Flowchart）
- [ ] 设计教学关卡（隐性教学）
- [ ] 设计Boss反射阶段详细流程

### 原型阶段（下周）
- [ ] 实现基础反射检测（不要求美术效果）
- [ ] 测试反射窗口大小（调整参数）
- [ ] 添加基础反馈（命中特效、音效）
- [ ] 内部Playtest（3-5人）

### 完整实现阶段（2-3周后）
- [ ] 实现所有视觉反馈（慢镜头、屏幕震动、粒子）
- [ ] 实现音效系统
- [ ] 实现Boss反射阶段
- [ ] 实现进度系统
- [ ] 公开Playtest（10-20人）

---

## 📋 设计检查清单

### 机制设计
- [x] 反射窗口定义清晰（完美/好/失败）
- [ ] 反射伤害倍率合理（需要Playtest验证）
- [ ] 反射冷却时间防止滥用
- [ ] 不可反射子弹有明确提示（红色发光）

### 玩家体验
- [x] 反射成功有强烈爽快感
- [ ] 反射失败有清晰反馈（不是"莫名其妙受伤"）
- [ ] 教学关卡让玩家理解反射机制
- [ ] 进度系统让玩家感到成长

### 平衡性
- [ ] 反射不会让游戏过于简单（高风险高回报）
- [ ] 反射不会让游戏过于困难（新手也能偶然触发）
- [ ] Boss反射阶段是挑战，而非折磨

### 技术实现
- [ ] 反射检测性能优化（Area3D + 对象池）
- [ ] 输入处理无冲突（闪避 vs 反射）
- [ ] 帧率独立性（基于时间，而非帧数）

---

## 🤔 开放问题（需要讨论）

1. **反射是否消耗资源？**
   - 方案A：免费，但有冷却时间（推荐，更简单）
   - 方案B：消耗法力值（增加策略层，但更复杂）

2. **是否所有敌人子弹都可反射？**
   - 方案A：只有特定敌人/攻击可反射（推荐，创造多样性）
   - 方案B：所有子弹都可反射（更简单，但可能破坏平衡）

3. **反射失败是否惩罚？**
   - 方案A：只是不触发反射，无额外惩罚（推荐，降低挫败感）
   - 方案B：反射失败 = 无法闪避，必受伤（更高风险，但可能太难）

---

**文档版本**: v0.1 (2026-06-08)  
**作者**: GameDesigner  
**下次更新**: Playtest后（预计2026-06-15）  

**变更日志**:
- v0.1: 初始设计，创建核心机制和平衡参数
