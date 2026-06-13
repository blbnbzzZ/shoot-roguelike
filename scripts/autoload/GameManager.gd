## 游戏管理器 — Autoload 单例
## 管理全局游戏状态、场景切换、暂停、重开
extends Node

signal game_paused(paused: bool)
signal run_started
signal run_ended

var player: Node = null
var current_score: int = 0
var current_coins: int = 0
var _is_paused: bool = false
var skip_menu: bool = false

@onready var _game_events: Node = get_node_or_null("/root/GameEvents")


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if _game_events:
		_game_events.player_died.connect(_on_player_died)
		_game_events.game_restarted.connect(_on_game_restarted)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func toggle_pause() -> void:
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	game_paused.emit(_is_paused)


func start_new_run() -> void:
	current_score = 0
	current_coins = 0
	if _game_events:
		_game_events.game_restarted.emit()
	run_started.emit()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_player_died(_who: Node = null) -> void:
	run_ended.emit()
	## 延迟显示死亡 UI
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = true
	game_paused.emit(true)


func _on_game_restarted() -> void:
	get_tree().paused = false
	_is_paused = false


func add_score(amount: int) -> void:
	current_score += amount
	if _game_events:
		_game_events.score_changed.emit(current_score)


func add_coins(amount: int) -> void:
	current_coins += amount
	if _game_events:
		_game_events.coin_collected.emit(current_coins)


func get_player() -> Node:
	if is_instance_valid(player):
		return player
	player = get_tree().get_first_node_in_group("player")
	return player
