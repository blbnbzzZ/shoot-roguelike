extends CharacterBody2D

@export var move_speed: float = 220.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea

var _facing_right: bool = true
var _can_interact: bool = false
var _interact_target: Node = null


func _ready() -> void:
	add_to_group("player")
	if interact_area:
		interact_area.body_entered.connect(_on_interact_body_entered)
		interact_area.body_exited.connect(_on_interact_body_exited)


func _physics_process(delta: float) -> void:
	## 重力
	if not is_on_floor():
		velocity.y += gravity * delta
	
	## 跳跃
	if Input.is_action_just_pressed("ui_jump") and is_on_floor():
		velocity.y = jump_velocity
	
	## 左右移动
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * move_speed
		if direction < 0 and _facing_right:
			_facing_right = false
			sprite.flip_h = true
		elif direction > 0 and not _facing_right:
			_facing_right = true
			sprite.flip_h = false
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 5 * delta)
	
	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _can_interact and _interact_target:
		_interact_target.interact()


func _on_interact_body_entered(body: Node2D) -> void:
	if body.is_in_group("interactable"):
		_can_interact = true
		_interact_target = body
		_show_interact_prompt(true)


func _on_interact_body_exited(body: Node2D) -> void:
	if body == _interact_target:
		_can_interact = false
		_interact_target = null
		_show_interact_prompt(false)


func _show_interact_prompt(show: bool) -> void:
	var prompt := get_tree().get_first_node_in_group("interact_prompt")
	if prompt:
		prompt.visible = show
