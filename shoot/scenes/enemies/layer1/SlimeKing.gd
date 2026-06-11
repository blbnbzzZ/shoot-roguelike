## 史莱姆王 — Boss 敌人
## 核心被动：碰撞小型史莱姆时吸收并恢复生命值
## 四大技能：弹跳碾压、凝胶分裂、凝胶弹幕、全域弹幕
class_name SlimeKing
extends EnemyBase

## ── 基础配置 ──
const FLOAT_AMPLITUDE: float = 6.0     ## 上下浮动幅度
const FLOAT_SPEED: float = 2.0         ## 浮动速度
const STRETCH_AMOUNT: float = 0.2      ## 拉伸幅度

## ── 技能参数 ──
## 弹跳碾压
const JUMP_PREPARE_TIME: float = 0.8    ## 蓄力时间（变扁）
const JUMP_DURATION: float = 0.6        ## 跳跃持续时间
const JUMP_HEIGHT: float = 40.0         ## 跳跃高度（与玩家跳进地洞高度一致）
const JUMP_LAND_TIME: float = 0.3       ## 落地后硬直
const JUMP_COOLDOWN: float = 2.0        ## 跳跃间隔
const JUMP_COUNT_MIN: int = 2           ## 最少连续跳跃次数
const JUMP_COUNT_MAX: int = 3           ## 最多连续跳跃次数
const JUMP_REST_TIME: float = 2.5       ## 连续跳跃后的休息（安全输出窗口）
const JUMP_DIST_MIN: float = 150.0      ## 最小跳跃距离（2.5倍）
const JUMP_DIST_MAX: float = 350.0      ## 最大跳跃距离（2.5倍）

## 凝胶分裂
const SPLIT_CHANCE: float = 0.35        ## 受击分裂概率
const SPLIT_MAX_SLIMES: int = 3         ## 最多同时存在的小史莱姆数
const SPLIT_INVINCIBLE_TIME: float = 0.5 ## 新分裂史莱姆的无敌时间

## 凝胶弹幕（扇形）
const FAN_BULLET_COUNT_MIN: int = 8     ## 最少子弹数
const FAN_BULLET_COUNT_MAX: int = 12    ## 最多子弹数
const FAN_ANGLE: float = 30.0           ## 上下各30度扇形
const FAN_PREPARE_TIME: float = 0.6     ## 蓄力时间（鼓起）
const FAN_COOLDOWN: float = 4.0         ## 冷却时间
const FAN_BULLET_SPEED_MIN: float = 40.0  ## 子弹最慢速度
const FAN_BULLET_SPEED_MAX: float = 100.0 ## 子弹最快速度（接近玩家初始移动速度120）
const FAN_BULLET_LIFE_MIN: float = 4.0  ## 子弹最短存在时间
const FAN_BULLET_LIFE_MAX: float = 6.0  ## 子弹最长存在时间

## 全域弹幕（环形）
const CIRCLE_BULLET_COUNT: int = 16     ## 环形子弹数
const CIRCLE_PREPARE_TIME: float = 0.5  ## 蓄力时间
const CIRCLE_COOLDOWN: float = 5.0      ## 冷却时间
const CIRCLE_BULLET_SPEED: float = 80.0 ## 环形子弹速度
const CIRCLE_BULLET_LIFE: float = 5.0   ## 环形子弹存在时间

## 被动：吸收小史莱姆恢复生命值
const ABSORB_HEAL_AMOUNT: float = 50.0  ## 每次吸收恢复血量
const ABSORB_COOLDOWN: float = 1.0      ## 吸收冷却

## ── 内部状态 ──
var _float_time: float = 0.0
var _slime_king_state: int = SlimeKingState.IDLE
var _jump_count: int = 0
var _max_jump_count: int = 0
var _jump_target: Vector3 = Vector3.ZERO
var _jump_start_pos: Vector3 = Vector3.ZERO
var _jump_timer: float = 0.0
var _skill_timer: float = 0.0
var _rest_timer: float = 0.0
var _absorb_timer: float = 0.0
var _spawned_slimes: Array[Node] = []   ## 已分裂的小史莱姆

## 攻击方式轮换：同一种最多连续2次
var _last_skill_used: int = -1          ## 上一次使用的技能（0=跳跃,1=扇形,2=环形）
var _same_skill_count: int = 0          ## 同一种技能连续使用次数

## 凝胶弹场景（使用敌人子弹场景，但修改外观和参数）
const GEL_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/EnemyProjectile.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/layer1/Slime.tscn")

enum SlimeKingState {
	IDLE,                ## 正常状态
	JUMP_PREPARE,        ## 弹跳蓄力（变扁）
	JUMPING,             ## 弹跳中
	JUMP_LAND,           ## 落地
	FAN_BURST_PREPARE,   ## 凝胶弹幕蓄力（鼓起）
	FAN_BURST_FIRE,      ## 凝胶弹幕发射
	CIRCLE_BURST_PREPARE,## 全域弹幕蓄力
	CIRCLE_BURST_FIRE,   ## 全域弹幕发射
	REST,                ## 休息（安全输出窗口）
}

## 技能冷却计时器
var _jump_cd_timer: float = 0.0
var _fan_cd_timer: float = 0.0
var _circle_cd_timer: float = 0.0

## 受击分裂冷却（防止连续受击连续分裂）
var _split_cd_timer: float = 0.0

## 预警红圈
var _warning_circle: MeshInstance3D = null


func _ready() -> void:
	is_boss = true
	move_speed = 50.0
	contact_damage = 30.0
	super._ready()

	## 设置史莱姆王血量
	if health_comp:
		health_comp.max_health = 1600.0
		health_comp.current_health = 1600.0

	## 初始技能冷却
	_jump_cd_timer = 2.0
	_fan_cd_timer = 3.0
	_circle_cd_timer = 4.0

	## 设置碰撞检测吸收小史莱姆
	if hit_box:
		hit_box.body_entered.connect(_on_hit_box_body_entered)

	## 创建预警红圈（初始隐藏）
	_create_warning_circle()

	_float_time = randf_range(0.0, TAU)


func _create_warning_circle() -> void:
	_warning_circle = MeshInstance3D.new()
	_warning_circle.name = "WarningCircle"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 40.0
	cylinder.bottom_radius = 40.0
	cylinder.height = 1.0
	_warning_circle.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warning_circle.material_override = mat
	_warning_circle.visible = false
	_warning_circle.position.y = 0.5
	## 红圈作为独立UI添加到场景根节点，不跟随史莱姆王
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(_warning_circle)
	else:
		add_child(_warning_circle)


func _physics_process(delta: float) -> void:
	## 更新浮动动画
	_float_time += delta * FLOAT_SPEED
	if sprite:
		var float_y: float = sin(_float_time) * FLOAT_AMPLITUDE
		sprite.position.y = 54.0 + float_y

	## 更新技能冷却
	if _jump_cd_timer > 0.0:
		_jump_cd_timer -= delta
	if _fan_cd_timer > 0.0:
		_fan_cd_timer -= delta
	if _circle_cd_timer > 0.0:
		_circle_cd_timer -= delta
	if _absorb_timer > 0.0:
		_absorb_timer -= delta
	if _split_cd_timer > 0.0:
		_split_cd_timer -= delta

	## 状态机处理
	match _slime_king_state:
		SlimeKingState.IDLE:
				_process_idle_state(delta)
		SlimeKingState.JUMP_PREPARE:
				_process_jump_prepare(delta)
		SlimeKingState.JUMPING:
				_process_jumping(delta)
		SlimeKingState.JUMP_LAND:
				_process_jump_land(delta)
		SlimeKingState.FAN_BURST_PREPARE:
				_process_fan_prepare(delta)
		SlimeKingState.FAN_BURST_FIRE:
				_process_fan_fire()
		SlimeKingState.CIRCLE_BURST_PREPARE:
				_process_circle_prepare(delta)
		SlimeKingState.CIRCLE_BURST_FIRE:
				_process_circle_fire()
		SlimeKingState.REST:
				_process_rest(delta)

	## 跳跃期间完全跳过物理引擎，避免 move_and_slide 干扰手动位置控制
	var _is_jumping: bool = (
		_slime_king_state == SlimeKingState.JUMP_PREPARE or
		_slime_king_state == SlimeKingState.JUMPING or
		_slime_king_state == SlimeKingState.JUMP_LAND
	)

	if not _is_jumping:
		## 非跳跃状态：正常物理处理
		if _knockback_velocity.length() > 0.1:
			velocity += _knockback_velocity
			_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
		move_and_slide()
	else:
		## 跳跃状态：只手动应用击退视觉反馈，不调用 move_and_slide()
		if _knockback_velocity.length() > 0.1:
			global_position += _knockback_velocity * delta * 0.05
			_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)


## ── 状态处理 ──
func _process_idle_state(delta: float) -> void:
	## 面向玩家
	if _player and sprite:
		var dir: Vector3 = (_player.global_position - global_position).normalized()
		sprite.flip_h = dir.x < 0.0

	## 技能选择：同一种攻击最多连续2次，强制轮换
	var available_skills: Array[int] = []
	if _jump_cd_timer <= 0.0:
		available_skills.append(0)
	if _fan_cd_timer <= 0.0:
		available_skills.append(1)
	if _circle_cd_timer <= 0.0:
		available_skills.append(2)

	if available_skills.size() == 0 or not _player:
		return

	## 同一种技能已连续2次，强制排除
	if _same_skill_count >= 2 and _last_skill_used in available_skills:
		available_skills.erase(_last_skill_used)

	if available_skills.size() == 0:
		## 所有可用技能都是同一个且已连续2次，等待其他技能CD
		return

	## 优先选不同于上一次的技能
	var chosen_skill: int = -1
	for skill in available_skills:
		if skill != _last_skill_used:
			chosen_skill = skill
			break
	## 只有上一次技能可用（冷却中没其他技能），且连续使用次数 < 2
	if chosen_skill == -1:
		chosen_skill = available_skills[0]

	## 记录连续使用次数
	if chosen_skill == _last_skill_used:
		_same_skill_count += 1
	else:
		_last_skill_used = chosen_skill
		_same_skill_count = 1

	## 执行技能
	match chosen_skill:
		0:
			## 开始新跳跃序列，初始化计数
			_jump_count = 0
			_max_jump_count = randi_range(JUMP_COUNT_MIN, JUMP_COUNT_MAX)
			_enter_jump_prepare()
		1: _enter_fan_prepare()
		2: _enter_circle_prepare()


## ── 弹跳碾压 ──
func _enter_jump_prepare() -> void:
	_slime_king_state = SlimeKingState.JUMP_PREPARE
	_jump_timer = 0.0
	## 不再这里重置_jump_count和_max_jump_count，改在_process_idle_state选跳跃时初始化
	## 清零速度，避免 move_and_slide 干扰跳跃轨迹
	velocity = Vector3.ZERO
	## 提前计算落点并显示红圈（起跳动画期间就预警）
	_calculate_jump_target()
	if _warning_circle:
		_warning_circle.global_position = _jump_target + Vector3(0, 0.5, 0)
		_warning_circle.visible = true
	## 变扁动画
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale:y", 0.5, JUMP_PREPARE_TIME * 0.5)
		tween.tween_property(sprite, "scale:y", 0.3, JUMP_PREPARE_TIME * 0.5)


func _process_jump_prepare(delta: float) -> void:
	_jump_timer += delta
	if _jump_timer >= JUMP_PREPARE_TIME:
		_start_jump()


## 计算跳跃落点（抽取为独立函数，供准备阶段和跳跃开始共用）
func _calculate_jump_target() -> void:
	if not _player:
		## 没有玩家，随机跳向最远距离
		var angle := randf_range(0.0, TAU)
		var jump_dir := Vector3(cos(angle), 0.0, sin(angle))
		_jump_target = global_position + jump_dir * JUMP_DIST_MAX
		_jump_start_pos = global_position
		return

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist_to_player: float = to_player.length()
	var base_dir := to_player.normalized()

	if dist_to_player <= JUMP_DIST_MAX:
		## 玩家在跳跃距离内，直接越向玩家（无偏差）
		var jump_dist := clampf(dist_to_player, JUMP_DIST_MIN, JUMP_DIST_MAX)
		_jump_target = global_position + base_dir * jump_dist
	else:
		## 玩家不在范围内，跳向面向玩家的最长距离
		_jump_target = global_position + base_dir * JUMP_DIST_MAX

	_jump_start_pos = global_position


func _start_jump() -> void:
	_slime_king_state = SlimeKingState.JUMPING
	_jump_timer = 0.0
	_jump_count += 1

	## 落点已在 _calculate_jump_target() 中计算，这里不再重复
	## 红圈已在 _enter_jump_prepare() 中显示，这里不再重复

	## 跳跃期间禁用物理碰撞体，避免与玩家碰撞弹飞玩家
	var body_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_col:
		body_col.disabled = true

	## 弹跳动画：恢复形状并弹起
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale:y", 1.3, 0.1)
		tween.tween_property(sprite, "scale:y", 1.0, 0.1)


func _process_jumping(delta: float) -> void:
	## 跳跃期间禁用物理速度，完全由手动轨迹控制
	velocity = Vector3.ZERO
	_jump_timer += delta
	var t := _jump_timer / JUMP_DURATION
	if t >= 1.0:
		## 落地
		global_position = _jump_target
		_land_jump()
		return

	## 抛物线运动（修复：y坐标应相对于起始位置，而非相对于0）
	var horizontal_pos := _jump_start_pos.lerp(_jump_target, t)
	var target_y := _jump_start_pos.y + JUMP_HEIGHT * sin(t * PI)
	global_position = Vector3(horizontal_pos.x, target_y, horizontal_pos.z)

	## 空中旋转效果
	if sprite:
		sprite.rotation_degrees.x = t * 360.0


func _land_jump() -> void:
	_slime_king_state = SlimeKingState.JUMP_LAND
	_jump_timer = 0.0
	## 红圈在最后一次跳跃落地时才隐藏（连续跳跃时保持显示）
	if _jump_count >= _max_jump_count:
		if _warning_circle:
			_warning_circle.visible = false
	## 落地时重新启用物理碰撞体
	var body_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_col:
		body_col.disabled = false
	## 落地冲击效果：变扁一下
	if sprite:
		sprite.rotation_degrees.x = 0.0
		var tween := create_tween()
		tween.tween_property(sprite, "scale:y", 0.4, 0.1)
		tween.tween_property(sprite, "scale:y", 1.0, 0.2)
	## 落地时对玩家造成范围伤害+击退（如果玩家在落点附近）
	if _player:
		var dist := global_position.distance_to(_player.global_position)
		if dist < 60.0:
			var hc := _player.get_node_or_null("HealthComponent") as HealthComponent
			if hc and not hc.invincible:
				hc.apply_damage(contact_damage * 1.5, self)
			## 给玩家一个向外的击退，避免碰撞体重叠导致卡地下
			if _player.has_method("apply_knockback"):
				var kb_dir: Vector3 = (_player.global_position - global_position).normalized()
				kb_dir.y = 0.0
				if kb_dir.is_zero_approx():
					kb_dir = Vector3.BACK
				_player.apply_knockback(kb_dir * 100.0)


func _process_jump_land(delta: float) -> void:
	_jump_timer += delta
	if _jump_timer >= JUMP_LAND_TIME:
		if _jump_count < _max_jump_count:
			## 继续下一次跳跃
			_enter_jump_prepare()
		else:
			## 进入休息（安全输出窗口）
			_enter_rest()


## ── 休息（安全输出窗口）──
func _enter_rest() -> void:
	_slime_king_state = SlimeKingState.REST
	_rest_timer = 0.0
	_jump_cd_timer = JUMP_COOLDOWN + JUMP_REST_TIME


func _process_rest(delta: float) -> void:
	_rest_timer += delta
	if _rest_timer >= JUMP_REST_TIME:
		_slime_king_state = SlimeKingState.IDLE


## ── 凝胶弹幕（扇形）──
func _enter_fan_prepare() -> void:
	_slime_king_state = SlimeKingState.FAN_BURST_PREPARE
	_skill_timer = 0.0
	## 鼓起动画
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector3(1.3, 1.3, 1.3), FAN_PREPARE_TIME)


func _process_fan_prepare(delta: float) -> void:
	_skill_timer += delta
	if _skill_timer >= FAN_PREPARE_TIME:
		_fire_fan_burst()


func _process_fan_fire() -> void:
	pass


func _fire_fan_burst() -> void:
	_slime_king_state = SlimeKingState.FAN_BURST_FIRE
	if sprite:
		## 恢复形状
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector3.ONE, 0.2)

	if not _player:
		_slime_king_state = SlimeKingState.IDLE
		_fan_cd_timer = FAN_COOLDOWN
		return

	## 计算朝向玩家的基础方向
	var base_dir: Vector3 = (_player.global_position - global_position)
	base_dir.y = 0.0
	base_dir = base_dir.normalized()

	## 发射8-12枚凝胶弹
	var bullet_count := randi_range(FAN_BULLET_COUNT_MIN, FAN_BULLET_COUNT_MAX)
	## 扇形角度：上下各30度，总共60度
	var total_angle := deg_to_rad(FAN_ANGLE * 2.0)
	var angle_step := total_angle / (bullet_count - 1)
	var start_angle := -deg_to_rad(FAN_ANGLE)

	for i in range(bullet_count):
		var angle := start_angle + i * angle_step
		var dir := base_dir.rotated(Vector3.UP, angle)
		_spawn_gel_projectile(dir, true)

	## 同时发射反方向的扇形（形成上下两个扇形区域）
	var reverse_base := -base_dir
	for i in range(bullet_count):
		var angle := start_angle + i * angle_step
		var dir := reverse_base.rotated(Vector3.UP, angle)
		_spawn_gel_projectile(dir, true)

	_fan_cd_timer = FAN_COOLDOWN
	## 发射后直接回到IDLE
	_slime_king_state = SlimeKingState.IDLE


## ── 全域弹幕（环形）──
func _enter_circle_prepare() -> void:
	_slime_king_state = SlimeKingState.CIRCLE_BURST_PREPARE
	_skill_timer = 0.0
	## 鼓起动画
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector3(1.2, 1.2, 1.2), CIRCLE_PREPARE_TIME)


func _process_circle_prepare(delta: float) -> void:
	_skill_timer += delta
	if _skill_timer >= CIRCLE_PREPARE_TIME:
		_fire_circle_burst()


func _process_circle_fire() -> void:
	pass


func _fire_circle_burst() -> void:
	_slime_king_state = SlimeKingState.CIRCLE_BURST_FIRE
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector3.ONE, 0.2)

	## 360度环形散射
	var angle_step := TAU / CIRCLE_BULLET_COUNT
	for i in range(CIRCLE_BULLET_COUNT):
		var angle := i * angle_step
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		_spawn_gel_projectile(dir, false)

	_circle_cd_timer = CIRCLE_COOLDOWN
	## 发射后直接回到IDLE
	_slime_king_state = SlimeKingState.IDLE


## ── 发射凝胶弹 ──
func _spawn_gel_projectile(dir: Vector3, is_fan: bool) -> void:
	if not GEL_PROJECTILE_SCENE:
		return
	var proj := GEL_PROJECTILE_SCENE.instantiate() as Area3D
	if not proj:
		return

	## 设置方向
	if proj.has_method("set_direction"):
		proj.set_direction(Vector2(dir.x, dir.z))

	## 设置速度
	var speed: float
	var life_time: float
	if is_fan:
		## 扇形弹幕：速度不一
		speed = randf_range(FAN_BULLET_SPEED_MIN, FAN_BULLET_SPEED_MAX)
		life_time = randf_range(FAN_BULLET_LIFE_MIN, FAN_BULLET_LIFE_MAX)
	else:
		## 环形弹幕：统一速度
		speed = CIRCLE_BULLET_SPEED
		life_time = CIRCLE_BULLET_LIFE

	if proj.has_method("set_speed"):
		proj.set_speed(speed)
	elif "speed" in proj:
		proj.speed = speed

	## 设置存在时间（直接修改LifeTimer）
	if proj.has_node("LifeTimer"):
		var life_timer: Timer = proj.get_node("LifeTimer")
		life_timer.wait_time = life_time
		life_timer.start(life_time)

	## 设置伤害（史莱姆王子弹伤害较低）
	if "damage" in proj:
		proj.damage = 8.0

	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, 20, 0)


## ── 被动：吸收小史莱姆 ──
func _on_hit_box_body_entered(body: Node3D) -> void:
	## 先调用父类处理玩家接触
	super._on_hit_box_body_entered(body)

	## 吸收小史莱姆
	if body.is_in_group("enemy") and body is Slime:
		if _absorb_timer <= 0.0:
			_absorb_slime(body)


func _absorb_slime(slime: Slime) -> void:
	_absorb_timer = ABSORB_COOLDOWN
	## 恢复生命值
	if health_comp:
		health_comp.heal(ABSORB_HEAL_AMOUNT)
	## 播放吸收动画效果（史莱姆王身体鼓一下）
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector3.ONE, 0.2)
	## 播放小史莱姆跳跃吞噬动画
	_play_absorb_animation(slime)


## 小史莱姆跳跃吞噬动画（类似玩家跳洞）
func _play_absorb_animation(slime: Slime) -> void:
	if not is_instance_valid(slime):
		return

	## 从追踪列表中移除
	if slime in _spawned_slimes:
		_spawned_slimes.erase(slime)

	## 禁用小史莱姆的碰撞和AI
	slime.set_physics_process(false)
	slime.set_process(false)
	## 清零速度，避免物理引擎残留速度导致下陷
	slime.velocity = Vector3.ZERO
	if "_velocity" in slime:
		slime._velocity = Vector3.ZERO
	## 正确禁用碰撞体（HitBox是Area3D，要获取其内部的CollisionShape3D）
	var slime_body_col := slime.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if slime_body_col:
		slime_body_col.disabled = true
	var slime_hitbox_shape := slime.get_node_or_null("HitBox/CollisionShape3D") as CollisionShape3D
	if slime_hitbox_shape:
		slime_hitbox_shape.disabled = true

	## 获取史莱姆王精灵的位置（世界坐标）
	var target_pos: Vector3 = global_position
	if sprite:
		target_pos = sprite.global_position

	## 创建跳跃动画（抛物线轨迹）
	var start_pos: Vector3 = slime.global_position
	var mid_pos: Vector3 = (start_pos + target_pos) * 0.5
	mid_pos.y += 80.0  ## 跳跃高度

	var tween := create_tween()
	tween.set_parallel(false)

	## 第一阶段：跳到最高点（0.25秒）
	var jump_up = func(t: float) -> void:
		if not is_instance_valid(slime):
			return
		var p := start_pos.lerp(mid_pos, t)
		## 添加横向的弧线偏移
		var arc := sin(t * PI) * 30.0
		p.x += arc * (1.0 if randf() > 0.5 else -1.0)
		p.z += arc * (randf() - 0.5) * 0.5
		slime.global_position = p
		## 旋转效果（翻滚）
		if is_instance_valid(slime) and slime.sprite:
			slime.sprite.rotation_degrees.z = t * 360.0 * 0.5
	tween.tween_method(jump_up, 0.0, 1.0, 0.25)

	## 第二阶段：从最高点落到史莱姆王身上（0.2秒）
	var jump_down = func(t: float) -> void:
		if not is_instance_valid(slime):
			return
		var p := mid_pos.lerp(target_pos, t)
		## 加速下落效果
		p.y -= sin(t * PI) * 20.0
		slime.global_position = p
		## 继续旋转
		if is_instance_valid(slime) and slime.sprite:
			slime.sprite.rotation_degrees.z += 15.0
		## 逐渐缩小（被吸收的感觉）
		if is_instance_valid(slime) and slime.sprite:
			var scale_val := 1.0 - t * 0.7
			slime.sprite.scale = Vector3(scale_val, scale_val, scale_val)
	tween.tween_method(jump_down, 0.0, 1.0, 0.2)

	## 动画完成后销毁小史莱姆
	tween.tween_callback(func():
		if is_instance_valid(slime):
			slime.queue_free()
	)


## ── 凝胶分裂：受击时分裂小史莱姆 ──
func _on_damaged(amount: float, source: Node) -> void:
	## 先调用父类处理（闪白等）
	super._on_damaged(amount, source)

	## 分裂小史莱姆
	if _split_cd_timer <= 0.0 and randf() < SPLIT_CHANCE:
		if _spawned_slimes.size() < SPLIT_MAX_SLIMES:
			_split_cd_timer = 1.0  ## 1秒内不会再次分裂
			_spawn_mini_slime()


func _spawn_mini_slime() -> void:
	if not SLIME_SCENE:
		return
	var slime := SLIME_SCENE.instantiate() as Slime
	if not slime:
		return

	## 在史莱姆王附近随机位置生成
	var offset := Vector3(randf_range(-40.0, 40.0), 0.0, randf_range(-40.0, 40.0))
	slime.global_position = global_position + offset

	## 设置0.5秒内无敌且不能被吸收
	if slime.health_comp:
		slime.health_comp.invincible = true

	get_tree().current_scene.add_child(slime)
	_spawned_slimes.append(slime)

	## 0.5秒后解除无敌
	var timer := get_tree().create_timer(SPLIT_INVINCIBLE_TIME)
	timer.timeout.connect(func():
		if is_instance_valid(slime) and slime.health_comp:
			slime.health_comp.invincible = false
	)


## ── 死亡处理 ──
func _on_died(_who: Node) -> void:
	_state = State.DEAD
	set_physics_process(false)

	## 清理预警圈
	if _warning_circle:
		_warning_circle.queue_free()

	## 清理所有分裂的小史莱姆
	for slime in _spawned_slimes:
		if is_instance_valid(slime):
			slime.queue_free()
	_spawned_slimes.clear()

	## 通知游戏事件
	var ge := get_node_or_null("/root/GameEvents")
	if ge:
		ge.enemy_died.emit(self)

	## Boss掉落
	if randf() < 0.5 and HEALTH_PICKUP_SCENE:
		var pickup := HEALTH_PICKUP_SCENE.instantiate()
		get_tree().current_scene.add_child(pickup)
		pickup.global_position = global_position

	## 死亡动画
	if sprite:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		tween.tween_property(sprite, "scale", Vector3(0.1, 0.1, 0.1), 1.0)
		await tween.finished

	queue_free()
