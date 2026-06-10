# 前期吸引力 & 后期留存设计方案
## Game Designer: GameDesigner

---

## 🎯 第一部分：前期吸引力设计（0-30分钟体验）

### 设计目标
- **30秒内**: 玩家理解核心玩法（移动、射击、闪避）
- **3分钟内**: 获得第一个"力量增强"（三发子弹/新法术）
- **10分钟内**: 击败第一个Boss，获得成就感
- **30分钟内**: 理解元游戏进度系统，产生"再玩一局"的冲动

---

## 📋 新手引导流程（Onboarding Flow）

### 阶段1：隐性教学（0-3分钟）

```markdown
## Onboarding Checklist

- [x] **0-10秒**: 玩家出生在安全房，可自由移动（无压力探索）
- [x] **10-30秒**: 自动开启相邻房间门，出现1只弱敌人（教学战斗）
- [x] **30-60秒**: 击败敌人后掉落"三发子弹拾取物"，自动提示按E拾取
- [x] **60-120秒**: 清除第一个房间，门自动开启，进入下一房间
- [x] **120-180秒**: 遇到商店房（NPC对话教学），用初始金币购买第一个法术
- [ ] **玩家通过实践学习，无文字教程**
```

**核心原则**:
> "Show, don't tell. Let players discover, don't instruct."

### 阶段2：第一个"哇时刻"（3-5分钟）

**设计**: 击败第一个精英怪（特殊外观敌人），触发**慢镜头击杀特效** + **屏幕震动** + **金币暴雨动画**

```gdscript
## 精英怪击杀特效 - 添加到EnemyBase.gd

func _on_died() -> void:
  if is_elite:
    ## 慢镜头效果
    Engine.time_scale = 0.3
    await get_tree().create_timer(0.5).timeout
    Engine.time_scale = 1.0
    
    ## 屏幕震动
    if get_viewport().has_method("set_shake"):
      get_viewport().set_shake(10.0, 0.5)
    
    ## 金币暴雨
    for i in range(20):
      _spawn_coin_particle()
```

**玩家感受**: "这游戏太酷了！我想要更多这样的时刻！"

---

## 🎨 新手友好系统

### 1. 动态难度调整（Dynamic Difficulty）

**目的**: 前3局游戏降低难度，让玩家建立信心

```markdown
## Mechanic: 动态难度调整

**Purpose**: 新手期降低挫折感，老玩家保持挑战
**Player Fantasy**: "我正在变强"（即使实际是难度降低）

**Implementation**:
  - 检测玩家死亡次数
  - 前3次死亡：敌人伤害-20%，血量-30%
  - 连续失败5次：触发"怜悯模式"（敌人不会追击）

**Success Metric**: 
  - 新手前30分钟留存率 > 70%
  - 玩家平均死亡次数 < 5次（前3局）
```

### 2. 成就系统（新手向）

**第一局必触发的成就**:
- 🏆 **"初次探险"** - 完成第一个房间清除
- 🏆 **"法术学徒"** - 首次施放法术
- 🏆 **"闪避大师"** - 用翻滚躲避10次攻击
- 🏆 **"Boss杀手"** - 击败第一个Boss

**心理学原理**: 利用**成就多巴胺**促使玩家继续游戏

---

## 🎁 第二部份：后期留存策略（Long-term Retention）

### 设计支柱

1. **元游戏进度** - 每局游戏都有永久提升
2. **社交竞争** - 排行榜、好友挑战
3. **内容更新** - 每日/每周新内容
4. **收集驱动** - 图鉴、皮肤、成就

---

## 📊 元游戏进度系统（Meta-Progression）

### 1. 永久升级系统（Roguelike核心）

**设计**: 每局游戏结束后，用金币购买永久升级

```markdown
## Economy: 永久升级商店

**Currency**: 金币（每局游戏收集）
**Sinks**: 永久升级、皮肤、法术解锁

### 升级项目：
1. **最大生命值 +10** (Cost: 100金币)
2. **最大法力值 +20** (Cost: 150金币)
3. **移动速度 +5%** (Cost: 200金币)
4. **起始金币 +10** (Cost: 250金币)
5. **翻滚无敌时间 +0.1秒** (Cost: 300金币)
6. **法术伤害 +10%** (Cost: 500金币)

**Balancing**:
  - 每次升级效果递减（避免后期OP）
  - 总花费约5000金币（需要10-15局游戏）
  - 玩家感受到"明显进步"但不过于快速
```

### 2. 图鉴系统（Collection）

**设计**: 击败敌人后解锁图鉴条目，提供背景故事和掉落信息

```gdscript
## BestiaryEntry.gd - 敌人图鉴条目

class_name BestiaryEntry
extends Resource

@export var enemy_name: String
@export var description: String
@export var hp: float
@export var damage: float
@export var drop_table: Dictionary  ## 掉落表
@export var unlocked: bool = false
@export var kill_count: int = 0  ## 击杀计数

func register_kill() -> void:
  kill_count += 1
  if kill_count >= 1:
    unlocked = true  ## 首次击杀解锁图鉴
```

**玩家动机**: 
- **收集癖**: "我要解锁所有敌人图鉴！"
- **信息优势**: "了解敌人弱点，下次更好打"

---

## 🏆 社交与竞争系统

### 1. 排行榜系统（Leaderboard）

**设计**: 每日/每周挑战，排名前100名获得奖励

```markdown
## Feature: 排行榜系统

**Categories**:
  - 最高分数（单局）
  - 最快Boss击杀时间
  - 最多金币收集（单局）
  - 最长生存时间

**Rewards** (每周重置):
  - 前10名：500金币 + 专属皮肤
  - 前100名：200金币
  - 参与奖：50金币

**Psychological Triggers**:
  - **社交比较**: "我的朋友比我高！"
  - **损失厌恶**: "如果这周不玩，我会错过奖励"
```

### 2. 好友挑战系统

**设计**: 与好友 compare 分数，发起1v1挑战

```gdscript
## FriendChallenge.gd

func send_challenge(friend_id: String, my_score: int) -> void:
  ## 发送挑战给好友
  ## 好友看到："你的朋友XXX获得了1000分，你能超过他吗？"
  pass
```

---

## 📅 内容更新策略（Live Ops）

### 每日挑战（Daily Challenge）

**设计**: 每天固定种子生成地牢，所有玩家挑战相同地图

```markdown
## Daily Challenge Mechanics

**Same Seed**: 所有玩家同一天玩相同地牢
**Leaderboard**: 每日独立排行榜
**Rewards**: 
  - 参与：50金币
  - 前50%：100金币
  - 前10%：300金币 + 专属称号

**Retention Impact**: 
  - 玩家每天登录至少1次
  - 社交话题："今天的每日挑战你打了多少分？"
```

### 每周活动（Weekly Event）

**主题示例**:
- **"法术周"** - 所有法术消耗-50%
- **"生存周"** - 敌人数量x2，但掉落x3
- **"Boss Rush"** - 连续挑战5个Boss，无休息

---

## 🎨 视觉进度反馈

### 1. 玩家成长可视化

**设计**: 主菜单显示玩家统计

```
┌─────────────────────────────┐
│  玩家等级: 12              │
│  ████████░░░░ 80% → 13级 │
│                             │
│  统计:                     │
│  - 总击杀: 1,234          │
│  - 最长生存: 15分32秒      │
│  - 最远楼层: 8            │
│  - 解锁法术: 4/10         │
└─────────────────────────────┘
```

### 2. 每局游戏结束屏幕

**设计**: 显示本局统计 + 永久进度提升

```gdscript
## RunSummaryScreen.gd

func show_summary(run_data: Dictionary) -> void:
  ## 显示：
  ## - 本局分数
  ## - 击杀数
  ## - 收集金币
  ## - 永久升级可用金币
  ## - "再玩一局"按钮（默认焦点）
```

---

## 📈 数据驱动的平衡调整

### 关键指标监控

```markdown
## Metrics to Track

**Onboarding**:
  - 新手教程完成率: Target > 85%
  - 前3分钟流失率: Target < 30%

**Retention**:
  - Day-1留存: Target > 40%
  - Day-7留存: Target > 15%
  - 平均游戏局数/天: Target > 3

**Monetization (if applicable)**:
  - ARPPU: Target > $5
  - 付费转化率: Target > 2%

**Balance**:
  - 平均通关时间: Target 15-25分钟
  - 失败率（某房间）: Target 20-40%
```

---

## 🚨 实施优先级

### Week 1-2: 核心留存系统
- [ ] 永久升级商店
- [ ] 成就系统（基础10个）
- [ ] 游戏结束统计屏幕

### Week 3-4: 社交功能
- [ ] 排行榜（本地高分）
- [ ] 好友挑战（基础版）

### Week 5-6: 内容更新
- [ ] 每日挑战系统
- [ ] 每周活动框架

### Week 7+: 长期运营
- [ ] 新法术/敌人（每月更新）
- [ ] 季节性活动（万圣节、圣诞节皮肤）

---

## 📝 设计注释

**假设**:
- 玩家平均游戏局数：每天3-5局
- 每局游戏时长：15-25分钟
- 玩家愿意花费10-15小时达到"满级"

**风险**:
- ⚠️ 永久升级可能导致"Pay to Win"感 → 解决方案：仅出售皮肤和非数值道具
- ⚠️ 排行榜可能导致新手挫败 → 解决方案：分段排行榜（新手/专家）

**待Playtest验证**:
- [ ] 永久升级价格曲线是否合理？
- [ ] 每日挑战是否能驱动日活？
- [ ] 社交功能是否真的提升留存？

---

**版本记录**:
- v0.1 (2026-06-08): 初始设计 - GameDesigner
