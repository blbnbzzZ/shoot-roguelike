## 敌人 3D 版本（Sprite3D + CharacterBody3D）
class_name EnemyBase
extends CharacterBody3D

signal died()
signal health_changed(current: float, max_hp: float)

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
enum AiType { MELEE, RANGED, FAST }

@export var move_speed: float = 80.0
@export var contact_damage: float = 15.0
@export var shoot: bool = false
@export var ai_type: int = AiType.MELEE
@export var ranged_strafe_speed: float = 100.0  ## 远程怪物左右摇摆速度

@onready var sprite: Sprite3D = $Sprite3D
@onready var health_comp: HealthComponent = $HealthComponent
@onready var detection: Area3D = $Detection
@onready var hit_box: Area3D = $HitBox
@onready var shoot_timer: Timer = $ShootTimer

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/EnemyProjectile.tscn")
const FAST_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/FastEnemyProjectile.tscn")
const HEALTH_PICKUP_SCENE: PackedScene = preload("res://scenes/items/HealthPickup.tscn")
var BLOOD_PARTICLES: PackedScene = null  ## 血浆粒子，运行时加载（延迟引用避免循环依赖）

var _state: int = State.IDLE
var _player: Node3D = null
var _shoot_cooldown: float = 0.0
var _state_timer: float = 0.0
var _strafe_direction: float = 1.0  ## 1.0 = 右, -1.0 = 左
var _strafe_timer: float = 0.0
var _strafe_interval: float = 1.5  ## 每隔几秒切换摇摆方向

## 近战持续伤害
var _melee_target: Node3D = null
var _melee_timer: float = 0.0
var _melee_interval: float = 1.0

## Boss专属
var is_boss: bool = false
var boss_shoot_interval: float = 5.0
var _boss_shoot_timer: float = 0.0
var _boss_single_shoot_timer: float = 0.0
var boss_single_shoot_interval: float = 1.0

## 击退（被子弹击中时向后弹开）
var _knockback_velocity: Vector3 = Vector3.ZERO
const KNOCKBACK_STRENGTH: float = 50.0   ## 击退强度
const KNOCKBACK_DECAY: float = 180.0      ## 击退衰减速度（调低=持续更久）

## 受击红色闪白
var _hurt_flash_tween: Tween = null
const HURT_FLASH_DURATION: float = 0.3     ## 红色闪白持续时间
const HURT_FLASH_COLOR: Color = Color(2.5, 0.5, 0.5, 1.0)  ## 受击红色（高亮溢出更明显）


func _ready() -> void:
	add_to_group("enemy")
	## 物理处理由 Room 通过 play_spawn_animation() 控制
	health_comp.died.connect(_on_died)
	health_comp.health_changed.connect(func(c, m): health_changed.emit(c, m))
	health_comp.damaged.connect(_on_damaged)  ## 受伤时触发击退
	detection.body_entered.connect(_on_detect_enter)
	detection.body_exited.connect(_on_detect_exit)
	if hit_box:
		hit_box.body_entered.connect(_on_hit_box_body_entered)
		hit_box.body_exited.connect(_on_hit_box_body_exited)
	call_deferred("_check_player_nearby")


func _on_hit_box_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_melee_target = body
	_melee_timer = 0.0  ## 立即造成第一次伤害


func _on_hit_box_body_exited(body: Node3D) -> void:
	if body == _melee_target:
		_melee_target = null
		_melee_timer = 0.0


func _check_player_nearby() -> void:
	for body in detection.get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_detect_enter(body)
			return


func _physics_process(delta: float) -> void:
	if _shoot_cooldown > 0.0:
		_shoot_cooldown -= delta
	if _strafe_timer > 0.0:
		_strafe_timer -= delta

	## Boss 攻击计时：扇形弹幕 + 单发射击
	if is_boss:
		_boss_shoot_timer -= delta
		if _boss_shoot_timer <= 0.0:
			_fire_fan_shot()
			_boss_shoot_timer = boss_shoot_interval

		_boss_single_shoot_timer -= delta
		if _boss_single_shoot_timer <= 0.0:
			_fire_at_player()
			_boss_single_shoot_timer = boss_single_shoot_interval

	_state_timer += delta

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			_process_dead(delta)

	## 近战持续伤害：贴着玩家时每1秒造成一次伤害
	if _melee_target and not is_boss and is_instance_valid(_melee_target):
		_melee_timer -= delta
		if _melee_timer <= 0.0:
			var hc := _melee_target.get_node_or_null("HealthComponent") as HealthComponent
			if hc and not hc.invincible:
				hc.apply_damage(contact_damage, self)
				if _melee_target.has_method("apply_knockback"):
					var kb_dir: Vector3 = (_melee_target.global_position - global_position).normalized()
					kb_dir.y = 0.0
					_melee_target.apply_knockback(kb_dir * 75.0)
			_melee_timer = _melee_interval

	## 击退速度叠加（阈值降到0.1，让微小击退也能生效）
	if _knockback_velocity.length() > 0.1:
		velocity += _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

	move_and_slide()


func _process_idle(_delta: float) -> void:
	velocity = Vector3.ZERO


func _process_chase(delta: float) -> void:
	if not _player:
		_enter_state(State.IDLE)
		return

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized()

	if is_boss:
		## Boss：像远程小兵一样走位（左右摇摆），同时面向玩家
		if _strafe_timer <= 0.0:
			_strafe_timer = _strafe_interval * (0.8 + randf() * 0.4)
			_strafe_direction = -_strafe_direction if randf() < 0.5 else _strafe_direction

		var strafe_vec: Vector3 = Vector3(-dir.z, 0.0, dir.x) * _strafe_direction
		velocity = strafe_vec * ranged_strafe_speed

		if sprite:
			sprite.flip_h = dir.x < 0.0
		_enter_state(State.ATTACK)
	elif ai_type == AiType.RANGED or shoot:
		## 远程：只在原地左右摇摆，不靠近也不远离玩家
		if _strafe_timer <= 0.0:
			_strafe_timer = _strafe_interval * (0.8 + randf() * 0.4)
			_strafe_direction = -_strafe_direction if randf() < 0.5 else _strafe_direction

		var strafe_vec: Vector3 = Vector3(-dir.z, 0.0, dir.x) * _strafe_direction
		velocity = strafe_vec * ranged_strafe_speed

		if sprite:
			sprite.flip_h = dir.x < 0.0

		## 进入攻击（射击）状态
		_enter_state(State.ATTACK)
	else:
		## 近战：直接冲向玩家
		velocity = dir * move_speed
		if sprite:
			sprite.flip_h = dir.x < 0.0
		if dist < 15.0:
			_enter_state(State.ATTACK)


func _process_attack(_delta: float) -> void:
	if not _player:
		_enter_state(State.IDLE)
		return

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized()

	if is_boss:
		## Boss：继续走位 + 弹幕计时器在 _physics_process 中处理
		if _strafe_timer <= 0.0:
			_strafe_timer = _strafe_interval * (0.8 + randf() * 0.4)
			_strafe_direction = -_strafe_direction if randf() < 0.5 else _strafe_direction

		var strafe_vec := Vector3(-dir.z, 0.0, dir.x) * _strafe_direction
		velocity = strafe_vec * ranged_strafe_speed

		if sprite:
			sprite.flip_h = dir.x < 0.0
	elif ai_type == AiType.RANGED or shoot:
		## 远程：继续原地摇摆 + 射击
		if _strafe_timer <= 0.0:
			_strafe_timer = _strafe_interval * (0.8 + randf() * 0.4)
			_strafe_direction = -_strafe_direction if randf() < 0.5 else _strafe_direction

		var strafe_vec: Vector3 = Vector3(-dir.z, 0.0, dir.x) * _strafe_direction
		velocity = strafe_vec * ranged_strafe_speed

		## 射击
		if _shoot_cooldown <= 0.0:
			_fire_at_player()
			_shoot_cooldown = 1.5
	else:
		## 近战：停止移动，接触伤害由 HitBox 处理
		velocity = Vector3.ZERO
		## 如果玩家跑远了，追上去
		if dist > 25.0:
			_enter_state(State.CHASE)


func _process_hurt(_delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 500.0 * _delta)
	if _state_timer > 0.2:
		if _player:
			_enter_state(State.CHASE)
		else:
			_enter_state(State.IDLE)


func _process_dead(_delta: float) -> void:
	velocity = Vector3.ZERO


func _fire_at_player() -> void:
	if not _player or not PROJECTILE_SCENE:
		return
	var proj := PROJECTILE_SCENE.instantiate() as Node3D
	var dir: Vector3 = (_player.global_position - global_position)
	dir.y = 0.0
	if proj.has_method("set_direction"):
		proj.set_direction(Vector2(dir.x, dir.z))
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, 1, 0)

	## Boss子弹更大更快
	if is_boss:
		if proj.has_method("set_speed"):
			proj.set_speed(120.0)
		elif "speed" in proj:
			proj.speed = 120.0


## Boss扇形弹幕：5发子弹，呈扇形分布
func _fire_fan_shot() -> void:
	if not _player or not FAST_PROJECTILE_SCENE:
		return
	var base_dir: Vector3 = (_player.global_position - global_position)
	base_dir.y = 0.0
	base_dir = base_dir.normalized()
	
	## 扇形角度范围：-20度到+20度，5发均匀分布
	var angle_step := deg_to_rad(10.0)  ## 每发间隔10度
	var start_angle := -2.0 * angle_step  ## 从-20度开始
	
	for i in range(5):
		var angle := start_angle + i * angle_step
		var rot_dir := base_dir.rotated(Vector3.UP, angle)
		
		var proj := FAST_PROJECTILE_SCENE.instantiate() as Area3D
		if proj.has_method("set_direction"):
			proj.set_direction(Vector2(rot_dir.x, rot_dir.z))
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position + Vector3(0, 1, 0)
		
		## 扇形弹幕使用高速子弹，速度更快
		if proj.has_method("set_speed"):
			proj.set_speed(200.0)
		elif "speed" in proj:
			proj.speed = 200.0


func _enter_state(new_state: int) -> void:
	_state = new_state
	_state_timer = 0.0
	_strafe_timer = 0.0


func _on_detect_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = body
		if _state == State.IDLE:
			_enter_state(State.CHASE)


func _on_detect_exit(body: Node3D) -> void:
	if body == _player:
		_player = null
		if _state == State.CHASE or _state == State.ATTACK:
			_enter_state(State.IDLE)


func _on_died(_who: Node) -> void:
	_state = State.DEAD
	set_physics_process(false)
	var ge := get_node_or_null("/root/GameEvents")
	if ge:
		ge.enemy_died.emit(self)
	if randf() < 0.2 and HEALTH_PICKUP_SCENE:
		var pickup := HEALTH_PICKUP_SCENE.instantiate()
		get_tree().current_scene.add_child(pickup)
		pickup.global_position = global_position
	if sprite:
		sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)
	await get_tree().create_timer(0.5).timeout
	queue_free()


## 受伤回调：非Boss怪物被击中时触发击退 + 血浆粒子效果 + 红色闪白 + 唤醒
func _on_damaged(_amount: float, source: Node) -> void:
	## 红色闪白效果（所有怪物包括Boss）
	_hurt_flash()

	## 如果物理处理被禁用（大房间远处休眠的敌人），受击时立即唤醒
	if not is_processing():
		set_physics_process(true)
		if health_comp:
			health_comp.invincible = false

	## 血浆粒子：向子弹反方向喷溅（所有怪物都有效果，包括Boss）
	if not BLOOD_PARTICLES:
		BLOOD_PARTICLES = load("res://scenes/effects/BloodParticles.tscn")
	if BLOOD_PARTICLES and is_inside_tree():
		var blood := BLOOD_PARTICLES.instantiate() as GPUParticles3D
		if blood:
			## 先加入场景树，再设置位置和朝向（避免节点不在树中的报错）
			get_tree().current_scene.add_child(blood)
			blood.global_position = global_position + Vector3(0, 20, 0)
			## 粒子朝向：子弹来源的反方向（被击中后向后飞溅）
			if source and is_instance_valid(source):
				var look_dir: Vector3 = (global_position - source.global_position).normalized()
				look_dir.y = 0.0
				if not look_dir.is_zero_approx():
					blood.look_at(global_position + look_dir, Vector3.UP)
			## 粒子播完自动销毁（one_shot=true）
			await get_tree().create_timer(1.0).timeout
			if is_instance_valid(blood):
				blood.queue_free()

	## 击退（Boss不触发）
	if is_boss:
		return
	var kb_dir: Vector3
	if source and is_instance_valid(source):
		kb_dir = (global_position - source.global_position).normalized()
	else:
		kb_dir = Vector3.BACK
	kb_dir.y = 0.0
	if not kb_dir.is_zero_approx():
		apply_knockback(kb_dir * KNOCKBACK_STRENGTH)


## 受击红色闪白：瞬间变红，0.3秒内平滑恢复白色
func _hurt_flash() -> void:
	if not sprite:
		return
	## 取消上一次未完成的闪白（防止连续命中时闪烁不自然）
	if _hurt_flash_tween and _hurt_flash_tween.is_running():
		_hurt_flash_tween.kill()
	## 固定恢复到纯白（不用sprite.modulate做目标——连射时会捕获到半红色导致越打越红）
	sprite.modulate = HURT_FLASH_COLOR
	_hurt_flash_tween = create_tween()
	_hurt_flash_tween.tween_property(sprite, "modulate", Color.WHITE, HURT_FLASH_DURATION)


func apply_knockback(force: Vector3) -> void:
	_knockback_velocity = force


## 生成动画：淡入 + 缩放，期间无敌且不动，持续 0.7 秒
func play_spawn_animation() -> void:
	set_physics_process(false)
	health_comp.invincible = true

	## 初始状态：透明 + 缩小
	sprite.modulate.a = 0.0
	sprite.scale = Vector3(0.2, 0.2, 0.2)

	## 动画：0.7 秒淡入并放大
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.7)
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.7)
	await tween.finished

	## 恢复：启用物理处理，取消无敌
	set_physics_process(true)
	health_comp.invincible = false
