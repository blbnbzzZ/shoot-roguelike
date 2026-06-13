## 3D 血包 — 十字造型，平滑浮动旋转动画
extends CSGCombiner3D

class_name HealthPack3D

signal picked_up()

@export var heal_amount: float = 25.0
@export var float_amplitude: float = 0.15  ## 浮动幅度
@export var float_speed: float = 2.0  ## 浮动速度
@export var rotation_speed: float = 60.0  ## 旋转速度（度/秒）

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
	
	## 平滑浮动动画（正弦波）
	var float_offset: float = sin(_time * float_speed) * float_amplitude
	global_position.y = _initial_position.y + float_offset
	
	## 平滑旋转动画（Y轴）
	rotate_y(deg_to_rad(rotation_speed * delta))


func _on_body_entered(body: Node3D) -> void:
	## 检测是否是玩家
	if not body.is_in_group("player"):
		return
	
	## 治疗玩家
	var health_comp = body.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("heal"):
		health_comp.heal(heal_amount)
	elif health_comp and "current_health" in health_comp:
		health_comp.current_health = mini(
			health_comp.current_health + heal_amount,
			health_comp.max_health
		)
	
	## 发送拾取信号
	picked_up.emit()
	
	## 播放拾取特效（可选）
	_play_pickup_effect()
	
	## 移除血包
	queue_free()


func _play_pickup_effect() -> void:
	## 可以在这里添加粒子特效或音效
	## 例如：生成拾取粒子
	pass


func set_heal_amount(amount: float) -> void:
	heal_amount = amount
