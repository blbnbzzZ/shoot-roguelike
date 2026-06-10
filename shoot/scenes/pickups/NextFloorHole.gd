## 下一层地洞 - Boss死后出现在房间中心
class_name NextFloorHole
extends Area3D

signal player_entered()  ## 玩家踏入地洞

@export var hole_radius: float = 30.0


func _ready() -> void:
	add_to_group("next_floor_hole")
	body_entered.connect(_on_body_entered)
	## 初始时不检测，等待延迟启用
	monitoring = false
	_setup_collision()
	_create_visuals()


## 延迟启用检测
func set_monitoring_delayed(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(self):
		monitoring = true


func _setup_collision() -> void:
	## 查找或创建CollisionShape3D
	var col := $CollisionShape3D as CollisionShape3D
	if not col:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
	
	## 创建圆柱形碰撞体
	var shape := CylinderShape3D.new()
	shape.radius = hole_radius
	shape.height = 10.0
	col.shape = shape
	col.disabled = false


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		## 先禁用检测，再发信号，防止同一帧内重复触发
		monitoring = false
		player_entered.emit()


func _create_visuals() -> void:
	## 创建地洞视觉效果（如果不存在）
	var mesh := $HoleMesh as MeshInstance3D
	if not mesh:
		mesh = MeshInstance3D.new()
		mesh.name = "HoleMesh"
		add_child(mesh)
	
	## 使用圆锥体网格（上宽下窄）
	var cone := CylinderMesh.new()
	cone.top_radius = hole_radius * 0.8
	cone.bottom_radius = hole_radius * 0.3
	cone.height = 10.0
	mesh.mesh = cone
	
	## 黑色/暗紫色材质
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.0, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.0, 0.5, 1.0)
	mat.metallic = 0.8
	mat.roughness = 0.2
	mesh.material_override = mat
	
	## 创建粒子效果（紫色漩涡）
	var particles := $Particles as GPUParticles3D
	if not particles:
		particles = GPUParticles3D.new()
		particles.name = "Particles"
		add_child(particles)
	
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 1.5
	particles.local_coords = true
	
	## 设置粒子材质
	var mat_particle := ParticleProcessMaterial.new()
	mat_particle.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat_particle.emission_sphere_radius = hole_radius * 0.5
	mat_particle.direction = Vector3(0, -1, 0)
	mat_particle.spread = 10.0
	mat_particle.gravity = Vector3(0, -50.0, 0)
	mat_particle.initial_velocity_min = 5.0
	mat_particle.initial_velocity_max = 15.0
	mat_particle.color = Color(0.5, 0.0, 1.0, 1.0)
	mat_particle.scale_min = 0.5
	mat_particle.scale_max = 1.5
	
	particles.process_material = mat_particle
	
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.5
	particle_mesh.height = 1.0
	particles.draw_pass_1 = particle_mesh
