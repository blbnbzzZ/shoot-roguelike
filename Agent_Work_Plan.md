# 🎮 游戏开发 Agent 工作计划表
## Game Designer: GameDesigner | 项目: Witch Roguelike Shooter

---

## 📋 项目概览

**项目名称**: Witch Roguelike Shooter  
**当前阶段**: 核心玩法完善 + 前期引导 + 后期留存  
**预计总工期**: 6-8周  
**团队配置**: 1-2名程序员 + 1名游戏设计师（您）+ AI Agent辅助  

---

## 🗓️ 总体时间线（Gantt Chart）

```
Week 1-2  |████████████████|  法术系统核心框架
Week 3-4  |████████████████|  新手引导 + 前期吸引力
Week 5-6  |████████████████|  元游戏进度 + 留存系统
Week 7-8  |████████████████|  社交功能 + 内容更新框架
```

---

## 📅 详细工作计划表

### Phase 1: 法术系统开发（Week 1-2）

#### 🎯 阶段目标
实现4个基础法术（火球术、冰霜新星、闪电链、魔法护盾），建立法力值系统

#### 📋 任务分解

| 任务ID | 任务名称 | 优先级 | 预计工时 | 负责人 | 依赖 | 状态 |
|--------|----------|--------|----------|--------|------|------|
| T1-01  | 创建SpellData资源类 | P0 | 2h | 程序员 | 无 | ⏳ Pending |
| T1-02  | 修改Player.gd添加法力值 | P0 | 3h | 程序员 | T1-01 | ⏳ Pending |
| T1-03  | 创建SpellSystem.gd | P0 | 4h | 程序员 | T1-02 | ⏳ Pending |
| T1-04  | 实现火球术（FireballSpell.gd） | P0 | 6h | 程序员 | T1-03 | ⏳ Pending |
| T1-05  | 实现冰霜新星（FrostNova.gd） | P1 | 5h | 程序员 | T1-03 | ⏳ Pending |
| T1-06  | 实现闪电链（ChainLightning.gd） | P1 | 6h | 程序员 | T1-03 | ⏳ Pending |
| T1-07  | 实现魔法护盾（MagicShield.gd） | P2 | 4h | 程序员 | T1-03 | ⏳ Pending |
| T1-08  | 法术UI（快捷栏 + 法力条） | P0 | 5h | UI设计师 | T1-04 | ⏳ Pending |
| T1-09  | 法术特效（粒子系统） | P1 | 8h | 美术 | T1-04~T1-07 | ⏳ Pending |
| T1-10  | 法术平衡测试 | P0 | 4h | 设计师 | T1-04~T1-07 | ⏳ Pending |

#### 🚨 关键里程碑
- **M1.1 (Week 1结束)**: 火球术可玩，法力值系统运行
- **M1.2 (Week 2结束)**: 4个法术全部实现，可进入平衡测试

#### 📝 Agent工作提示词（Phase 1）

```markdown
# Agent Role: Godot程序员 - 法术系统实现

## 任务背景
你正在为一款女巫主题的Roguelike射击游戏实现法术系统。游戏已经有基础的射击、移动、翻滚机制，现在需要添加法术系统。

## 核心要求
1. **遵循现有代码风格**: 参考WeaponSystem.gd和WeaponData.gd的结构
2. **组件化设计**: 法术系统应该是可扩展的，新法术只需创建新资源
3. **性能优化**: 法术特效使用Object pooling，避免运行时实例化开销
4. **输入映射**: 使用Godot的Input Map系统，支持自定义按键

## 技术约束
- Godot 4.x (GDScript)
- 使用CharacterBody3D + Sprite3D（2.5D视角）
- 法术是Resources（类似WeaponData），便于编辑器和代码创建

## 实现步骤

### Step 1: 创建SpellData.gd
参考路径: `E:\shoot\shoot\scripts\core\WeaponData.gd`
- 创建SpellData类，继承Resource
- 导出属性: display_name, mana_cost, cooldown, description, spell_scene
- 添加法术类型枚举（PROJECTILE, AOE, SELF_CAST, CHANNELING）

### Step 2: 修改Player.gd
参考路径: `E:\shoot\shoot\scripts\Player.gd`
- 添加mana_current和mana_max变量
- 添加法力恢复逻辑（_physics_process中）
- 添加施放法术的输入检测（Q/E/R/F键）

### Step 3: 创建SpellSystem.gd
- 管理当前装备的法术列表（最多4个）
- 处理法术施放逻辑（检查法力、冷却、施放）
- 发送信号: spell_cast(spell_data), mana_changed(current, max)

### Step 4: 实现具体法术
#### 火球术示例:
```gdscript
class_name FireballSpell
extends SpellData

@export var explosion_radius: float = 50.0
@export var projectile_speed: float = 400.0

func cast(caster: Node3D, direction: Vector3) -> void:
  var scene = load("res://scenes/spells/FireballProjectile.tscn")
  var instance = scene.instantiate()
  instance.damage = self.damage
  instance.explosion_radius = self.explosion_radius
  instance.direction = direction
  caster.get_parent().add_child(instance)
  instance.global_position = caster.global_position + direction * 20.0
```

### Step 5: UI实现
参考现有UI: `E:\shoot\shoot\scenes\Main.gd` (ui_health, ui_coins等)
- 创建法力条（ProgressBar，位于血条下方）
- 创建法术快捷栏（HBoxContainer，屏幕底部中央）
- 显示法术图标、冷却Overlay、法力消耗

## 测试清单
- [ ] 法力值正确恢复（每秒5点）
- [ ] 法力不足时无法施放法术（UI灰显 + 提示）
- [ ] 火球术命中敌人造成伤害
- [ ] 火球术爆炸造成范围伤害
- [ ] 冰霜新星减速敌人50%持续3秒
- [ ] 闪电链正确弹射到2个额外目标
- [ ] 魔法护盾正确吸收伤害
- [ ] 所有法术都有正确特效和音效

## 交付物
1. SpellData.gd
2. SpellSystem.gd (挂载到Player场景)
3. 4个法术实现（Fireball, FrostNova, ChainLightning, MagicShield）
4. 法术UI场景（SpellUI.tscn）
5. 法术特效粒子（.tscn文件）
6. 测试报告（包含已知问题和平衡建议）

## 注意事项
- 法术伤害应该是[PLACEHOLDER]，等待设计师平衡
- 所有数值都应该在SpellData中暴露，便于策划调整
- 记得在Player.gd中添加信号连接（spell_system.spell_cast）
- 参考GDD_SpellSystem.md获取详细设计（已创建在E:\shoot\）
```

---

### Phase 2: 新手引导 & 前期吸引力（Week 3-4）

#### 🎯 阶段目标
实现隐性教学系统，确保前3分钟体验流畅，第一个"Boss击杀"产生成就感

#### 📋 任务分解

| 任务ID | 任务名称 | 优先级 | 预计工时 | 负责人 | 依赖 | 状态 |
|--------|----------|--------|----------|--------|------|------|
| T2-01  | 创建安全房（Safe Room） | P0 | 4h | 关卡设计师 | 无 | ⏳ Pending |
| T2-02  | 实现隐性教学流程 | P0 | 8h | 设计师+程序 | T2-01 | ⏳ Pending |
| T2-03  | 添加三发子弹拾取教学 | P0 | 3h | 程序员 | T2-02 | ⏳ Pending |
| T2-04  | 实现精英怪"哇时刻"特效 | P1 | 6h | 程序员+美术 | 无 | ⏳ Pending |
| T2-05  | 创建商店房（Shop Room） | P1 | 5h | 程序员 | 无 | ⏳ Pending |
| T2-06  | 动态难度调整系统 | P2 | 4h | 程序员 | 无 | ⏳ Pending |
| T2-07  | 成就系统（基础10个） | P1 | 6h | 程序员 | 无 | ⏳ Pending |
| T2-08  | 新手引导Playtest | P0 | 4h | 设计师 | T2-02~T2-04 | ⏳ Pending |

#### 🚨 关键里程碑
- **M2.1 (Week 3结束)**: 玩家可在无压力下探索安全房，学习基础操作
- **M2.2 (Week 4结束)**: 完整新手流程可玩，成就系统运行

#### 📝 Agent工作提示词（Phase 2）

```markdown
# Agent Role: 游戏设计师 + Godot程序员 - 新手引导实现

## 任务背景
当前游戏缺少新手引导，玩家不知道如何玩。需要实现一个"隐性教学"系统，让玩家通过实践学习，而非阅读文字教程。

## 设计原则（CRITICAL）
1. **Show, don't tell** - 让玩家通过行动学习
2. **无压力环境** - 第一个房间应该是安全房（无敌人）
3. **即时反馈** - 每个行动都有明确的视觉/音频反馈
4. **渐进式复杂性** - 先教移动，再教射击，最后是闪避和法术

## 实现步骤

### Step 1: 创建安全房场景
参考: `E:\shoot\shoot\scenes\rooms\RoomTemplate.tscn`
- 创建一个大房间，无敌人
- 添加可视化提示：
  - 地面有箭头指示移动方向
  - 墙上有靶子指示射击目标
  - 陷阱（无伤害）指示闪避时机
- 房间中央有NPC（女巫导师），提供可选对话

### Step 2: 实现教学流程（TutorialFlow.gd）
```gdscript
class_name TutorialFlow
extends Node

signal tutorial_step_completed(step: int)
signal tutorial_completed()

var current_step: int = 0
var steps: Array[Dictionary] = []

func _ready() -> void:
  _setup_tutorial_steps()
  _start_tutorial()

func _setup_tutorial_steps() -> void:
  steps = [
    {
      "id": 0,
      "instruction": "使用WASD移动",
      "condition": func(): return _player_moved_distance() > 50.0,
      "hint_position": Vector3(0, 0, 100)
    },
    {
      "id": 1,
      "instruction": "鼠标瞄准，左键射击",
      "condition": func(): return _player_fired_shots() >= 3,
      "hint_position": Vector3(0, 0, 150)
    },
    {
      "id": 2,
      "instruction": "按空格键翻滚闪避",
      "condition": func(): return _player_rolled() >= 1,
      "hint_position": Vector3(100, 0, 0)
    }
  ]

func _process_tutorial() -> void:
  if current_step >= steps.size():
    tutorial_completed.emit()
    return
  
  var step = steps[current_step]
  if step["condition"].call():
    current_step += 1
    tutorial_step_completed.emit(current_step)
    _show_instruction("")
```

### Step 3: 添加视觉提示系统
- 创建TutorialHint节点（Sprite3D + 动画）
- 当玩家接近教学点时，显示浮动提示
- 提示文字："按WASD移动"、"点击鼠标射击"

### Step 4: 实现"哇时刻"特效
参考: GDD_Onboarding_Retention.md中的精英怪击杀特效
```gdscript
## 在EnemyBase.gd中添加
func _on_died() -> void:
  if is_elite:
    # 慢镜头
    Engine.time_scale = 0.3
    await get_tree().create_timer(0.5).timeout
    Engine.time_scale = 1.0
    
    # 屏幕震动
    get_viewport().set_shake(10.0, 0.5)
    
    # 金币暴雨
    for i in range(20):
      _spawn_coin_particle()
```

### Step 5: 动态难度调整
```gdscript
## 在GameManager.gd或Main.gd中添加
var player_death_count: int = 0
var dynamic_difficulty_multiplier: float = 1.0

func _on_player_died() -> void:
  player_death_count += 1
  
  # 前3次死亡降低难度
  if player_death_count <= 3:
    dynamic_difficulty_multiplier = 0.8  # 敌人伤害-20%
    _show_message("怜悯模式激活：敌人伤害降低")
  
  # 连续失败5次，进一步降低
  if player_death_count >= 5:
    dynamic_difficulty_multiplier = 0.6
    _show_message("已为你降低难度，继续尝试！")
```

## 测试清单
- [ ] 玩家出生在安全房，无压力探索
- [ ] 教学提示在正确时机出现
- [ ] 玩家通过实践学会移动、射击、闪避
- [ ] 第一个精英怪击杀产生慢镜头+震动+金币暴雨
- [ ] 前3次死亡后难度明显降低（可感知）
- [ ] 成就系统正确触发（首次击杀、首次施放法术等）

## 交付物
1. TutorialFlow.gd（教学流程控制器）
2. TutorialHint.tscn（视觉提示UI）
3. 安全房场景（SafeRoom.tscn）
4. 动态难度调整系统（集成到Main.gd）
5. 成就系统基础框架（AchievementSystem.gd）
6. Playtest报告（包含新手玩家反馈）

## 注意事项
- 教学应该是可选的（老玩家可跳过）
- 所有提示应该是视觉化的，避免大段文字
- "哇时刻"特效不应该影响游戏平衡（纯视觉）
- 动态难度调整要对玩家透明（不要明确告诉玩家"难度降低了"）
```

---

### Phase 3: 元游戏进度 & 留存系统（Week 5-6）

#### 🎯 阶段目标
实现永久升级系统、图鉴系统、每日挑战，提升长期留存

#### 📋 任务分解

| 任务ID | 任务名称 | 优先级 | 预计工时 | 负责人 | 依赖 | 状态 |
|--------|----------|--------|----------|--------|------|------|
| T3-01  | 创建元游戏进度系统（MetaProgression.gd） | P0 | 6h | 程序员 | 无 | ⏳ Pending |
| T3-02  | 实现永久升级商店UI | P0 | 5h | UI设计师 | T3-01 | ⏳ Pending |
| T3-03  | 创建敌人图鉴系统（Bestiary.gd） | P1 | 8h | 程序员 | 无 | ⏳ Pending |
| T3-04  | 实现每日挑战（DailyChallenge.gd） | P1 | 10h | 程序员 | T3-01 | ⏳ Pending |
| T3-05  | 创建排行榜系统（Leaderboard.gd） | P2 | 8h | 程序员 | T3-04 | ⏳ Pending |
| T3-06  | 游戏结束统计屏幕 | P0 | 6h | UI设计师 | T3-01 | ⏳ Pending |
| T3-07  | 平衡永久升级数值 | P0 | 4h | 设计师 | T3-02 | ⏳ Pending |
| T3-08  | 留存系统Playtest | P0 | 6h | 设计师 | T3-01~T3-06 | ⏳ Pending |

#### 🚨 关键里程碑
- **M3.1 (Week 5结束)**: 永久升级系统可玩，玩家能感受到进度
- **M3.2 (Week 6结束)**: 每日挑战和排行榜运行，留存loop完整

#### 📝 Agent工作提示词（Phase 3）

```markdown
# Agent Role: 系统程序员 - 元游戏进度系统实现

## 任务背景
当前游戏是纯粹的Roguelike（每局独立），缺少长期动力。需要添加永久升级系统、图鉴、每日挑战，让玩家有"再玩一局"的理由。

## 核心设计原则
1. **每次游戏都有进度** - 即使失败，也获得金币用于永久升级
2. **进度可感知** - 玩家明确知道"我在变强"
3. **避免Pay-to-Win** - 永久升级应该是时间投入，而非付费
4. **社交驱动** - 排行榜和每日挑战创造社交比较

## 实现步骤

### Step 1: 创建MetaProgression.gd（元游戏管理器）
```gdscript
class_name MetaProgression
extends Node

signal currency_changed(amount: int)
signal upgrade_purchased(upgrade_id: String)

## 持久化数据（保存到文件）
var persistent_data: Dictionary = {
  "currency": 0,
  "upgrades": {},
  "bestiary": {},
  "statistics": {
    "total_kills": 0,
    "total_deaths": 0,
    "highest_floor": 0,
    "total_playtime": 0.0
  }
}

## 永久升级定义
var upgrade_definitions: Dictionary = {
  "hp_boost_1": {
    "name": "生命值提升I",
    "description": "最大生命值+10",
    "cost": 100,
    "effect": func(player): player.health_comp.max_health += 10
  },
  "mana_boost_1": {
    "name": "法力值提升I",
    "description": "最大法力值+20",
    "cost": 150,
    "effect": func(player): player.mana_max += 20
  },
  "speed_boost_1": {
    "name": "移动速度提升I",
    "description": "移动速度+5%",
    "cost": 200,
    "effect": func(player): player.move_speed *= 1.05
  }
  # ... 更多升级
}

func add_currency(amount: int) -> void:
  persistent_data.currency += amount
  currency_changed.emit(persistent_data.currency)
  _save_data()

func purchase_upgrade(upgrade_id: String) -> bool:
  if not upgrade_definitions.has(upgrade_id):
    return false
  if persistent_data.upgrades.has(upgrade_id):
    return false  # 已购买
  if persistent_data.currency < upgrade_definitions[upgrade_id].cost:
    return false  # 金币不足
  
  persistent_data.currency -= upgrade_definitions[upgrade_id].cost
  persistent_data.upgrades[upgrade_id] = true
  upgrade_definitions[upgrade_id].effect.call(get_node("/root/Main/Player"))
  upgrade_purchased.emit(upgrade_id)
  _save_data()
  return true

func _save_data() -> void:
  var file = FileAccess.open("user://meta_progression.save", FileAccess.WRITE)
  file.store_string(JSON.stringify(persistent_data))
  file.close()

func _load_data() -> void:
  if not FileAccess.file_exists("user://meta_progression.save"):
    return
  var file = FileAccess.open("user://meta_progression.save", FileAccess.READ)
  var json = JSON.new()
  json.parse(file.get_as_text())
  persistent_data = json.data
  file.close()
```

### Step 2: 实现永久升级商店UI
```gdscript
## UpgradeStore.gd - 挂载到Control节点
extends Control

@onready var currency_label: Label = $CurrencyLabel
@onready var upgrade_container: VBoxContainer = $ScrollContainer/VBoxContainer

var meta_progression: MetaProgression

func _ready() -> void:
  meta_progression = get_node_or_null("/root/MetaProgression")
  if meta_progression:
    meta_progression.currency_changed.connect(_on_currency_changed)
  _populate_upgrades()

func _populate_upgrades() -> void:
  for upgrade_id in meta_progression.upgrade_definitions.keys():
    var upgrade_data = meta_progression.upgrade_definitions[upgrade_id]
    var button = Button.new()
    button.text = "%s\n%s\n费用: %d金币" % [
      upgrade_data.name,
      upgrade_data.description,
      upgrade_data.cost
    ]
    button.pressed.connect(func(): _on_upgrade_pressed(upgrade_id))
    upgrade_container.add_child(button)

func _on_upgrade_pressed(upgrade_id: String) -> void:
  if meta_progression.purchase_upgrade(upgrade_id):
    _show_message("升级成功！")
    _refresh_ui()
  else:
    _show_message("金币不足或已购买")

func _on_currency_changed(amount: int) -> void:
  currency_label.text = "金币: %d" % amount
```

### Step 3: 创建敌人图鉴系统（Bestiary）
参考: GDD_Onboarding_Retention.md中的BestiaryEntry设计
```gdscript
## Bestiary.gd
extends Node

var entries: Dictionary = {}  # enemy_id -> BestiaryEntry

func register_kill(enemy_id: String, enemy_data: Dictionary) -> void:
  if not entries.has(enemy_id):
    entries[enemy_id] = {
      "name": enemy_data.name,
      "description": enemy_data.description,
      "hp": enemy_data.hp,
      "damage": enemy_data.damage,
      "kill_count": 0,
      "unlocked": false
    }
  
  entries[enemy_id].kill_count += 1
  if entries[enemy_id].kill_count >= 1:
    entries[enemy_id].unlocked = true
    _show_notification("图鉴解锁: %s" % entries[enemy_id].name)
  
  _save_data()

func get_unlocked_count() -> int:
  var count = 0
  for entry in entries.values():
    if entry.unlocked:
      count += 1
  return count
```

### Step 4: 实现每日挑战
```gdscript
## DailyChallenge.gd
extends Node

var daily_seed: int = 0
var daily_leaderboard: Array[Dictionary] = []

func _ready() -> void:
  # 基于日期生成固定种子
  var date = Time.get_date_dict_from_system()
  daily_seed = date.year * 10000 + date.month * 100 + date.day
  randomize()  # 重置RNG

func get_daily_seed() -> int:
  return daily_seed

func submit_score(player_name: String, score: int) -> void:
  daily_leaderboard.append({
    "name": player_name,
    "score": score,
    "date": Time.get_date_string_from_system()
  })
  daily_leaderboard.sort_custom(func(a, b): return a.score > b.score)
  _save_leaderboard()

func get_rank(player_name: String) -> int:
  for idx in range(daily_leaderboard.size()):
    if daily_leaderboard[idx].name == player_name:
      return idx + 1
  return -1
```

## 测试清单
- [ ] 每局游戏结束获得金币（基于表现）
- [ ] 金币可购买永久升级（重启游戏后生效）
- [ ] 升级效果正确应用（血量+10、法力+20等）
- [ ] 敌人图鉴在首次击杀后解锁
- [ ] 每日挑战使用固定种子（每天相同）
- [ ] 排行榜正确显示前100名
- [ ] 游戏结束屏幕显示本局统计和永久进度

## 交付物
1. MetaProgression.gd（元游戏管理器，单例）
2. UpgradeStore.tscn（永久升级商店UI）
3. Bestiary.gd + BestiaryUI.tscn（图鉴系统）
4. DailyChallenge.gd（每日挑战管理器）
5. Leaderboard.gd + LeaderboardUI.tscn（排行榜UI）
6. RunSummaryScreen.tscn（游戏结束统计屏幕）
7. 平衡文档（永久升级价格和效果曲线）

## 注意事项
- 所有持久化数据保存在user://目录（Godot用户数据路径）
- 永久升级应该是"感觉明显但不过强"，避免破坏游戏平衡
- 每日挑战的种子应该基于日期，确保全球玩家同一天玩相同地图
- 排行榜初期可以本地保存，后期可集成Playfab/Firebase
```

---

### Phase 4: 社交功能 & 内容更新框架（Week 7-8）

#### 🎯 阶段目标
实现好友挑战、每周活动、为新内容创建可扩展框架

#### 📋 任务分解

| 任务ID | 任务名称 | 优先级 | 预计工时 | 负责人 | 依赖 | 状态 |
|--------|----------|--------|----------|--------|------|------|
| T4-01  | 创建好友挑战系统 | P2 | 10h | 程序员 | T3-05 | ⏳ Pending |
| T4-02  | 实现每周活动框架 | P1 | 8h | 程序员 | T3-04 | ⏳ Pending |
| T4-03  | 添加新法术（2个） | P1 | 6h | 程序员 | T1-03 | ⏳ Pending |
| T4-04  | 添加新敌人类型（3个） | P1 | 9h | 程序员+美术 | 无 | ⏳ Pending |
| T4-05  | 创建内容更新Pipeline | P2 | 4h | 设计师 | 无 | ⏳ Pending |
| T4-06  | 平衡性Pass（全系统） | P0 | 8h | 设计师 | 全部 | ⏳ Pending |
| T4-07  | 完整Playtest（Alpha版本） | P0 | 16h | 设计师 | 全部 | ⏳ Pending |

#### 🚨 关键里程碑
- **M4.1 (Week 7结束)**: 社交功能可运行，每周活动框架完成
- **M4.2 (Week 8结束)**: Alpha版本完成，准备Beta测试

---

## 📊 资源分配矩阵

| 角色 | Week 1-2 | Week 3-4 | Week 5-6 | Week 7-8 | 总计 |
|------|----------|----------|----------|----------|------|
| 主程序员 | 40h | 30h | 35h | 25h | 130h |
| UI设计师 | 5h | 15h | 20h | 10h | 50h |
| 美术 | 8h | 10h | 5h | 15h | 38h |
| 游戏设计师 | 10h | 20h | 15h | 25h | 70h |
| Playtest | 0h | 4h | 6h | 16h | 26h |
| **总计** | **63h** | **79h** | **81h** | **91h** | **314h** |

---

## 🎯 成功指标（KPIs）

### 前期吸引力（Onboarding）
- ✅ 新手教程完成率 > 85%
- ✅ 前3分钟流失率 < 30%
- ✅ 第一个Boss击杀率 > 60%

### 后期留存（Retention）
- ✅ Day-1留存 > 40%
- ✅ Day-7留存 > 15%
- ✅ 平均游戏局数/天 > 3
- ✅ 永久升级购买率 > 70%

### 玩家满意度
- ✅ Playtest满意度评分 > 7/10
- ✅ 是否愿意推荐给朋友 > 60% (NPS)

---

## ⚠️ 风险管理

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 法术系统导致平衡破坏 | 高 | 中 | 早期引入[PLACEHOLDER]数值，频繁平衡Pass |
| 新手引导过于冗长 | 中 | 中 | Playtest迭代，确保<5分钟 |
| 元游戏进度过于Grindy | 高 | 高 | 监控平均通关时间，调整金币奖励 |
| 内容更新频率不足 | 中 | 中 | 建立内容Pipeline，每月至少1个新法术/敌人 |

---

## 📝 会议节奏

- **每日Standup** (15min): 进度同步， blocker识别
- **周会** (1h): Week回顾，下周计划调整
- **Playtest Session** (2h): 每周五下午，邀请5-10名测试玩家
- **Retro聚会** (2h): 每个Phase结束，总结教训

---

## 🚀 下一步行动

### 本周任务（Week 1）
1. [ ] **周一**: 创建SpellData.gd和法力值系统（T1-01, T1-02）
2. [ ] **周二**: 实现SpellSystem.gd（T1-03）
3. [ ] **周三**: 实现火球术（T1-04）
4. [ ] **周四**: 实现冰霜新星和闪电链（T1-05, T1-06）
5. [ ] **周五**: Playtest法术系统，收集反馈

### 依赖确认
- [ ] Godot版本确认（4.0+？）
- [ ] 美术资源需求清单（法术特效、UI图标）
- [ ] Playtest玩家招募（至少10人）

---

**文档版本**: v0.1 (2026-06-08)  
**作者**: GameDesigner  
**下次更新**: Week 1结束（2026-06-15）
