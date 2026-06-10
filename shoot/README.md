# Soul Rogue — 元气骑士风格肉鸽地牢射击游戏

> Godot 4.x | GDScript 2.0 | 组件化架构 | 信号驱动

## 架构设计

```
scripts/
├── autoload/
│   ├── GameEvents.gd      # 全局事件总线（信号解耦）
│   └── GameManager.gd     # 游戏状态管理单例
├── components/
│   └── HealthComponent.gd # 可复用生命值组件
└── core/
    ├── WeaponData.gd      # 武器数据资源（ScriptableObject等价）
    └── DungeonGenerator.gd # 地牢随机生成器（BSP/随机游走）

scenes/
├── Main.tscn               # 主场景（地牢+玩家+UI）
├── player/
│   └── Player.tscn/.gd    # 玩家角色（移动/射击/翻滚/受伤）
├── enemies/
│   └── EnemyBase.tscn/.gd # 敌人基类（追踪/近战/远程）
├── weapons/
│   ├── Projectile.tscn/.gd      # 玩家子弹
│   └── EnemyProjectile.tscn/.gd # 敌人子弹
└── rooms/
    ├── Room.gd                  # 房间控制器（清房/开门逻辑）
    └── RoomTemplate.tscn        # 房间模板场景
```

## 核心特性
- **组件化架构**：`HealthComponent` 可挂载到任何节点，零继承
- **信号驱动**：跨节点通信全部通过 `GameEvents` Autoload，无直接引用
- **静态类型**：所有 GDScript 2.0 变量/函数均有显式类型
- **肉鸽地牢生成**：`DungeonGenerator` 随机游走算法生成连通房间图
- **房间战斗**：进入房间自动关门，清房后开门
- **武器系统**：`WeaponData` 资源驱动，支持多武器切换

## 操作方法
| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| 鼠标瞄准 + 左键 | 射击 |
| Space | 翻滚（无敌帧） |
| E | 互动 |
| ESC | 暂停 |

## 快速开始
1. 用 Godot 4.3+ 打开本项目目录
2. 确认 Autoload：`GameEvents.gd` 和 `GameManager.gd` 已注册
3. 点击 `scenes/Main.tscn` 运行（F5）
4. 替换占位素材（`icon.png` 为玩家精灵，补充动画帧）

## 下一步扩展建议
- [ ] 补充 `AnimatedSprite2D` 动画帧（idle/run/roll/hurt/death）
- [ ] 实现 `WeaponSystem.gd`（武器拾取/切换/冷却）
- [ ] 实现道具/宝箱系统（`ItemData` + `ItemPickup`）
- [ ] 实现 Boss 房与 Boss AI
- [ ] 实现道具商店（通关后货币消费）
- [ ] 添加音效与 BGM（使用 `AudioStreamPlayer2D`）

---
*由 GodotGameplayScripter Agent 生成，严格遵循 GDScript 2.0 静态类型规范与组件化架构。*
