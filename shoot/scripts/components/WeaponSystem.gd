## 武器系统组件 — 挂载到 Player，管理当前武器和开火逻辑
## 信号驱动，与 Player.gd 解耦
class_name WeaponSystem
extends Node

signal weapon_fired(weapon_data: WeaponData)
signal weapon_changed(weapon_data: WeaponData)

@export_group("Runtime")
@export var current_weapon: WeaponData:
	set(v):
		current_weapon = v
		weapon_changed.emit(v)
		_fire_timer = 0.0

@export var fire_point: Marker2D

var _fire_timer: float = 0.0
var _projectile_scene: PackedScene = preload("res://scenes/weapons/Projectile.tscn")


func _ready() -> void:
	if current_weapon == null:
		_create_default_weapon()


func _physics_process(delta: float) -> void:
	_fire_timer = max(_fire_timer - delta, 0.0)

	if Input.is_action_pressed("fire") and _fire_timer <= 0.0 and current_weapon != null:
		fire(get_parent().get_global_mouse_position() - get_parent().global_position)
		_fire_timer = 1.0 / current_weapon.fire_rate


func fire(direction: Vector2) -> void:
	if not _projectile_scene or not current_weapon:
		return

	var base_angle: float = direction.angle()
	var count: int = max(current_weapon.projectile_count, 1)
	var spread: float = deg_to_rad(current_weapon.spread)

	for i in count:
		var angle_offset: float = 0.0
		if count > 1:
			angle_offset = lerp(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
		var proj_dir: Vector2 = Vector2(cos(base_angle + angle_offset), sin(base_angle + angle_offset))

		var proj: Area2D = _projectile_scene.instantiate()
		proj.damage = current_weapon.damage
		proj.speed = current_weapon.projectile_speed
		proj.lifetime = current_weapon.projectile_lifetime
		proj.global_position = fire_point.global_position if fire_point else get_parent().global_position
		proj.set_direction(proj_dir)
		get_tree().current_scene.add_child(proj)

	weapon_fired.emit(current_weapon)


func _create_default_weapon() -> void:
	current_weapon = WeaponData.new()
	current_weapon.display_name = "Pistol"
	current_weapon.damage = 10.0
	current_weapon.fire_rate = 3.0
	current_weapon.projectile_speed = 600.0
	current_weapon.projectile_count = 1
	current_weapon.spread = 0.0
