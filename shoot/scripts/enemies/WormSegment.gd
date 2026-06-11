## 虫子Boss（肉丸子）身体部位脚本
## 每个部位是一个独立的 Node3D，挂载此脚本
## 包含：Sprite3D（外观）、HealthComponent（独立血量）、HitBox（碰撞玩家）、HurtBox（受击）

extends Node3D
class_name WormSegment

## 部位类型枚举
enum SegmentType { HEAD, BODY }

## 导出参数
@export var segment_type: int = SegmentType.BODY
@export var max_hp: float = 200.0
@export var pixel_size: float = 0.1

## 节点引用
@onready var sprite: Sprite3D = $Sprite3D
@onready var health_comp: HealthComponent = $HealthComponent
@onready var hit_box: Area3D = $HitBox
@onready var hurt_box: Area3D = $HurtBox
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hitbox_shape: CollisionShape3D = $HitBox/CollisionShape3D

## 资源路径（由 WormBoss 统一设置）
var head_texture: Texture2D
var body_texture: Texture2D

## 部位索引（在整条虫中的序号，0=头）
var segment_index: int = 0

## 所属虫（WormBoss 节点）
var worm_parent: Node = null

## 是否还活着
var is_alive: bool = true


func _ready() -> void:
	## 根据类型设置贴图
	if sprite:
		if segment_type == SegmentType.HEAD and head_texture:
			sprite.texture = head_texture
		elif segment_type == SegmentType.BODY and body_texture:
			sprite.texture = body_texture
		if sprite.pixel_size != pixel_size:
			sprite.pixel_size = pixel_size

	## 连接血量事件
	if health_comp:
		health_comp.max_health = max_hp
		health_comp.health = max_hp
		health_comp.died.connect(_on_died)
		health_comp.damaged.connect(_on_damaged)

	## 设置碰撞层
	if hit_box:
		hit_box.body_entered.connect(_on_hit_box_entered)

	## 调试输出
	# print("WormSegment ready: type=", "HEAD" if segment_type == SegmentType.HEAD else "BODY", " index=", segment_index)


func setup(type: int, idx: int, head_tex: Texture2D, body_tex: Texture2D, parent: Node) -> void:
	segment_type = type
	segment_index = idx
	head_texture = head_tex
	body_texture = body_tex
	worm_parent = parent

	## 立即应用贴图
	if sprite:
		if segment_type == SegmentType.HEAD and head_texture:
			sprite.texture = head_texture
		elif segment_type == SegmentType.BODY and body_texture:
			sprite.texture = body_texture


func take_damage(amount: float) -> void:
	## 由 WormBoss 调用，转发伤害到 HealthComponent
	if not is_alive:
		return
	if health_comp:
		health_comp.apply_damage(amount, null)


func _on_died(_who: Node) -> void:
	## 血量归零，通知 WormBoss 处理断开
	is_alive = false
	if worm_parent and worm_parent.has_method("_on_segment_died"):
		worm_parent._on_segment_died(segment_index)


func _on_damaged(_amount: float, _source: Node) -> void:
	## 受击闪白效果
	_hurt_flash()


func _on_hit_box_entered(body: Node3D) -> void:
	## 碰到玩家造成伤害
	if body.is_in_group("player") and health_comp:
		## 每次碰到造成 15 点伤害（类似其他近战敌人）
		var dmg: float = 15.0
		body.get_node("HealthComponent").apply_damage(dmg, self)


func _hurt_flash() -> void:
	## 受击红色闪白
	if not sprite:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)


func set_head_texture(tex: Texture2D) -> void:
	## 动态切换为头部贴图（断开后新头部调用）
	head_texture = tex
	if sprite and segment_type == SegmentType.HEAD:
		sprite.texture = tex


func destroy_segment() -> void:
	## 从场景中移除该部位（被打烂后调用）
	queue_free()
