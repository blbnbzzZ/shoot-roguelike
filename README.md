# 🎮 地牢射击 Roguelike - AI 完全开发

> **完全由 AI 开发的俯视角肉鸽地牢射击游戏**  
> 类似《元气骑士》的爽快战斗体验 · 9层地牢挑战 · 多Boss战

![Godot 4.6.3](https://img.shields.io/badge/Godot-4.6.3-blue?logo=godot-engine)
![AI Developed](https://img.shields.io/badge/AI%20Developed-80%25-green?logo=openai)
![License](https://img.shields.io/badge/license-MIT-orange)

---

## 📖 项目介绍

这是一个**由 AI (WorkBuddy + GPT) 辅助开发**的俯视角肉鸽地牢射击游戏。项目从零开始，包括游戏设计、代码编写、Bug调试、平衡性调整等大部分由 AI 完成，展示了 AI 独立开发游戏的潜力。

**游戏类型**: 俯视角射击 + Roguelike + 地牢探索  
**类似作品**: 《元气骑士》、《Enter the Gungeon》  
**开发工具**: Godot 4.6.3 Stable  
**AI 参与度**: 80% (设计 + 代码 + 调试)

---

##  开发图片展示
<img width="875" height="470" alt="image" src="https://github.com/user-attachments/assets/2d5dd5b1-7fb6-477d-95f9-5cb0aef331cb" />
<img width="875" height="470" alt="image" src="https://github.com/user-attachments/assets/ba6e160c-3eb4-481a-a68d-2be7228e47d8" />
<img width="875" height="470" alt="image" src="https://github.com/user-attachments/assets/606c07df-c2e3-43aa-8d02-4dd739685479" />
<img width="875" height="470" alt="image" src="https://github.com/user-attachments/assets/ea10955a-2de7-4186-bdeb-711bdcd63b2b" />
<img width="875" height="470" alt="image" src="https://github.com/user-attachments/assets/fe10e6e1-36b4-4c94-a6e3-ea3682bcafd0" />

---

## 🎯 核心玩法

### 🏰 地牢结构
- **9层地牢**：分为3大层，每大层包含3个子层
- **随机房间生成**：每次游玩地图布局不同
- **房间类型**：普通房间、精英房间、Boss房间、奖励房间

### ⚔️ 战斗系统
- **流畅的射击手感**：鼠标瞄准 + WASD移动
- **多重射击能力**：三重射击、SMG快速射击
- **达姆弹系统**：拾取后增加25%基础伤害

### 👾 敌人系统
- **多种敌人类型**：史莱姆、大眼、籽籽敌人等
- **Boss战**：
  - 🟢 **史莱姆王**：扇形子弹攻击，可调整攻击前摇
  - 👁️ **大眼Boss**：2-3层专属Boss
  - 🪱 **虫子Boss**：15节身体，打断关节后分裂为两条独立虫子

### 🎁 奖励系统
奖励房间提供三选一奖励：
1. **Shotgun**：霰弹枪，近距离高伤害
2. **SMG**：冲锋枪，快速连射
3. **达姆弹**：永久增加25%基础伤害

---

## ✨ 项目优点

### 🤖 AI 开发
- **80% AI 生成代码**：从游戏设计到Bug修复，大部分由 AI 完成
- **快速迭代**：AI 可以在几分钟内完成复杂功能的实现和调试
- **可复现性**：展示 AI 开发游戏的完整流程，可供学习参考

### 🎮 游戏特色
- **流畅的战斗体验**：经过多次调试优化手感流畅
- **丰富的Boss战**：每个Boss都有独特的攻击模式和阶段变化
- **Roguelike元素**：随机房间、随机奖励，每次游玩都有新鲜感

### 🛠️ 技术亮点
- **组件化设计**：HealthComponent、Pickup系统等高可复用组件
- **灵活的房间系统**：支持不同大小房间（小房间、大房间、巨大房间）
- **精确的碰撞检测**：优化子弹与墙体的碰撞逻辑
- **动态Boss生成**：第一大层Boss不重复随机生成

---

## 🚧 缺失内容与待更新

### 🐛 已知问题
- [ ] 部分动画还未实装
- [ ] 虫子Boss模型高度与碰撞箱对齐需进一步优化
- [ ] 门通路逻辑在极端情况下可能卡住

### 🎨 美术与音效
- [ ] 缺少背景音乐
- [ ] 部分技能特效需要完善
- [ ] UI界面可以进一步美化

### 🎯 玩法扩展
- [ ] 更多武器类型（激光、火箭筒等）
- [ ] 角色选择系统
- [ ] 技能升级树
- [ ] 更多敌人类型和Boss

### 📱 平台适配
- [ ] 触摸屏控制优化（计划上线微信小程序和抖音小游戏）
- [ ] 性能优化 for 移动端

---

## 🚀 如何运行

### 环境要求
- Godot 4.6.3 Stable 或更高版本
- Windows / macOS / Linux

### 运行步骤
1. 克隆本仓库：
   ```bash
   git clone https://github.com/你的用户名/仓库名.git
   ```
2. 用 Godot 4.6.3 打开项目文件夹
3. 点击"运行"按钮，开始游戏！

### 操作说明
- **WASD**：移动角色
- **鼠标左键**：射击
- **鼠标瞄准**：控制射击方向
- **E键**：拾取附近的道具

---

## 🤝 AI 开发过程

本项目是**AI独立开发游戏**的实验性项目，开发过程包括：

1. **游戏设计**：AI 根据"俯视角肉鸽地牢射击"的需求，设计游戏核心玩法和系统
2. **代码实现**：AI 编写所有GDScript代码，包括玩家控制、敌人AI、Boss机制等
3. **Bug调试**：AI 根据用户反馈（截图/视频）快速定位和修复问题
4. **平衡性调整**：AI 根据测试结果调整伤害、血量、掉落率等参数

**开发工具**：WorkBuddy (AI编程助手) + GPT-4  
**开发时间**：约2周（包括多次迭代和调试）  
**代码行数**：约5000+ 行GDScript代码

---

## 📂 项目结构

```
shoot/
├── scripts/          # GDScript脚本
│   ├── core/         # 核心系统（DungeonGenerator等）
│   ├── enemies/      # 敌人脚本
│   ├── player/       # 玩家脚本
│   ├── components/   # 可复用组件
│   └── ui/           # UI脚本
├── scenes/           # Godot场景文件
│   ├── rooms/        # 房间场景
│   ├── enemies/      # 敌人场景
│   └── pickups/      # 道具场景
├── assets/           # 美术资源
├── README.md         # 本文件
└── project.godot     # Godot项目配置
```

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- **Godot Engine**：开源游戏引擎
- **WorkBuddy**：AI编程助手
- **OpenAI**：GPT-4 模型

---

## 📧 联系方式

如果你对这个项目感兴趣，或者想了解更多关于AI开发游戏的信息，欢迎联系我！

**Boss直聘**: [你的Boss直聘账号]  
**邮箱**: [你的邮箱]

---

**⭐ 如果这个项目对你有帮助，欢迎给个Star！**
