# Soul Rogue — 元气骑士风格肉鸽地牢射击游戏

## 项目概述
这是一个使用 Godot 4.3+ 和 GDScript 2.0 开发的 2D 平面肉鸽地牢射击游戏，玩法类似《元气骑士》。采用严格的组件化架构和静态类型系统。

## 核心架构

### 设计原则
- **组件化优于继承**：行为通过挂载 Node 组件实现
- **信号驱动通信**：跨节点通过 `GameEvents` Autoload 解耦
- **静态类型安全**：所有变量/函数均有显式类型声明
- **场景可独立运行**：每个场景可 F6 独立测试

### 文件结构
```
scripts/
├── autoload/
│   ├── GameEvents.gd      # 全局事件总线
│   └── GameManager.gd     # 游戏状态管理单例
├── components/
│   ├── HealthComponent.gd # 可复用生命值组件
│   ├── WeaponSystem.gd    # 武器系统组件
│   └── Door.gd            # 门控制组件
└── core/
    ├── WeaponData.gd      # 武器数据资源 (ScriptableObject)
    └── DungeonGenerator.gd # 地牢随机生成器

scenes/
├── Main.tscn/.gd           # 主场景控制器
├── player/
│   └── Player.tscn/.gd    # 玩家角色
├── enemies/
│   └── EnemyBase.tscn/.gd # 敌人基类
├── weapons/
│   ├── Projectile.tscn/.gd      # 玩家子弹
│   └── EnemyProjectile.tscn/.gd # 敌人子弹
└── rooms/
    ├── Room.gd                  # 房间控制器
    └── RoomTemplate.tscn        # 房间模板
```

## 已实现功能

### 玩家系统
- [x] WASD 移动控制
- [x] 鼠标瞄准 + 左键射击
- [x] 翻滚闪避（无敌帧）
- [x] 受伤无敌时间
- [x] 生命值组件（可复用）

### 战斗系统
- [x] 子弹投射物系统
- [x] 敌人 AI（追踪/近战/远程）
- [x] 伤害计算与生命值管理
- [x] 武器数据驱动系统

### 地牢系统
- [x] 随机游走算法生成房间
- [x] 房间连通图生成
- [x] 房间控制器（清房/开门逻辑）
- [x] 门系统（开关控制）

### UI 系统
- [x] 生命值血条
- [x] 金币计数器
- [x] 分数显示
- [x] 暂停叠加层

## 输入映射 (project.godot)
| 动作 | 按键 | 游戏手柄 |
|------|------|----------|
| 移动 | WASD | 左摇杆 |
| 射击 | 鼠标左键 | A 键 |
| 翻滚 | Space | B 键 |
| 互动 | E | X 键 |
| 暂停 | ESC | Start |

## 技术亮点

### 1. 组件化架构
```gdscript
# 玩家节点树
Player (CharacterBody2D)
├── HealthComponent (Node)
├── WeaponSystem (Node)
├── AnimatedSprite2D
├── Muzzle (Marker2D)
├── Hitbox (Area2D)
├── HurtTimer (Timer)
└── RollTimer (Timer)
```

### 2. 信号驱动通信
```gdscript
# 错误做法：直接引用
player.health_comp.apply_damage(10)

# 正确做法：信号解耦
GameEvents.player_hurt.emit(10)
# 其他系统通过信号响应
```

### 3. 静态类型安全
```gdscript
# 所有变量均有类型声明
var _current_health: float = 0.0
var _fire_timer: float = 0.0
var _player: Node2D = null
var _state: State = State.NORMAL
```

### 4. 数据驱动武器系统
```gdscript
# WeaponData.gd (Resource)
@export var display_name: String = "Pistol"
@export var damage: float = 10.0
@export var fire_rate: float = 0.2
@export var projectile_count: int = 1
@export var spread: float = 0.0
```

## 如何运行

1. 打开 Godot 4.3+ 编辑器
2. 导入项目目录：`C:\Users\blbnb\WorkBuddy\2026-06-03-17-54-36`
3. 确认 Autoload 设置：
   - `GameEvents.gd` → Autoload 名称 `GameEvents`
   - `GameManager.gd` → Autoload 名称 `GameManager`
4. 运行 `scenes/Main.tscn`（按 F5）
5. 替换占位素材（`icon.png`）

## 下一步开发计划

### 高优先级
- [ ] 补充玩家/敌人动画帧（idle/run/attack/death）
- [ ] 实现武器拾取系统（地面武器精灵 + 碰撞检测）
- [ ] 实现道具/宝箱系统（`ItemData` + `ItemPickup`）
- [ ] 添加音效与 BGM（`AudioStreamPlayer2D`）

### 中优先级
- [ ] 实现 Boss 房与 Boss AI
- [ ] 实现房间类型多样性（普通/精英/Boss/商店）
- [ ] 实现角色选择系统
- [ ] 实现存档系统（加密 JSON）

### 低优先级
- [ ] 实现联机多人模式（WebSocket）
- [ ] 实现 MOD 支持（外部脚本加载）
- [ ] 实现地图编辑器（导出/导入 JSON）

## 性能优化建议

1. **对象池**：子弹/敌人使用对象池回收而非 `queue_free()`
2. **碰撞优化**：合理设置 `collision_layer`/`collision_mask`
3. **灯光优化**：使用 `CanvasModulate` 替代多盏 `PointLight2D`
4. **动画优化**：使用 `AnimationPlayer` 替代代码驱动动画

## 故障排除

### 常见问题

**Q: 运行后玩家不显示？**  
A: 检查 `Player.tscn` 中 `AnimatedSprite2D` 的 `texture` 属性是否赋值

**Q: 子弹不伤害敌人？**  
A: 检查碰撞层设置：玩家子弹 layer=4，敌人 mask=4

**Q: 地牢生成后看不到房间？**  
A: 检查 `DungeonGenerator.room_templates` 是否分配了房间场景

**Q: 输入无响应？**  
A: 检查 `project.godot` 中输入映射是否正确加载

## 扩展阅读

- [Godot 4 官方文档](https://docs.godotengine.org/)
- [GDScript 2.0 静态类型指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [信号与事件系统](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html)
- [组件化架构模式](https://www.youtube.com/watch?v=rCu8vQrdDDI)

---
*由 GodotGameplayScripter Agent 生成于 2026-06-03*  
*遵循 GDScript 2.0 静态类型规范与组件化架构*
