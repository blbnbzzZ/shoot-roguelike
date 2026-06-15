## 暂停菜单场景
extends Control

signal resume_game
signal quit_to_menu

## 用独立变量追踪暂停状态，不与 visible/get_tree().paused 产生竞争
var _is_paused: bool = false


func _ready() -> void:
	hide_menu_deferred()
	## 始终处理输入，确保游戏暂停后仍能响应 ESC
	process_mode = Node.PROCESS_MODE_ALWAYS
	## 设置背景不拦截鼠标事件，让按钮可以接收点击
	if has_node("Background"):
		$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("VBox/ResumeButton"):
		$VBox/ResumeButton.pressed.connect(_on_resume_pressed)
	if has_node("VBox/QuitButton"):
		$VBox/QuitButton.pressed.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	## 响应 ESC 切换暂停状态
	## process_mode 已设为 ALWAYS，暂停后仍能接收输入
	## 调用 set_input_as_handled 防止同一事件被其他节点重复处理
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	visible = true
	_is_paused = true
	get_tree().paused = true


func hide_menu() -> void:
	visible = false
	_is_paused = false
	get_tree().paused = false


## 在 _ready 中安全调用，避免暂停状态在 frame 初期不一致
func hide_menu_deferred() -> void:
	visible = false
	_is_paused = false
	get_tree().paused = false


func toggle_pause() -> void:
	## 用 _is_paused 作为唯一真相源，避免 visible 与 paused 状态不同步
	if _is_paused:
		hide_menu()
	else:
		show_menu()


func _on_resume_pressed() -> void:
	hide_menu()


func _on_quit_pressed() -> void:
	visible = false
	get_tree().quit()
