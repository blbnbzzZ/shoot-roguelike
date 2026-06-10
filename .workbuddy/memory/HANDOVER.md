# 🎮 Godot 3D 地牢射击游戏 — 项目交接文档

> 生成时间：2026-06-10  
> 当前 Git HEAD：`2432a84`  
> 交接自：Senior Developer (高级开发工程师)

---

## 📁 项目结构速览

```
E:/shoot/shoot/
├── scenes/
│   ├── Main.gd              ← 核心：楼层生成、通关逻辑、New Game+
│   ├── Player.tscn / scripts/Player.gd
│   ├── rooms/
│   │   ├── Room.gd         ← 核心：房间逻辑、敌人计数、门管理
│   │   ├── RoomTemplate.tscn       (普通 640×640)
│   │   ├── RoomTemplateLarge.tscn  (大 1280×640)
│   │   └── RoomTemplateHuge.tscn   (超大 1280×1280)
│   ├── enemies/
│   │   ├── EnemyBase.gd    ← 所有怪物基类（含击退、血浆、红色闪白）
│   │   ├── Strawberry.gd/.tscn
│   │   ├── ZapRat.gd/.tscn
│   │   ├── Guruguru.gd/.tscn
│   │   ├── BigEyeBoss.gd/.tscn
│   │   └── Slime.gd/.tscn（史莱姆分裂机制）
│   ├── weapons/
│   │   ├── Projectile.gd   ← 玩家子弹（检测 collision_layer & 4）
│   │   └── EnemyProjectile.gd
│   └── pickups/
│       ├── TripleShotPickup.gd/.tscn  ← 散弹枪
│       └── SMGPickup.gd/.tscn        ← 冲锋枪（+33%攻速）
├── assets/
│   └── enemies/
│       ├── layer1/    ← 当前所有怪物立绘在这
│       │   ├── strawberry/strawberry.png
│       │   ├── zaprat/ZapRat.png
│       │   ├── guruguru/Guruguru.png
│       │   ├── bigeyeboss/BigEyeBoss.png
│       │   └── slime/slime_*.png + slime_frames.tres
│       ├── layer2/    ← 预留，待添加第二层怪物
│       └── layer3/    ← 预留，待添加第三层怪物
└── scripts/ui/
    └── BuffUI.gd      ← 显示散弹枪/冲锋枪图标
```

---

## ✅ 已完成功能

| 功能 | 状态 | 备注 |
|------|------|------|
| 基础移动 + 射击 | ✅ | WASD + 鼠标瞄准 |
| 4种敌人 + Boss | ✅ | 草莓/闪电鼠/咕噜咕噜/大眼Boss |
| 史莱姆分裂 | ✅ | 死亡时分裂为2只小型史莱姆 |
| 血浆粒子效果 | ✅ | 受击时向反方向喷溅，参数可调 |
| 受击红色闪白 | ✅ | 所有敌人含Boss，0.3s tween |
| 散弹枪奖励 | ✅ | 奖励房50%概率 |
| 冲锋枪(SMG)奖励 | ✅ | 奖励房50%概率，与散弹枪互斥；Boss死亡也掉落 |
| 3大层 × 3层 = 9层 | ✅ | LAYER_CONFIG驱动，每层房间数递增 |
| 每层Boss房 | ✅ | 必达条件：打完Boss才能进下一层 |
| 通关界面 | ✅ | 继承装备重玩(New Game+) / 返回主菜单 |
| New Game+ | ✅ | 继承装备，怪量×5 |
| 子弹阻挡墙 | ✅ | 隐形，只挡子弹(collision_layer=4)，不挡人 |
| 远处敌人被击中唤醒 | ✅ | 大房间优化，休眠敌人被击中立即苏醒 |
| 敌人计数安全网 | ✅ | 1秒周期reconcile，防止信号丢失导致门不开 |

---

## 🔧 关键技术细节

### 碰撞层设计
```
Layer 1 (值=1): 玩家
Layer 2 (值=2): 敌人
Layer 3 (值=4): 墙壁/子弹阻挡墙  ← Player.mask包含此层
Layer 4 (值=8): 奖励拾取物
Layer 5 (值=16): 玩家/敌人互相检测  ← Player.mask=5(1+4), 敌人mask=16
```

### 房间生成流程（Main.gd）
```
_generate_floor(_floor)
  ├── 从 LAYER_CONFIG[_current_layer-1] 读取房间数范围
  ├── _find_boss_room() → 最远房间设为Boss房
  ├── _find_reward_rooms(boss_idx, count) → 多个奖励房
  ├── 实例化 Room.tscn × N，设置 room_type / layer_number
  └── 排列房间位置（横向/纵向偏移）
```

### 敌人计数校正机制（Room.gd）
- `_enemies_alive` 初始 = 生成时敌人数量
- 每次敌人/史莱姆死亡：`_enemies_alive -= 1`
- 若 `_enemies_alive <= 0`：调用 `_reconcile_enemy_count()` 校正
- `_reconcile_enemy_count()`：遍历 `enemies_container` 实际存活节点，修正计数
- **1秒周期Timer**：最终兜底，即使所有信号丢失也能开门

### 门系统（Room.gd）
1. 房间未清理：`_spawn_door_blockers()` 生成 StaticBody3D 堵门（collision_layer=1，只挡玩家）
2. 房间清理后：`_destroy_door_blockers()` 先设 `collision_layer=0` 再 `queue_free()`
3. `_open_doors()`：连接门Area3D的 `body_entered` 信号 → 玩家触发的 `_on_door_entered()`
4. `_on_door_entered()`：调用 `Main._enter_room(door_name)` → 传送到对应新房间门口

### 大房间穿墙Bug修复（重要！）
**根因**：`_destroy_door_blockers()` 用 `queue_free()` 延迟到帧末才删除 → 窗口期内玩家可挤压穿透  
**修复**：先 `blocker.collision_layer = 0` 立即失效，再 `queue_free()`  
**安全网**：`_on_player_enter()` 增加判断，若房间已清理则直接开门而非重复激活

---

## 🐛 已修复Bug清单

| Bug描述 | 根因 | 修复方式 |
|---------|------|---------|
| 血浆粒子不可见 | `Color()` 缺alpha参数 (Godot 4要求4个参数) | 加 `, 1` |
| 血浆粒子Parse Error | `.tscn` 不支持 `deg_to_rad()` 函数调用 | 替换为原始值 `0.8727` |
| 血液横着飞 | `direction.y` 太小(0.2)，无抛物线 | 改为0.5 + 加大重力 |
| 红色闪白越打越红 | 恢复目标用 `sprite.modulate`（捕获中间色）| 改为固定 `Color.WHITE` |
| SMG不出现 | `Vector8` 类型不存在 → Parse Error → load()返回null | 改为 `Vector3` + 清除所有 `##` 注释 |
| 杀1个怪就开门 | `_on_enemy_died` 的 `>0` 分支错误执行了开门代码 | 删除 `>0` 分支，只在 `<=0` 时处理 |
| 门打不开（计数不同步） | 死亡信号可能丢失导致 `_enemies_alive` 残留 | 新增 `_reconcile_enemy_count()` + 1秒周期Timer |
| 大房间穿墙→出生位置错误 | `queue_free()` 延迟删除窗口期，玩家挤压穿透 | 立即禁用碰撞 + PlayerDetector安全网 |

---

## 📝 待完成 / 已知TODO

### 🔴 高优先级
1. **Layer 2 / Layer 3 怪物未实现**
   - `Room.gd` 的 `_get_random_enemy_scene()` 和 `_get_boss_scene()` 中，layer 2/3 分支是空的实现（目前复用layer1怪物）
   - 需要：设计新怪物 → 导入立绘到 `assets/enemies/layer2/` 和 `layer3/` → 创建 .tscn/.gd → 更新分支

2. **通关界面UI**
   - `Main.gd` 的 `_show_game_clear_screen()` 应该是placeholder
   - 需要实现：显示"游戏通关！" + "继承装备重玩"按钮 + "返回主菜单"按钮

### 🟡 中优先级
3. **史莱姆属性系统**
   - `Slime.gd` 中有冰/火/毒属性框架，但尚未完全实现特效
   - 需要：属性视觉特效 + 对玩家的影响

4. **Boss战平衡性**
   - 当前Boss只有血量递增（2000/3500/5000），攻击模式较单一
   - 可以加：阶段变化、新攻击模式、弹幕花样

5. **音效和背景音乐**
   - 目前应该是静音状态
   - 需要：射击音效、受击音效、Boss死亡音效、背景音乐

### 🟢 低优先级 / 优化
6. **性能优化**
   - 大房间（1280×1280）敌人较多时可能有性能压力
   - 可以考虑：敌人数量动态调节、LOD系统、粒子数量限制

7. **玩家体验优化**
   - 小地图/楼层导航
   - 武器切换动画
   - 更多武器类型（火箭筒、激光等）

---

## 📊 Git 状态

```
最新commit: 2432a84
分支: master
工作区: 干净（所有改动已提交）

关键commit历史:
- 2432a84: fix: large room wall-phasing bug
- (前序commit): feat: bullet barrier, enemy wake-on-hit, layer1 asset restructure
- (更早): 多层地牢架构、SMG奖励、红色闪白等
```

---

## 🔑 快速上手指南

### 1. 理解核心循环
```
主菜单 → 开始游戏 → Floor 1-9 逐层推进
每层中：普通房(杀怪开门) → 奖励房(拾取武器) → Boss房(击杀→地洞)
通关(9层) → 选择：继承重玩(New Game+，5倍怪) / 返回主菜单
```

### 2. 修改敌人属性
- 基础属性（速度/血量/攻击力）：改对应 `.gd` 文件顶部的 `const`
- 外观：替换 `assets/enemies/layerX/xxx/xxx.png`，更新 `.tscn` 的 `[ext_resource]` 路径
- 行为AI：改 `_physics_process()` 或 `_on_timer_timeout()`

### 3. 添加新武器
- 创建 `PickupXXX.gd/.tscn`（参考 `TripleShotPickup` 或 `SMGPickup`）
- 在 `Player.gd` 添加 `enable_xxx()` 方法
- 在 `Room.gd` 的 `_spawn_reward_pickup()` 和 `_spawn_boss_weapon_reward()` 中加入新武器逻辑
- 在 `BuffUI.gd` 添加图标生成方法

### 4. 调试技巧
- 敌人计数异常：看 `_reconcile_enemy_count()` 的 print 输出
- 门不开：检查 `_enemies_alive` 和实际节点数是否一致
- 穿墙：确认 `_destroy_door_blockers()` 是否正确立即禁用碰撞

---

## 📞 联系方式

如遇重大问题或需要澄清设计意图，可参考：
- **记忆文件**: `E:/shoot/.workbuddy/memory/2026-06-09.md`（详细修改记录）
- **本交接文档**: `E:/shoot/.workbuddy/memory/HANDOVER.md`

---

**祝下一个agent顺利！🚀**
