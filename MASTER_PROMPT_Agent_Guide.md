# 🎮 Master Prompt: 游戏开发 Agent 完整指南
## 项目: Witch Roguelike Shooter | Game Designer: GameDesigner

---

## 📋 项目背景

你是一名为"Witch Roguelike Shooter"游戏工作的Godot程序员/游戏设计师。这是一款**女巫主题的Roguelike射击游戏**（2.5D视角，使用Sprite3D）。

### 游戏核心机制（已实现）
- ✅ 玩家控制（移动WASD、鼠标瞄准、左键射击、空格翻滚闪避）
- ✅ 武器系统（WeaponData资源、伤害、射速、弹丸数量、散布）
- ✅ 血量系统（HealthComponent组件化，有无敌时间）
- ✅ 地牢生成（随机游走算法、支持普通/大/超大房间）
- ✅ 房间系统（普通房、安全房、Boss房、奖励房）
- ✅ 基础UI（血条、金币、分数、层数、小地图、Boss血条）

### 代码库结构
```
E:\shoot\shoot\
├── scenes\
│   ├── Main.gd              # 主场景控制器
│   ├── Player.gd            # 玩家角色（3D版本）
│   ├── enemies\EnemyBase.gd # 敌人基类
│   ├── items\               # 拾取物
│   ├── rooms\               # 房间场景
│   └── weapons\             # 武器和弹丸
├── scripts\
│   ├── components\
│   │   ├── WeaponSystem.gd  # 武器系统组件
│   │   └── HealthComponent.gd # 血量组件
│   ├── core\
│   │   ├── WeaponData.gd    # 武器数据资源
│   │   └── DungeonGenerator.gd # 地牢生成器
│   └── Player.gd            # 玩家脚本
└── assets\                  # 美术资源（女巫精灵图等）
```

---

## 🎯 你的任务（按优先级）

### Phase 1: 法术系统（Week 1-2）— 优先级 P0
**目标**: 实现4个法术（火球术、冰霜新星、闪电链、魔法护盾），建立法力值系统

#### 具体任务
1. **创建SpellData.gd** - 法术数据资源（类似WeaponData）
2. **修改Player.gd** - 添加法力值变量和恢复逻辑
3. **创建SpellSystem.gd** - 法术施放管理器（挂载到Player）
4. **实现4个法术**:
   - FireballSpell.gd - 火球术（发射火球，范围爆炸）
   - FrostNova.gd - 冰霜新星（AOE + 减速）
   - ChainLightning.gd - 闪电链（弹射伤害）
   - MagicShield.gd - 魔法护盾（伤害吸收）
5. **创建法术UI** - 快捷栏（屏幕底部）+ 法力条（血条下方）

#### 技术约束
- **参考现有代码**: `E:\shoot\shoot\scripts\core\WeaponData.gd` 和 `WeaponSystem.gd`
- **组件化设计**: 法术应该是Resource，便于在编辑器中创建和平衡
- **输入映射**: 使用Godot的Input Map，法术施放用Q/E/R/F键
- **性能优化**: 法术特效使用对象池（Object Pooling）

#### 交付物
- [ ] SpellData.gd
- [ ] 修改Player.gd（添加法力值）
- [ ] SpellSystem.gd
- [ ] 4个法术实现（.gd + .tscn）
- [ ] 法术UI场景（SpellUI.tscn）
- [ ] 法术特效粒子系统
- [ ] 测试报告

#### 代码片段参考

**SpellData.gd**:
```gdscript
class_name SpellData
extends Resource

@export var display_name: String = "Fireball"
@export var mana_cost: float = 20.0
@export var cooldown: float = 0.0  # 0 = 无冷却，受法力限制
@export var damage: float = 50.0
@export var spell_scene: PackedScene
@export_multiline var description: String = ""
```

**修改Player.gd添加法力值**:
```gdscript
## 在Player.gd的var区域添加
var mana_current: float = 100.0
var mana_max: float = 100.0
var mana_regen_rate: float = 5.0  # 每秒恢复5点

## 在_physics_process中添加
mana_current = min(mana_current + mana_regen_rate * delta, mana_max)
```

---

### Phase 2: 新手引导 & 前期吸引力（Week 3-4）— 优先级 P0
**目标**: 实现隐性教学系统，确保前3分钟体验流畅

#### 设计原则（CRITICAL）
1. **Show, don't tell** - 让玩家通过行动学习，不要文字教程
2. **无压力环境** - 第一个房间应该是安全房（无敌人）
3. **即时反馈** - 每个行动都有明确的视觉/音频反馈
4. **渐进式复杂性** - 先教移动，再教射击，最后闪避和法术

#### 具体任务
1. **创建安全房场景** - 无敌人，有视觉提示（地面箭头、靶子）
2. **实现TutorialFlow.gd** - 教学流程控制器
3. **添加视觉提示系统** - TutorialHint节点（浮动提示）
4. **实现"哇时刻"特效** - 精英怪击杀慢镜头+震动+金币暴雨
5. **创建商店房** - 用金币购买法术/升级
6. **实现动态难度调整** - 前3次死亡降低难度

#### 代码片段参考

**TutorialFlow.gd**:
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
      "condition": func(): return _player_moved_distance() > 50.0
    },
    {
      "id": 1,
      "instruction": "鼠标瞄准，左键射击",
      "condition": func(): return _player_fired_shots() >= 3
    },
    {
      "id": 2,
      "instruction": "按空格键翻滚闪避",
      "condition": func(): return _player_rolled() >= 1
    }
  ]
```

**精英怪"哇时刻"特效** (添加到EnemyBase.gd):
```gdscript
func _on_died() -> void:
  if is_elite:
    # 慢镜头效果
    Engine.time_scale = 0.3
    await get_tree().create_timer(0.5).timeout
    Engine.time_scale = 1.0
    
    # 屏幕震动
    if get_viewport().has_method("set_shake"):
      get_viewport().set_shake(10.0, 0.5)
    
    # 金币暴雨
    for i in range(20):
      _spawn_coin_particle()
```

#### 交付物
- [ ] TutorialFlow.gd + TutorialHint.tscn
- [ ] 安全房场景（SafeRoom.tscn）
- [ ] 精英怪击杀特效
- [ ] 商店房系统
- [ ] 动态难度调整系统
- [ ] Playtest报告（前3分钟体验）

---

### Phase 3: 元游戏进度 & 留存系统（Week 5-6）— 优先级 P0
**目标**: 实现永久升级、图鉴、每日挑战，提升长期留存

#### 具体任务
1. **创建MetaProgression.gd** - 元游戏管理器（单例）
2. **实现永久升级商店** - 用金币购买永久升级（血量+10、法力+20等）
3. **创建敌人图鉴系统** - Bestiary.gd（击败敌人解锁图鉴条目）
4. **实现每日挑战** - DailyChallenge.gd（固定种子，全球玩家同一天相同地图）
5. **创建排行榜系统** - Leaderboard.gd（本地高分，可后期集成服务器）
6. **游戏结束统计屏幕** - RunSummaryScreen.tscn

#### 代码片段参考

**MetaProgression.gd**:
```gdscript
class_name MetaProgression
extends Node

signal currency_changed(amount: int)
signal upgrade_purchased(upgrade_id: String)

## 持久化数据
var persistent_data: Dictionary = {
  "currency": 0,
  "upgrades": {},
  "bestiary": {},
  "statistics": {
    "total_kills": 0,
    "total_deaths": 0,
    "highest_floor": 0
  }
}

## 永久升级定义
var upgrade_definitions: Dictionary = {
  "hp_boost_1": {
    "name": "生命值提升I",
    "cost": 100,
    "effect": func(player): player.health_comp.max_health += 10
  },
  "mana_boost_1": {
    "name": "法力值提升I",
    "cost": 150,
    "effect": func(player): player.mana_max += 20
  }
}

func add_currency(amount: int) -> void:
  persistent_data.currency += amount
  currency_changed.emit(persistent_data.currency)
  _save_data()

func purchase_upgrade(upgrade_id: String) -> bool:
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
```

#### 交付物
- [ ] MetaProgression.gd（单例，自动加载）
- [ ] 永久升级商店UI（UpgradeStore.tscn）
- [ ] 敌人图鉴系统（Bestiary.gd + BestiaryUI.tscn）
- [ ] 每日挑战系统（DailyChallenge.gd）
- [ ] 排行榜UI（Leaderboard.tscn）
- [ ] 游戏结束统计屏幕（RunSummaryScreen.tscn）
- [ ] 平衡文档（永久升级价格和效果曲线）

---

### Phase 4: 社交功能 & 内容更新（Week 7-8）— 优先级 P1
**目标**: 实现好友挑战、每周活动、建立内容更新Pipeline

#### 具体任务
1. **实现好友挑战系统** - 与好友compare分数，发起1v1挑战
2. **创建每周活动框架** - 主题活动（"法术周"、"生存周"）
3. **添加新内容** - 2个新法术、3个新敌人类型
4. **建立内容更新Pipeline** - 便于每月添加新法术/敌人
5. **完整平衡Pass** - 所有系统数值平衡
6. **Alpha版本Playtest** - 邀请10-20名玩家测试

#### 交付物
- [ ] 好友挑战系统
- [ ] 每周活动框架
- [ ] 2个新法术 + 3个新敌人
- [ ] 内容更新Pipeline文档
- [ ] Alpha版本构建
- [ ] Playtest报告和平衡建议

---

## 🔧 开发规范

### 代码规范
1. **注释**: 每个函数都要有注释（用途、参数、返回值）
2. **信号**: 使用Godot信号系统解耦，避免直接引用
3. **导出变量**: 所有可调参数用@export暴露，便于策划调整
4. **[PLACEHOLDER]标记**: 所有平衡数值标记为[PLACEHOLDER]，等待Playtest后调整

### 文档规范
1. **GDD更新**: 每个新系统都要更新GDD（Game Design Document）
2. **提交信息**: Git提交信息要清晰（"实现火球术法术"、"修复玩家穿墙Bug"）
3. **测试清单**: 每个功能完成后，附上测试清单（见各Phase交付物）

### 平衡规范
1. **数值假设**: 所有数值都要有 rationale（为什么是这个值？）
2. **平衡Pass**: 每周五进行平衡Pass，根据Playtest反馈调整
3. **难度的曲线**: 记录所有难度曲线（敌人血量、伤害、金币掉落）

---

## 🚨 常见问题 & 解决方案

### Q1: 如何调试法术系统？
**A**: 在SpellSystem.gd中添加`print()`语句，查看法力值消耗和法术施放是否正常工作。使用Godot远程调试。

### Q2: 新手引导如何跳过？
**A**: 在TutorialFlow.gd中检测玩家输入，如果玩家主动移动/射击，自动跳过对应教学步骤。

### Q3: 永久升级如何应用到新游戏？
**A**: 在Player.gd的`_ready()`中，调用`MetaProgression`单例，应用所有已购买的升级效果。

### Q4: 每日挑战的固定种子如何实现？
**A**: 使用`Time.get_date_dict_from_system()`获取日期，生成基于日期的种子（如20260608），传入`DungeonGenerator.gd`的`seed_value`属性。

### Q5: 排行榜如何防止作弊？
**A**: 初期可以本地保存，后期集成服务器验证。服务器端重新模拟游戏过程，验证分数合法性。

---

## 📊 进度跟踪

### 每日Standup（15分钟）
回答3个问题：
1. 昨天完成了什么？
2. 今天计划做什么？
3. 遇到什么阻碍？

### 每周Playtest（周五下午2小时）
1. **邀请5-10名测试玩家**（非开发团队成员）
2. **观察玩家行为**（不要指导，记录困惑点）
3. **收集反馈**（问卷：1-10分评分 + 开放性建议）
4. **整理行动项**（下周一前完成高优先级修复）

### 里程碑检查点
- **M1 (Week 2结束)**: 法术系统可玩，火球术实现
- **M2 (Week 4结束)**: 新手引导完成，玩家可独立游玩前10分钟
- **M3 (Week 6结束)**: 元游戏进度系统运行，玩家有"再玩一局"动力
- **M4 (Week 8结束)**: Alpha版本完成，准备Beta测试

---

## 📝 参考资料

### 已创建的设计文档
1. **GDD_SpellSystem.md** - 法术系统详细设计（`E:\shoot\GDD_SpellSystem.md`）
2. **GDD_Onboarding_Retention.md** - 前期吸引力和后期留存方案（`E:\shoot\GDD_Onboarding_Retention.md`）
3. **Agent_Work_Plan.md** - 详细工作计划表（`E:\shoot\Agent_Work_Plan.md`）

### 关键代码文件（必须阅读）
1. `E:\shoot\shoot\scripts\Player.gd` - 玩家脚本（添加法力值系统）
2. `E:\shoot\shoot\scripts\components\WeaponSystem.gd` - 武器系统（参考结构）
3. `E:\shoot\shoot\scripts\core\WeaponData.gd` - 武器数据（法术数据参考）
4. `E:\shoot\shoot\scenes\Main.gd` - 主场景（UI集成参考）

### 外部资源
- **Godot官方文档**: https://docs.godotengine.org/
- **Roguelike设计模式**: https://www.roguebasin.com/
- **游戏平衡指南**: 参考GDD文档中的平衡章节

---

## ✅ 检查清单（每周更新）

### Week 1 检查清单
- [ ] 创建SpellData.gd
- [ ] 修改Player.gd添加法力值
- [ ] 创建SpellSystem.gd
- [ ] 实现火球术（FireballSpell.gd）
- [ ] 创建法术UI（法力条 + 快捷栏）
- [ ] 周五年Playtest（测试法术手感）

### Week 2 检查清单
- [ ] 实现冰霜新星（FrostNova.gd）
- [ ] 实现闪电链（ChainLightning.gd）
- [ ] 实现魔法护盾（MagicShield.gd）
- [ ] 添加法术特效（粒子系统）
- [ ] 法术平衡测试（伤害、法力消耗、冷却）
- [ ] 修复Week 1发现的Bug

### Week 3 检查清单
- [ ] 创建安全房场景
- [ ] 实现TutorialFlow.gd
- [ ] 添加视觉提示系统（TutorialHint）
- [ ] 实现精英怪"哇时刻"特效
- [ ] 创建商店房系统
- [ ] Playtest新手引导流程

### Week 4-8 检查清单
（参考Agent_Work_Plan.md中的详细任务分解）

---

## 🎯 成功标准

### 法术系统（Phase 1）
- ✅ 玩家能流畅施放4个法术
- ✅ 法力值系统运行正常（恢复、消耗、UI显示）
- ✅ 法术有酷炫特效和音效
- ✅ 平衡性合理（法术比普通攻击强30-50%）

### 新手引导（Phase 2）
- ✅ 前30秒玩家理解移动和射击
- ✅ 前3分钟玩家获得第一个"力量增强"（三发子弹/新法术）
- ✅ 教学通过实践完成，无文字教程
- ✅ 新手教程完成率 > 85%

### 留存系统（Phase 3）
- ✅ 每局游戏结束获得金币
- ✅ 金币可购买永久升级
- ✅ 玩家有明确动力"再玩一局"
- ✅ Day-1留存率 > 40%

### 整体体验（Phase 4）
- ✅ Playtest满意度评分 > 7/10
- ✅ 平均游戏局数/天 > 3
- ✅ 无崩溃Bug，帧率稳定60FPS
- ✅ 所有[PLACEHOLDER]数值经过至少1轮平衡调整

---

## 🚀 开始工作吧！

如果你已经理解任务，请回复：
**"我已理解任务，开始执行Phase 1 - 法术系统开发"**

如果有疑问，请具体指出：
- 哪部分设计不清晰？
- 哪个技术实现有困难？
- 需要更多参考资料？

---

**文档版本**: v1.0 (2026-06-08)  
**作者**: GameDesigner  
**下一次更新**: Week 1结束（2026-06-15）  
**联系方式**: 如有问题，参考GDD文档或创建Issue
