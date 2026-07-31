extends Node3D

# ---------------------------------------------------------------------------
# Naufrage — Étape 1 : scène de base (île, personnage, jour/nuit)
# Construit entièrement par code pour rester simple à relire/modifier.
# ---------------------------------------------------------------------------

const ISLAND_RADIUS := 40.0
const OCEAN_SIZE := 400.0
const PLAYER_HEIGHT := 1.8
const PLAYER_RADIUS := 0.4
const MOVE_SPEED := 5.0
const LOOK_SENSITIVITY := 0.005
const DAY_LENGTH := 180.0
const JOYSTICK_MAX_RADIUS := 60.0
const GRAVITY := 9.8

var player: CharacterBody3D
var camera: Camera3D
var sun: DirectionalLight3D

var time_of_day: float = 0.3

var move_touch_index: int = -1
var move_touch_start: Vector2 = Vector2.ZERO
var move_touch_current: Vector2 = Vector2.ZERO
var look_touch_index: int = -1

var camera_yaw: float = 0.0
var camera_pitch: float = 0.0

var instruction_label: Label
var instruction_timer: float = 0.0


func _ready() -> void:
	build_environment()
	build_terrain()
	build_player()
	build_touch_ui()


# ---------------------------------------------------------------------------
# Construction de la scène
# ---------------------------------------------------------------------------

func build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.5, 0.85)
	sky_material.sky_horizon_color = Color(0.75, 0.8, 0.85)
	sky_material.ground_bottom_color = Color(0.15, 0.18, 0.22)
	sky_material.ground_horizon_color = Color(0.75, 0.8, 0.85)
	sky.sky_material = sky_material
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.76, 0.82)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35

	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)


func build_terrain() -> void:
	var ocean := MeshInstance3D.new()
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(OCEAN_SIZE, OCEAN_SIZE)
	ocean.mesh = ocean_mesh
	var ocean_mat := StandardMaterial3D.new()
	ocean_mat.albedo_color = Color(0.05, 0.25, 0.4)
	ocean_mat.roughness = 0.08
	ocean_mat.metallic = 0.2
	ocean.material_override = ocean_mat
	ocean.position = Vector3(0, -0.6, 0)
	add_child(ocean)

	var ground_body := StaticBody3D.new()
	var ground_mesh_instance := MeshInstance3D.new()
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = ISLAND_RADIUS
	ground_mesh.bottom_radius = ISLAND_RADIUS * 1.15
	ground_mesh.height = 2.0
	ground_mesh.radial_segments = 28
	ground_mesh_instance.mesh = ground_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.56, 0.5, 0.32)
	ground_mat.roughness = 0.95
	ground_mesh_instance.material_override = ground_mat
	ground_body.add_child(ground_mesh_instance)

	var ground_shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = ISLAND_RADIUS
	cyl_shape.height = 2.0
	ground_shape.shape = cyl_shape
	ground_body.add_child(ground_shape)

	ground_body.position = Vector3(0, -1.0, 0)
	add_child(ground_body)

	spawn_shipwreck()

	for i in range(14):
		var angle: float = randf() * TAU
		var r: float = randf_range(6.0, ISLAND_RADIUS - 4.0)
		spawn_tree(Vector3(cos(angle) * r, 0.0, sin(angle) * r))

	for i in range(8):
		var angle2: float = randf() * TAU
		var r2: float = randf_range(4.0, ISLAND_RADIUS - 3.0)
		spawn_rock(Vector3(cos(angle2) * r2, 0.0, sin(angle2) * r2))


func spawn_tree(pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 3.5
	trunk.mesh = trunk_mesh
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.28, 0.15)
	trunk.material_override = trunk_mat
	trunk.position = pos + Vector3(0, 1.75, 0)
	add_child(trunk)

	for j in range(4):
		var frond := MeshInstance3D.new()
		var frond_mesh := SphereMesh.new()
		frond_mesh.radius = 0.9
		frond_mesh.height = 1.2
		frond.mesh = frond_mesh
		var frond_mat := StandardMaterial3D.new()
		frond_mat.albedo_color = Color(0.2, 0.5, 0.25)
		frond.material_override = frond_mat
		var a: float = (TAU / 4.0) * j
		frond.position = pos + Vector3(cos(a) * 0.6, 3.6, sin(a) * 0.6)
		frond.scale = Vector3(1.2, 0.4, 1.2)
		add_child(frond)


func spawn_rock(pos: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = randf_range(0.4, 0.9)
	rock.mesh = rock_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.45, 0.48)
	mat.roughness = 1.0
	rock.material_override = mat
	rock.position = pos + Vector3(0, rock_mesh.radius * 0.4, 0)
	rock.scale = Vector3(1.0, randf_range(0.5, 0.8), 1.0)
	add_child(rock)


func spawn_shipwreck() -> void:
	for i in range(3):
		var box := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(4.0, 1.2, 1.5)
		box.mesh = box_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.18, 0.15)
		mat.roughness = 0.9
		box.material_override = mat
		box.position = Vector3(6.0 + i * 1.5, 0.4, 10.0 - i * 0.8)
		box.rotation_degrees = Vector3(0, 15 * i, 10 + i * 5)
		add_child(box)


func build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 3, 22)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	collision.shape = capsule
	player.add_child(collision)

	camera = Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, PLAYER_HEIGHT * 0.4, 0)
	player.add_child(camera)

	add_child(player)


func build_touch_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var label := Label.new()
	label.text = "Glissez à GAUCHE pour marcher\nGlissez à DROITE pour regarder\n(souris + WASD sur ordinateur)"
	label.add_theme_font_size_override("font_size", 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(340, 540)
	label.size = Vector2(600, 120)
	canvas.add_child(label)

	instruction_label = label
	instruction_timer = 6.0


# ---------------------------------------------------------------------------
# Entrées (tactile + souris/clavier pour tester sur ordinateur)
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var vw: float = get_viewport().get_visible_rect().size.x

	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < vw / 2.0 and move_touch_index == -1:
				move_touch_index = event.index
				move_touch_start = event.position
				move_touch_current = event.position
			elif event.position.x >= vw / 2.0 and look_touch_index == -1:
				look_touch_index = event.index
		else:
			if event.index == move_touch_index:
				move_touch_index = -1
			elif event.index == look_touch_index:
				look_touch_index = -1

	elif event is InputEventScreenDrag:
		if event.index == move_touch_index:
			move_touch_current = event.position
		elif event.index == look_touch_index:
			apply_look(event.relative)

	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			apply_look(event.relative)


func apply_look(rel: Vector2) -> void:
	camera_yaw -= rel.x * LOOK_SENSITIVITY
	camera_pitch -= rel.y * LOOK_SENSITIVITY
	camera_pitch = clamp(camera_pitch, -1.3, 1.3)


# ---------------------------------------------------------------------------
# Boucle principale
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	player.rotation.y = camera_yaw
	camera.rotation.x = camera_pitch

	var forward: Vector3 = -player.global_transform.basis.z
	var right: Vector3 = player.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var move_input := Vector2.ZERO
	if move_touch_index != -1:
		var raw: Vector2 = move_touch_current - move_touch_start
		if raw.length() > 0.001:
			var mag: float = clamp(raw.length() / JOYSTICK_MAX_RADIUS, 0.0, 1.0)
			var dir2d: Vector2 = raw.normalized()
			move_input = Vector2(dir2d.x, -dir2d.y) * mag
	else:
		if Input.is_physical_key_pressed(KEY_W):
			move_input.y += 1.0
		if Input.is_physical_key_pressed(KEY_S):
			move_input.y -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			move_input.x += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			move_input.x -= 1.0
		if move_input.length() > 1.0:
			move_input = move_input.normalized()

	var move_dir3d: Vector3 = right * move_input.x + forward * move_input.y

	player.velocity.x = move_dir3d.x * MOVE_SPEED
	player.velocity.z = move_dir3d.z * MOVE_SPEED

	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	else:
		player.velocity.y = 0.0

	player.move_and_slide()


func _process(delta: float) -> void:
	update_day_night(delta)

	if instruction_timer > 0.0:
		instruction_timer -= delta
		if instruction_timer <= 0.0:
			instruction_label.visible = false


func update_day_night(delta: float) -> void:
	time_of_day += delta / DAY_LENGTH
	if time_of_day > 1.0:
		time_of_day -= 1.0

	sun.rotation.x = (time_of_day - 0.25) * TAU

	var brightness: float = clamp(sin(time_of_day * TAU), 0.05, 1.0)
	sun.light_energy = lerp(0.15, 1.3, brightness)

	var day_color := Color(1.0, 0.95, 0.85)
	var night_color := Color(0.35, 0.45, 0.7)
	sun.light_color = day_color.lerp(night_color, 1.0 - brightness)