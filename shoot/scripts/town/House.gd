extends Area3D

func _ready() -> void:
	add_to_group("interactable")

func interact() -> void:
	print("与房子交互！功能待添加...")
	## 后续可扩展：打开商店、NPC对话、升级装备等
