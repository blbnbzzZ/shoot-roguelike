## 门组件 — 挂载到 Room/Doors/ 下的每个门节点
## 支持 open()/close() 方法，控制碰撞和可见性
class_name Door
extends Area3D

signal door_opened(door: Door)
signal door_closed(door: Door)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

var _is_open: bool = false
var _is_locked: bool = false


func _ready() -> void:
	## 初始状态：关闭
	close()


func open() -> void:
	if _is_open or _is_locked:
		return
	_is_open = true

	## 禁用碰撞
	if collision_shape:
		collision_shape.disabled = true

	## 隐藏网格
	if mesh_instance:
		mesh_instance.visible = false

	## 播放动画（如果有）
	if animation_player and animation_player.has_animation("open"):
		animation_player.play("open")

	door_opened.emit(self)


func close() -> void:
	if not _is_open:
		return
	_is_open = false

	## 启用碰撞
	if collision_shape:
		collision_shape.disabled = false

	## 显示网格
	if mesh_instance:
		mesh_instance.visible = true

	## 播放动画
	if animation_player and animation_player.has_animation("close"):
		animation_player.play("close")

	door_closed.emit(self)


func is_open() -> bool:
	return _is_open


func set_locked(locked: bool) -> void:
	_is_locked = locked
	if locked and not _is_open:
		close()


func _on_body_entered(body: Node) -> void:
	## 可扩展：玩家触碰到门时自动开门（用于出口）
	pass
