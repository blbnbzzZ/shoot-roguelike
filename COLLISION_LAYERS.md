## 碰撞层设计（3D Physics）
##
## Layer 1  = Player       (CharacterBody3D)
## Layer 2  = Enemy        (CharacterBody3D)
## Layer 4  = PlayerHurt   (Area3D HurtBox)
## Layer 8  = EnemyHurt    (Area3D HurtBox)
## Layer 16 = Wall         (StaticBody3D)
## Layer 32 = Item         (Area3D)

## 各场景碰撞设置：

## Player.tscn（CharacterBody3D）
##   collision_layer = 1
##   collision_mask = 16         （只碰墙）

## EnemyBase.tscn（CharacterBody3D）
##   collision_layer = 2
##   collision_mask = 16         （只碰墙）

## Projectile.tscn（玩家子弹 Area3D）
##   根节点 collision_layer = 8   （玩家子弹层）
##   根节点 collision_mask  = 2   （打敌人身体）
##   HurtBox collision_layer = 0
##   HurtBox collision_mask  = 8   （检测敌人受击框，用于信号）

## EnemyProjectile.tscn（敌人子弹 Area3D）
##   根节点 collision_layer = 16
##   根节点 collision_mask  = 1   （打玩家身体）
##   HurtBox collision_layer = 0
##   HurtBox collision_mask  = 4   （检测玩家受击框）

## RoomTemplate.tscn（墙 StaticBody3D）
##   collision_layer = 16
##   collision_mask = 0

## HealthPickup.tscn（拾取物 Area3D）
##   collision_layer = 32
##   collision_mask = 1           （只检测玩家碰触）
