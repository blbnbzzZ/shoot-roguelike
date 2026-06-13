## 玩家角色 3D 版本（Sprite3D + CharacterBody3D）
class_name Player
extends CharacterBody3D

signal died()
signal health_changed(current: float, max_hp: float)
signal triple_shot_activated()
signal smg_activated()  ## 冲锋枪攻速增益激活信号
signal dumdum_activated()  ## 达姆弹伤害增益激活信号

enum State { NORMAL, ROLLING, HURT, DEAD }
var _state: int = State.NORMAL

@export var move_speed: float = 120.0
@export var roll_speed: float = 260.0
@export var roll_duration: float = 0.25
@export var roll_cooldown: float = 1.0
@export var contact_damage: float = 15.0

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var health_comp: HealthComponent = $HealthComponent
@onready var muzzle: Marker3D = $Muzzle
@onready var interaction: Area3D = $Interaction
@onready var roll_timer: Timer = $RollTimer
@onready var roll_cd_timer: Timer = $RollCDTimer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var cam: Camera3D = $Camera3D

## 相机弧形缩放参数
const CAM_DIST_MIN: float = 150.0
const CAM_DIST_MAX: float = 600.0
const CAM_SCROLL_STEP: float = 40.0
const CAM_ANGLE_DEG: float = 60.0

var _target_cam_dist: float = 300.0

var _input_dir: Vector3 = Vector3.ZERO
var _facing_direction: Vector3 = Vector3.FORWARD
var _can_roll: bool = true
var _roll_timer: float = 0.0
var _is_firing: bool = false

var _state_timer: float = 0.0

var _mouse_world_pos: Vector3 = Vector3.ZERO
var _mouse_direction: Vector3 = Vector3.FORWARD

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/Projectile.tscn")

@export var fire_rate: float = 0.5
var _fire_cooldown: float = 0.0

## 三发子弹
var triple_shot_enabled: bool = false
var _triple_shot_angle: float = 30.0  ## 散弹角度（度）

## 冲锋枪攻速增益（拾取后攻速+33%，即冷却时间缩短为原来的2/3）
var smg_enabled: bool = false
const SMG_FIRE_RATE_MULT: float = 0.6667   ## 原始攻速的2/3
var _base_fire_rate: float = 0.5            ## 记录原始攻速，用于计算

## 达姆弹伤害增益（拾取后基础伤害+25%）
var dumdum_enabled: bool = false
const DUMDUM_DAMAGE_MULT: float = 1.25     ## 伤害倍率1.25
var _base_contact_damage: float = 15.0        ## 记录原始近战伤害（用于计算）

## 摄像机惯性
var _target_cam_height: float = 180.0
const CAM_SMOOTH_SPEED: float = 8.0

## 平滑摄像机效果参数（可手动调）
## 相机跟随延迟偏移：移动时相机稍微滞后，停顿时快速追上，更有电影感
var _cam_offset: Vector3 = Vector3.ZERO          ## 当前相机额外偏移量
const CAM_FOLLOW_LAG_SPEED: float = 5.0           ## 偏移跟随速度，越小越"拖影"
const CAM_OFFSET_MAX: float = 20.0               ## 最大偏移距离（世界单位）

## 相机震动（受伤时触发）
var _cam_shake_intensity: float = 0.0             ## 当前震动强度
var _cam_shake_time: float = 0.0                  ## 震动剩余时间
const CAM_SHAKE_DURATION: float = 0.25           ## 震动持续时间
const CAM_SHAKE_DECAY: float = 8.0                ## 震动衰减速度
const CAM_SHAKE_MAX_AMPLITUDE: float = 4.0       ## 震动最大幅度（世界单位）

## 开枪后坐力（轻微镜头回弹）
var _cam_recoil_offset: Vector3 = Vector3.ZERO    ## 后坐力偏移
const CAM_RECOIL_STRENGTH: float = 2.5            ## 后坐力强度
const CAM_RECOIL_DECAY: float = 15.0              ## 后坐力衰减速度

## 击退
var _knockback_velocity: Vector3 = Vector3.ZERO

## 冻结（进入新房间时短暂不能移动）
var _frozen: bool = false
var _freeze_timer: float = 0.0

## 无敌闪烁
var _invincible_timer: float = 0.0
const _INVINCIBLE_DURATION: float = 2.0
var _flash_timer: float = 0.0
const _FLASH_INTERVAL: float = 0.08


func _ready() -> void:
	add_to_group("player")
	health_comp.died.connect(_on_died)
	health_comp.health_changed.connect(func(c, m): health_changed.emit(c, m))
	health_comp.damaged.connect(_on_damaged)
	roll_timer.timeout.connect(_on_roll_end)
	roll_cd_timer.timeout.connect(func(): _can_roll = true)
	if cam:
		_target_cam_dist = cam.position.length()
	## 记录原始攻速和伤害
	_base_fire_rate = fire_rate
	_base_contact_damage = contact_damage
	## 注册到 DevMode（开发者模式）
	var dm = get_node_or_null("/root/DevMode")
	if dm and dm.has_method("register_player"):
		dm.register_player(self)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_attack") and _state != State.DEAD:
		_is_firing = true
		_try_fire()
	if event.is_action_released("ui_attack"):
		_is_firing = false
	if event.is_action_pressed("ui_roll") and _can_roll and _state == State.NORMAL:
		_enter_state(State.ROLLING)
		_can_roll = false
		roll_timer.start(roll_duration)
		roll_cd_timer.start(roll_cooldown)
	if event.is_action_pressed("ui_accept") and _state != State.DEAD:
		_try_interact()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_camera_height(-CAM_SCROLL_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_camera_height(CAM_SCROLL_STEP)


func _adjust_camera_height(delta_dist: float) -> void:
	if not cam:
		return
	_target_cam_dist = clampf(_target_cam_dist + delta_dist, CAM_DIST_MIN, CAM_DIST_MAX)


func _physics_process(delta: float) -> void:
	## 无敌闪烁逻辑
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		_flash_timer += delta
		if _flash_timer >= _FLASH_INTERVAL:
			_flash_timer = 0.0
			sprite.visible = !sprite.visible
		if _invincible_timer <= 0.0:
			health_comp.invincible = false
			sprite.visible = true

	## 平滑摄像机效果：跟随延迟 + 震动 + 后坐力
	if cam:
		var target_pos: Vector3 = _get_camera_arc_position(_target_cam_dist)

		## 1. 跟随延迟：根据玩家速度方向产生偏移（移动时相机滞后，停顿时追上）
		var velocity_flat: Vector3 = Vector3(velocity.x, 0, velocity.z)
		var target_offset: Vector3 = -velocity_flat * (0.15 / move_speed)  ## 与速度成比例的滞后
		target_offset.x = clampf(target_offset.x, -CAM_OFFSET_MAX, CAM_OFFSET_MAX)
		target_offset.z = clampf(target_offset.z, -CAM_OFFSET_MAX, CAM_OFFSET_MAX)
		_cam_offset = _cam_offset.lerp(target_offset, 1.0 - exp(-CAM_FOLLOW_LAG_SPEED * delta))

		## 2. 后坐力衰减
		if _cam_recoil_offset.length() > 0.05:
			_cam_recoil_offset = _cam_recoil_offset.move_toward(Vector3.ZERO, CAM_RECOIL_DECAY * delta)
		else:
			_cam_recoil_offset = Vector3.ZERO

		## 3. 震动计算
		if _cam_shake_time > 0.0:
			_cam_shake_time -= delta
			_cam_shake_intensity *= exp(-CAM_SHAKE_DECAY * delta)
			var shake_vec: Vector3 = Vector3(
				randf_range(-1, 1),
				randf_range(-1, 1),
				randf_range(-1, 1)
			).normalized() * _cam_shake_intensity * CAM_SHAKE_MAX_AMPLITUDE
			cam.position = cam.position.lerp(target_pos + _cam_offset + _cam_recoil_offset + shake_vec, 1.0 - exp(-CAM_SMOOTH_SPEED * delta))
		else:
			_cam_shake_intensity = 0.0
			cam.position = cam.position.lerp(target_pos + _cam_offset + _cam_recoil_offset, 1.0 - exp(-CAM_SMOOTH_SPEED * delta))
	
	_update_mouse_world_pos()

	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	if _is_firing and _state != State.DEAD:
		_try_fire()

	## 冻结检查：如果玩家被冻结，不处理移动输入
	if _frozen:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_frozen = false
		## 冻结期间只处理击退和物理，不处理玩家输入
		if _knockback_velocity.length() > 1.0:
			velocity += _knockback_velocity
			_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 500.0 * delta)
		move_and_slide()
		return

	if _knockback_velocity.length() > 1.0:
		velocity += _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 500.0 * delta)

	match _state:
		State.NORMAL:
			_process_normal(delta)
		State.ROLLING:
			_process_rolling(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			_process_dead(delta)
	move_and_slide()


func _process_normal(delta: float) -> void:
	_input_dir = Vector3.ZERO
	_input_dir.x = Input.get_axis("ui_left", "ui_right")
	_input_dir.z = Input.get_axis("ui_up", "ui_down")
	_input_dir = _input_dir.normalized()

	## 开发者模式：移速 10x
	var speed_mult: float = 1.0
	var dm = get_node_or_null("/root/DevMode")
	if dm and dm.has_method("is_dev_mode") and dm.is_dev_mode():
		speed_mult = 10.0

	if _input_dir.length() > 0.1:
		_facing_direction = _input_dir
		var target_vel := _input_dir * move_speed * speed_mult
		velocity = velocity.lerp(target_vel, 1.0 - exp(-CAM_SMOOTH_SPEED * delta))
		if _input_dir.x > 0.01:
			sprite.flip_h = false
		elif _input_dir.x < -0.01:
			sprite.flip_h = true
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-CAM_SMOOTH_SPEED * delta))
		if velocity.length() < 1.0:
			velocity = Vector3.ZERO
		if sprite.animation != "idle":
			sprite.play("idle")


func _process_rolling(delta: float) -> void:
	velocity = _facing_direction * roll_speed
	_roll_timer += delta
	if _roll_timer >= roll_duration:
		_on_roll_end()


func _process_hurt(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 500.0 * delta)
	_state_timer += delta
	if _state_timer > 0.2:
		_enter_state(State.NORMAL)


func _process_dead(_delta: float) -> void:
	velocity = Vector3.ZERO


func _try_fire() -> void:
	if _fire_cooldown > 0.0:
		return
	_fire_cooldown = fire_rate
	_fire(_mouse_direction)

func enable_triple_shot() -> void:
	if not triple_shot_enabled:
		triple_shot_enabled = true
		triple_shot_activated.emit()

## 启用冲锋枪攻速增益：攻速提升33%（冷却时间变为原来的2/3）
func enable_smg() -> void:
	if not smg_enabled:
		smg_enabled = true
		fire_rate = _base_fire_rate * SMG_FIRE_RATE_MULT
		smg_activated.emit()

## 启用达姆弹伤害增益：基础伤害提升25%
func enable_dumdum() -> void:
	if not dumdum_enabled:
		dumdum_enabled = true
		contact_damage = _base_contact_damage * DUMDUM_DAMAGE_MULT
		dumdum_activated.emit()


func _fire(dir: Vector3) -> void:
	if not PROJECTILE_SCENE:
		print("ERROR: PROJECTILE_SCENE is null")
		return

	## 开枪后坐力：镜头轻微向后+向上弹
	_cam_recoil_offset = -dir * CAM_RECOIL_STRENGTH + Vector3(0, CAM_RECOIL_STRENGTH * 0.5, 0)

	print("DEBUG _fire: dir=", dir, " muzzle_y=", muzzle.global_position.y if muzzle else "null")
	
	## 三发子弹模式
	if triple_shot_enabled:
		var angles: Array[float] = [-_triple_shot_angle, 0.0, _triple_shot_angle]
		for angle_deg in angles:
			var angle_rad: float = deg_to_rad(angle_deg)
			var rotated_dir: Vector3 = dir.rotated(Vector3.UP, angle_rad)
			var proj := PROJECTILE_SCENE.instantiate() as Node3D
			if proj.has_method("set_direction"):
				proj.set_direction(Vector2(rotated_dir.x, rotated_dir.z))
			else:
				print("ERROR: Projectile has no set_direction method!")
			get_tree().current_scene.add_child(proj)
			proj.global_position = muzzle.global_position + rotated_dir * 5.0
			proj.global_position.y = global_position.y
			print("DEBUG bullet spawned at ", proj.global_position)
	else:
		## 单发模式
		var proj := PROJECTILE_SCENE.instantiate() as Node3D
		if proj.has_method("set_direction"):
			proj.set_direction(Vector2(dir.x, dir.z))
		else:
			print("ERROR: Projectile has no set_direction method!")
		get_tree().current_scene.add_child(proj)
		proj.global_position = muzzle.global_position + dir * 5.0
		proj.global_position.y = global_position.y
		print("DEBUG bullet spawned at ", proj.global_position)


func _update_mouse_world_pos() -> void:
	if not cam:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = cam.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = cam.project_ray_normal(mouse_pos)
	var t: float = -ray_origin.y / ray_dir.y
	_mouse_world_pos = ray_origin + ray_dir * t
	var to_mouse: Vector3 = _mouse_world_pos - global_position
	_mouse_direction = Vector3(to_mouse.x, 0.0, to_mouse.z).normalized()


func _enter_state(new_state: int) -> void:
	_state = new_state
	_state_timer = 0.0


func _on_damaged(_amount: float, _source: Node) -> void:
	if _state == State.DEAD:
		return
	_invincible_timer = _INVINCIBLE_DURATION
	health_comp.invincible = true
	_flash_timer = 0.0
	_enter_state(State.HURT)
	## 受伤触发相机震动
	_cam_shake_intensity = 1.0
	_cam_shake_time = CAM_SHAKE_DURATION


func _on_roll_end() -> void:
	_roll_timer = 0.0
	if _state == State.ROLLING:
		_enter_state(State.NORMAL)


func _on_died(_who: Node) -> void:
	_enter_state(State.DEAD)
	if get_node_or_null("/root/GameEvents"):
		get_node("/root/GameEvents").player_died.emit(self)
	sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)


func _try_interact() -> void:
	for body in interaction.get_overlapping_bodies():
		if body.has_method("interact"):
			body.interact(self)


func revive() -> void:
	_state = State.NORMAL
	set_physics_process(true)
	sprite.modulate = Color(1, 1, 1, 1)


func apply_knockback(force: Vector3) -> void:
	_knockback_velocity = force


## 冻结玩家指定时长（秒），冻结期间不能移动
func freeze(duration: float) -> void:
	_frozen = true
	_freeze_timer = duration
	velocity = Vector3.ZERO


func _get_camera_arc_position(dist: float) -> Vector3:
	var angle_rad: float = deg_to_rad(CAM_ANGLE_DEG)
	var y: float = dist * sin(angle_rad)
	var z: float = dist * cos(angle_rad)
	return Vector3(0, y, z)
