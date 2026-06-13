## 增益图标组件 — 显示单个增益图标，鼠标悬停显示说明
extends Control

class_name BuffIcon

@export var icon_texture: Texture2D :
	set(v):
		icon_texture = v
		if _icon_rect:
			_icon_rect.texture = v

@export var buff_name: String = ""
@export var buff_description: String = ""

signal tooltip_requested(text: String)
signal tooltip_hidden()

var _icon_rect: TextureRect
var _background: Panel


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	
	## 背景面板
	_background = Panel.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	style.set_border_width_all(2)
	style.border_color = Color(0.7, 0.5, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_background.add_theme_stylebox_override("panel", style)
	add_child(_background)
	
	## 图标
	_icon_rect = TextureRect.new()
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.texture = icon_texture
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)
	
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			## 左键点击可以移除增益（可选）
			pass


func _on_mouse_entered() -> void:
	## 高亮背景
	if _background:
		var style := _background.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = Color(1.0, 0.8, 0.3, 1.0)
			_background.add_theme_stylebox_override("panel", style)
	
	## 显示提示
	tooltip_requested.emit(buff_description)


func _on_mouse_exited() -> void:
	## 恢复背景
	if _background:
		var style := _background.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = Color(0.7, 0.5, 0.2, 1.0)
			_background.add_theme_stylebox_override("panel", style)
	
	tooltip_hidden.emit()
