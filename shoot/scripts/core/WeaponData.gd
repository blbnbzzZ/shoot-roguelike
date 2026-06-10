## 武器数据资源 — 类似 Unity ScriptableObject
## 在编辑器中创建 .tres 资源实例，配置每种武器参数
class_name WeaponData
extends Resource

@export var display_name: String = "Pistol"
@export var damage: float = 10.0
@export var fire_rate: float = 0.2
@export var projectile_speed: float = 600.0
@export var projectile_lifetime: float = 2.0
@export var spread: float = 0.0
@export var projectile_count: int = 1
@export var pierce: int = 0
@export var sprite_texture: Texture2D
@export_multiline var description: String = ""
