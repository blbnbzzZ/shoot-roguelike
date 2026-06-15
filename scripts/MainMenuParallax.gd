## 主菜单视差背景控制器（@tool 模式，支持编辑器内可视化编辑）
## 根据鼠标位置移动多层背景，创造深邃感
@tool
extends Control

## 图层配置（可在检查器中调整，使用外部 ParallaxLayerData 资源类）
@export var layers: Array[ParallaxLayerData] = []

## 鼠标跟踪
var _mouse_pos: Vector2 = Vector2.ZERO
var _viewport_size: Vector2 = Vector2.ZERO
var _is_editor: bool = false

## 每个图层的基准位置（编辑器里摆的位置，运行时以此为基准做视差偏移）
var _base_positions: Array[Vector2] = []


func _ready() -> void:
	_is_editor = Engine.is_editor_hint()
	_viewport_size = get_viewport_rect().size if not _is_editor else Vector2(1920, 1080)
	_mouse_pos = _viewport_size * 0.5

	## 如果检查器中未配置图层，自动加载默认的三个图层
	if layers.is_empty():
		_auto_load_default_layers()

	## 创建/更新图层子节点
	_setup_layer_nodes()

	## 记住每个图层的基准位置（编辑器里摆的位置）
	_save_base_positions()

	if not _is_editor:
		if visible:
			set_process(true)
		else:
			set_process(false)


func _auto_load_default_layers() -> void:
	var default_configs = [
		{"path": "res://assets/ui/parallax/layer0.png", "speed": 5.0, "scale": 1.3},
		{"path": "res://assets/ui/parallax/layer1.png", "speed": 15.0, "scale": 1.15},
		{"path": "res://assets/ui/parallax/layer2.png", "speed": 30.0, "scale": 1.05}
	]
	for config in default_configs:
		if FileAccess.file_exists(config.path):
			var data := ParallaxLayerData.new()
			data.texture_path = config.path
			data.parallax_speed = config.speed
			data.scale = config.scale
			layers.append(data)


func _setup_layer_nodes() -> void:
	## 为每个图层创建一个 TextureRect 子节点
	## @tool 模式下，这些节点在编辑器里也能看到
	for i in range(layers.size()):
		var data: ParallaxLayerData = layers[i]
		var node_name := "Layer%d" % i

		var tex_rect: TextureRect
		var is_new: bool = false
		if has_node(node_name):
			tex_rect = get_node(node_name)
		else:
			tex_rect = TextureRect.new()
			tex_rect.name = node_name
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tex_rect)
			if _is_editor:
				tex_rect.owner = get_tree().edited_scene_root
			is_new = true

		## 加载纹理（仅当路径变化时更新）
		if data.texture_path != "" and FileAccess.file_exists(data.texture_path):
			var new_tex = load(data.texture_path)
			if tex_rect.texture != new_tex:
				tex_rect.texture = new_tex
				is_new = true  ## 纹理变了，需要重新设置大小

		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE

		## 仅当节点是新创建的、或纹理刚变化时，才重置大小和位置
		## 否则保留编辑器里手动调整的值
		if is_new:
			var tex_size: Vector2 = tex_rect.texture.get_size() if tex_rect.texture else _viewport_size
			tex_rect.size = tex_size * data.scale
			tex_rect.position = (_viewport_size - tex_rect.size) * 0.5


func _save_base_positions() -> void:
	_base_positions.clear()
	for i in range(layers.size()):
		var node_name := "Layer%d" % i
		var tex_rect: TextureRect = get_node_or_null(node_name) as TextureRect
		if tex_rect:
			_base_positions.append(tex_rect.position)
		else:
			_base_positions.append(Vector2.ZERO)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion:
		_mouse_pos = event.position


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not visible:
		return

	## 计算鼠标偏移量（归一化到 -1 到 1）
	var offset: Vector2 = (_mouse_pos - _viewport_size * 0.5) / (_viewport_size * 0.5)

	## 更新每个图层位置：基准位置 + 视差偏移
	for i in range(layers.size()):
		var data: ParallaxLayerData = layers[i]
		var node_name := "Layer%d" % i
		var tex_rect: TextureRect = get_node_or_null(node_name) as TextureRect
		if not tex_rect:
			continue
		## 使用基准位置（编辑器里摆的位置）加上视差偏移
		var base_pos: Vector2 = _base_positions[i] if i < _base_positions.size() else tex_rect.position
		var move: Vector2 = offset * data.parallax_speed
		tex_rect.position = base_pos + move


func show_parallax() -> void:
	visible = true
	if not Engine.is_editor_hint():
		set_process(true)


func hide_parallax() -> void:
	visible = false
	if not Engine.is_editor_hint():
		set_process(false)
