## 冲锋枪拾取物 — 攻速+33%，浮动旋转动画
extends CSGCombiner3D

class_name SMGPickup

signal picked_up()

## 浮动参数
@export var float_amplitude: float = 0.2
@export var float_speed: float = 2.0   ## 比散弹枪稍快，更有活力感
@export var rotation_speed: float = 60.0  ## 转得比散弹枪快

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

	## 启用冲锋枪攻速增益
	if body.has_method("enable_smg"):
		body.enable_smg()
	elif "smg_enabled" in body:
		body.smg_enabled = true

	## 发送拾取信号
	picked_up.emit()

	## 移除拾取物
	queue_free()
