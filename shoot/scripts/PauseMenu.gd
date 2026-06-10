## 暂停菜单场景
extends Control

signal resume_game
signal quit_to_menu

var game_started: bool = false

func _ready() -> void:
	visible = false
	## 暂停时仍能处理输入
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	## 设置背景不拦截鼠标事件，让按钮可以接收点击
	if has_node("Background"):
		$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("VBox/ResumeButton"):
		$VBox/ResumeButton.pressed.connect(_on_resume_pressed)
	if has_node("VBox/QuitButton"):
		$VBox/QuitButton.pressed.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	if not game_started:
		return
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func show_menu() -> void:
	visible = true
	get_tree().paused = true


func hide_menu() -> void:
	visible = false
	get_tree().paused = false


func toggle_pause() -> void:
	if visible:
		hide_menu()
	else:
		show_menu()


func _on_resume_pressed() -> void:
	hide_menu()


func _on_quit_pressed() -> void:
	visible = false
	get_tree().quit()

func quit_game() -> void:
	## 退出游戏
	get_tree().quit()
