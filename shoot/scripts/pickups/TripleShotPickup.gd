## 三发子弹拾取物 — 散弹枪模型，浮动旋转动画
extends CSGCombiner3D

class_name TripleShotPickup

signal picked_up()

## 浮动参数
@export var float_amplitude: float = 0.2
@export var float_speed: float = 1.5
@export var rotation_speed: float = 45.0

var _initial_position: Vector3 = Vector3.ZERO
var _time: float = 0.0


func _ready() -> void:
	_initial_position = global_position
	
	## 连接拾取检测
	var pickup_area: Area3D = get_node_or_null("PickupArea")
	if pickup_area:
		pickup_area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	
	## 浮动动画
	var float_offset: float = sin(_time * float_speed) * float_amplitude
	global_position.y = _initial_position.y + float_offset
	
	## 旋转动画
	rotate_y(deg_to_rad(rotation_speed * delta))


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	
	## 启用三发子弹
	if body.has_method("enable_triple_shot"):
		body.enable_triple_shot()
	elif "triple_shot_enabled" in body:
		body.triple_shot_enabled = true
	
	## 发送拾取信号
	picked_up.emit()
	
	## 移除拾取物
	queue_free()
