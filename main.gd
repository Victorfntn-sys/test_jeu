extends Node2D

enum State { LEVEL_SELECT, PLAYING, LEVEL_CLEARED, GAME_OVER }
enum ObstacleType { STATIC, MOVING, HEAVY }
enum PowerType { SHIELD, SLOWMO, MULTIPLIER }

const VIEWPORT_SIZE := Vector2(720, 1280)
const CENTER := Vector2(360, 640)
const INNER_RADIUS := 160.0
const OUTER_RADIUS := 280.0
const SHIP_RADIUS := 18.0
const OBSTACLE_ANGULAR_WIDTH := 0.35
const HEAVY_ANGULAR_WIDTH := 0.5
const GEM_WINDOW := 0.12
const POWERUP_WINDOW := 0.12
const SAVE_PATH := "user://novadodge_save.json"

const MAX_LIVES := 3
const HIT_INVINCIBILITY_TIME := 1.2
const SLOWMO_DURATION := 4.0
const SLOWMO_FACTOR := 0.55
const MULT_DURATION := 6.0

const LEVELS := [
	{"target": 15, "base_speed": 1.6, "speed_cap": 2.0, "types": [ObstacleType.STATIC], "gap_min": 1.6, "gap_max": 2.4},
	{"target": 30, "base_speed": 1.7, "speed_cap": 2.2, "types": [ObstacleType.STATIC], "gap_min": 1.5, "gap_max": 2.3},
	{"target": 50, "base_speed": 1.8, "speed_cap": 2.6, "types": [ObstacleType.STATIC, ObstacleType.MOVING], "gap_min": 1.4, "gap_max": 2.2},
	{"target": 75, "base_speed": 1.9, "speed_cap": 2.9, "types": [ObstacleType.STATIC, ObstacleType.MOVING], "gap_min": 1.3, "gap_max": 2.1},
	{"target": 100, "base_speed": 2.0, "speed_cap": 3.2, "types": [ObstacleType.STATIC, ObstacleType.MOVING, ObstacleType.HEAVY], "gap_min": 1.3, "gap_max": 2.0},
	{"target": 140, "base_speed": 2.1, "speed_cap": 3.4, "types": [ObstacleType.STATIC, ObstacleType.MOVING, ObstacleType.HEAVY], "gap_min": 1.2, "gap_max": 1.9},
	{"target": 190, "base_speed": 2.2, "speed_cap": 3.6, "types": [ObstacleType.STATIC, ObstacleType.MOVING, ObstacleType.HEAVY], "gap_min": 1.15, "gap_max": 1.85},
	{"target": 250, "base_speed": 2.3, "speed_cap": 3.8, "types": [ObstacleType.STATIC, ObstacleType.MOVING, ObstacleType.HEAVY], "gap_min": 1.1, "gap_max": 1.8},
]

var state: int = State.LEVEL_SELECT
var current_level_index: int = 0

var track_distance: float = 0.0
var angular_speed: float = 1.6
var ship_ring: int = 0
var ship_visual_radius: float = INNER_RADIUS

var score: int = 0

var lives: int = MAX_LIVES
var invincible_timer: float = 0.0
var shield_active: bool = false
var slow_timer: float = 0.0
var mult_timer: float = 0.0

var combo: int = 0
var combo_multiplier: int = 1

var obstacles: Array = []
var gems: Array = []
var powerups: Array = []

var next_obstacle_distance: float = 2.5
var next_gem_distance: float = 4.0
var next_powerup_distance: float = 9.0

var unlocked_level: int = 0
var level_best: Array = []
var level_stars: Array = []

var rng := RandomNumberGenerator.new()
var level_buttons: Array = []

@onready var play_hud: Control = $CanvasLayer/PlayHud
@onready var score_label: Label = $CanvasLayer/PlayHud/ScoreLabel
@onready var combo_label: Label = $CanvasLayer/PlayHud/ComboLabel
@onready var target_label: Label = $CanvasLayer/PlayHud/TargetLabel

@onready var level_select_root: Control = $CanvasLayer/LevelSelectRoot
@onready var cleared_root: Control = $CanvasLayer/ClearedRoot
@onready var gameover_root: Control = $CanvasLayer/GameOverRoot


func _ready() -> void:
	rng.randomize()
	for i in range(LEVELS.size()):
		level_best.append(0)
		level_stars.append(0)
	load_progress()
	build_level_select_ui()
	build_cleared_ui()
	build_gameover_ui()
	show_level_select()


func _input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	elif event is InputEventKey and event.pressed and not event.echo:
		tapped = true
	if tapped:
		ship_ring = 1 - ship_ring


# ---------------------------------------------------------------------------
# UI construction (built in code so the .tscn stays simple and safe to edit)
# ---------------------------------------------------------------------------

func build_level_select_ui() -> void:
	var title := Label.new()
	title.text = "NOVA DODGE"
	title.add_theme_font_size_override("font_size", 44)
	title.position = Vector2(0, 90)
	title.size = Vector2(720, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_select_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choisissez un niveau"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	subtitle.position = Vector2(0, 155)
	subtitle.size = Vector2(720, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_select_root.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.position = Vector2(90, 260)
	level_select_root.add_child(grid)

	level_buttons.clear()
	for i in range(LEVELS.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 160)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(_on_level_button_pressed.bind(i))
		grid.add_child(btn)
		level_buttons.append(btn)

	refresh_level_select_ui()


func refresh_level_select_ui() -> void:
	for i in range(LEVELS.size()):
		var btn: Button = level_buttons[i]
		var stars: int = level_stars[i]
		var star_text := ""
		for s in range(3):
			star_text += "*" if s < stars else "-"
		var locked: bool = i > unlocked_level
		btn.disabled = locked
		if locked:
			btn.text = str(i + 1)
		else:
			btn.text = "%d\n%s\n%d" % [i + 1, star_text, level_best[i]]


func build_message_panel(root: Control, title_text: String, color: Color) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 420)
	title.size = Vector2(720, 60)
	root.add_child(title)


func make_menu_button(text: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 26)
	btn.position = pos
	btn.size = Vector2(360, 70)
	return btn


func build_cleared_ui() -> void:
	build_message_panel(cleared_root, "NIVEAU TERMINE", Color(0.4, 0.85, 1.0))

	var stars_label := Label.new()
	stars_label.name = "StarsLabel"
	stars_label.add_theme_font_size_override("font_size", 40)
	stars_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.position = Vector2(0, 500)
	stars_label.size = Vector2(720, 60)
	cleared_root.add_child(stars_label)

	var score_label2 := Label.new()
	score_label2.name = "ScoreLabel2"
	score_label2.add_theme_font_size_override("font_size", 24)
	score_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label2.position = Vector2(0, 570)
	score_label2.size = Vector2(720, 40)
	cleared_root.add_child(score_label2)

	var next_btn := make_menu_button("Niveau suivant", Vector2(180, 680))
	next_btn.name = "NextButton"
	next_btn.pressed.connect(_on_next_pressed)
	cleared_root.add_child(next_btn)

	var retry_btn := make_menu_button("Rejouer", Vector2(180, 770))
	retry_btn.pressed.connect(_on_retry_pressed)
	cleared_root.add_child(retry_btn)

	var menu_btn := make_menu_button("Menu des niveaux", Vector2(180, 860))
	menu_btn.pressed.connect(_on_menu_pressed)
	cleared_root.add_child(menu_btn)


func build_gameover_ui() -> void:
	build_message_panel(gameover_root, "PERDU", Color(1.0, 0.3, 0.35))

	var score_label3 := Label.new()
	score_label3.name = "ScoreLabel3"
	score_label3.add_theme_font_size_override("font_size", 24)
	score_label3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label3.position = Vector2(0, 560)
	score_label3.size = Vector2(720, 40)
	gameover_root.add_child(score_label3)

	var retry_btn := make_menu_button("Reessayer", Vector2(180, 680))
	retry_btn.pressed.connect(_on_retry_pressed)
	gameover_root.add_child(retry_btn)

	var menu_btn := make_menu_button("Menu des niveaux", Vector2(180, 770))
	menu_btn.pressed.connect(_on_menu_pressed)
	gameover_root.add_child(menu_btn)


func _on_level_button_pressed(index: int) -> void:
	start_level(index)


func _on_next_pressed() -> void:
	start_level(current_level_index + 1)


func _on_retry_pressed() -> void:
	start_level(current_level_index)


func _on_menu_pressed() -> void:
	show_level_select()


# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------

func show_level_select() -> void:
	state = State.LEVEL_SELECT
	refresh_level_select_ui()
	level_select_root.visible = true
	cleared_root.visible = false
	gameover_root.visible = false
	play_hud.visible = false


func start_level(index: int) -> void:
	if index < 0 or index >= LEVELS.size():
		show_level_select()
		return

	current_level_index = index
	var cfg: Dictionary = LEVELS[index]

	state = State.PLAYING
	track_distance = 0.0
	angular_speed = float(cfg["base_speed"])
	ship_ring = 0
	ship_visual_radius = INNER_RADIUS
	score = 0
	lives = MAX_LIVES
	invincible_timer = 0.0
	shield_active = false
	slow_timer = 0.0
	mult_timer = 0.0
	combo = 0
	combo_multiplier = 1
	obstacles.clear()
	gems.clear()
	powerups.clear()
	next_obstacle_distance = 2.5
	next_gem_distance = 4.0
	next_powerup_distance = 9.0

	score_label.text = "0"
	combo_label.text = ""
	target_label.text = "Objectif : %d" % int(cfg["target"])

	level_select_root.visible = false
	cleared_root.visible = false
	gameover_root.visible = false
	play_hud.visible = true


# ---------------------------------------------------------------------------
# Gameplay loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if state == State.PLAYING:
		var cfg: Dictionary = LEVELS[current_level_index]
		angular_speed = min(float(cfg["speed_cap"]), float(cfg["base_speed"]) + track_distance * 0.008)
		var effective_speed: float = angular_speed
		if slow_timer > 0.0:
			slow_timer = max(0.0, slow_timer - delta)
			effective_speed *= SLOWMO_FACTOR
		if mult_timer > 0.0:
			mult_timer = max(0.0, mult_timer - delta)
		if invincible_timer > 0.0:
			invincible_timer = max(0.0, invincible_timer - delta)

		track_distance += effective_speed * delta

		var target_radius: float = INNER_RADIUS if ship_ring == 0 else OUTER_RADIUS
		ship_visual_radius = lerp(ship_visual_radius, target_radius, min(1.0, delta * 12.0))

		spawn_if_needed(cfg)
		check_collisions_and_scoring(cfg)

	queue_redraw()


func obstacle_half_width(obstacle: Dictionary) -> float:
	if obstacle["type"] == ObstacleType.HEAVY:
		return HEAVY_ANGULAR_WIDTH * 0.5
	return OBSTACLE_ANGULAR_WIDTH * 0.5


func spawn_if_needed(cfg: Dictionary) -> void:
	var available_types: Array = cfg["types"]

	while next_obstacle_distance < track_distance + 6.0:
		var chosen_type: int = available_types[rng.randi_range(0, available_types.size() - 1)]
		var start_ring: int = rng.randi_range(0, 1)
		var data := {
			"distance": next_obstacle_distance,
			"ring": start_ring,
			"type": chosen_type,
			"passed": false,
			"flipped": false,
			"flip_at": 0.0,
		}
		if chosen_type == ObstacleType.MOVING:
			data["flip_at"] = next_obstacle_distance - rng.randf_range(0.9, 1.3)
		obstacles.append(data)
		next_obstacle_distance += rng.randf_range(float(cfg["gap_min"]), float(cfg["gap_max"]))

	while next_gem_distance < track_distance + 6.0:
		gems.append({
			"distance": next_gem_distance,
			"ring": rng.randi_range(0, 1),
			"collected": false,
		})
		next_gem_distance += rng.randf_range(2.0, 3.5)

	while next_powerup_distance < track_distance + 6.0:
		powerups.append({
			"distance": next_powerup_distance,
			"ring": rng.randi_range(0, 1),
			"type": rng.randi_range(0, 2),
			"collected": false,
		})
		next_powerup_distance += rng.randf_range(8.0, 13.0)


func check_collisions_and_scoring(cfg: Dictionary) -> void:
	var target: int = int(cfg["target"])

	for obstacle in obstacles:
		if obstacle["passed"]:
			continue

		if obstacle["type"] == ObstacleType.MOVING and not obstacle["flipped"] and track_distance >= obstacle["flip_at"]:
			obstacle["ring"] = 1 - int(obstacle["ring"])
			obstacle["flipped"] = true

		var d: float = obstacle["distance"]
		var half_width: float = obstacle_half_width(obstacle)

		if obstacle["ring"] == ship_ring and abs(track_distance - d) <= half_width:
			if shield_active:
				shield_active = false
				obstacle["passed"] = true
			elif invincible_timer > 0.0:
				obstacle["passed"] = true
			else:
				var life_cost: int = 2 if obstacle["type"] == ObstacleType.HEAVY else 1
				lives -= life_cost
				combo = 0
				combo_multiplier = 1
				combo_label.text = ""
				invincible_timer = HIT_INVINCIBILITY_TIME
				obstacle["passed"] = true
				if lives <= 0:
					lives = 0
					trigger_game_over(cfg)
					return
		elif track_distance - d > half_width:
			obstacle["passed"] = true
			combo += 1
			combo_multiplier = min(4, 1 + int(combo / 5))
			combo_label.text = ("x%d" % combo_multiplier) if combo_multiplier > 1 else ""
			var base_value: int = 3 if obstacle["type"] == ObstacleType.HEAVY else 1
			var mult: int = 2 if mult_timer > 0.0 else 1
			score += base_value * combo_multiplier * mult
			score_label.text = str(score)
			if score >= target:
				trigger_level_cleared(cfg)
				return

	for gem in gems:
		if gem["collected"]:
			continue
		var dg: float = gem["distance"]
		if gem["ring"] == ship_ring and abs(track_distance - dg) <= GEM_WINDOW:
			gem["collected"] = true
			var mult2: int = 2 if mult_timer > 0.0 else 1
			score += 5 * mult2
			score_label.text = str(score)
			if score >= target:
				trigger_level_cleared(cfg)
				return

	for powerup in powerups:
		if powerup["collected"]:
			continue
		var dp: float = powerup["distance"]
		if powerup["ring"] == ship_ring and abs(track_distance - dp) <= POWERUP_WINDOW:
			powerup["collected"] = true
			match powerup["type"]:
				PowerType.SHIELD:
					shield_active = true
				PowerType.SLOWMO:
					slow_timer = SLOWMO_DURATION
				PowerType.MULTIPLIER:
					mult_timer = MULT_DURATION

	if obstacles.size() > 0 and track_distance - obstacles[0]["distance"] > 20.0:
		obstacles.pop_front()
	if gems.size() > 0 and track_distance - gems[0]["distance"] > 20.0:
		gems.pop_front()
	if powerups.size() > 0 and track_distance - powerups[0]["distance"] > 20.0:
		powerups.pop_front()


func trigger_level_cleared(cfg: Dictionary) -> void:
	state = State.LEVEL_CLEARED
	var target: int = int(cfg["target"])

	var stars := 1
	if score >= target * 2:
		stars = 3
	elif score >= int(target * 1.5):
		stars = 2

	if score > level_best[current_level_index]:
		level_best[current_level_index] = score
	if stars > level_stars[current_level_index]:
		level_stars[current_level_index] = stars
	if current_level_index + 1 < LEVELS.size():
		unlocked_level = max(unlocked_level, current_level_index + 1)
	save_progress()

	var stars_label: Label = cleared_root.get_node("StarsLabel")
	var star_text := ""
	for s in range(3):
		star_text += "*" if s < stars else "-"
	stars_label.text = star_text

	var score_label2: Label = cleared_root.get_node("ScoreLabel2")
	score_label2.text = "Score : %d  (objectif : %d)" % [score, target]

	var next_btn: Button = cleared_root.get_node("NextButton")
	var has_next: bool = current_level_index + 1 < LEVELS.size()
	next_btn.disabled = not has_next
	next_btn.text = "Niveau suivant" if has_next else "Tous les niveaux termines"

	play_hud.visible = false
	cleared_root.visible = true


func trigger_game_over(cfg: Dictionary) -> void:
	state = State.GAME_OVER

	if score > level_best[current_level_index]:
		level_best[current_level_index] = score
		save_progress()

	var score_label3: Label = gameover_root.get_node("ScoreLabel3")
	score_label3.text = "Score : %d  (objectif : %d)" % [score, int(cfg["target"])]

	play_hud.visible = false
	gameover_root.visible = true


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content := f.get_as_text()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.has("unlocked_level"):
		unlocked_level = int(parsed["unlocked_level"])
	if parsed.has("level_best"):
		var arr: Array = parsed["level_best"]
		for i in range(min(arr.size(), level_best.size())):
			level_best[i] = int(arr[i])
	if parsed.has("level_stars"):
		var arr2: Array = parsed["level_stars"]
		for i in range(min(arr2.size(), level_stars.size())):
			level_stars[i] = int(arr2[i])


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"unlocked_level": unlocked_level,
		"level_best": level_best,
		"level_stars": level_stars,
	}))


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color(0.04, 0.05, 0.09), true)

	if state == State.LEVEL_SELECT:
		return

	draw_arc(CENTER, INNER_RADIUS, 0.0, TAU, 64, Color(0.24, 0.55, 0.95, 0.35), 2.0)
	draw_arc(CENTER, OUTER_RADIUS, 0.0, TAU, 64, Color(0.7, 0.3, 0.9, 0.35), 2.0)

	draw_circle(CENTER, 60.0, Color(1.0, 0.7, 0.2))

	for obstacle in obstacles:
		var ring_radius: float = INNER_RADIUS if obstacle["ring"] == 0 else OUTER_RADIUS
		var center_angle: float = fmod(obstacle["distance"], TAU)
		var half_width: float = obstacle_half_width(obstacle)
		var color: Color
		if obstacle["passed"]:
			color = Color(0.3, 0.3, 0.3, 0.3)
		elif obstacle["type"] == ObstacleType.HEAVY:
			color = Color(0.7, 0.25, 0.95, 0.9)
		elif obstacle["type"] == ObstacleType.MOVING:
			color = Color(1.0, 0.6, 0.15, 0.9)
		else:
			color = Color(1.0, 0.2, 0.3, 0.9)
		var thickness: float = 20.0 if obstacle["type"] == ObstacleType.HEAVY else 14.0
		draw_arc(CENTER, ring_radius, center_angle - half_width, center_angle + half_width, 12, color, thickness)

	for gem in gems:
		if gem["collected"]:
			continue
		var ring_radius2: float = INNER_RADIUS if gem["ring"] == 0 else OUTER_RADIUS
		var angle2: float = fmod(gem["distance"], TAU)
		var pos: Vector2 = CENTER + Vector2(cos(angle2), sin(angle2)) * ring_radius2
		draw_circle(pos, 10.0, Color(0.3, 1.0, 0.6))

	for powerup in powerups:
		if powerup["collected"]:
			continue
		var ring_radius3: float = INNER_RADIUS if powerup["ring"] == 0 else OUTER_RADIUS
		var angle3: float = fmod(powerup["distance"], TAU)
		var pos3: Vector2 = CENTER + Vector2(cos(angle3), sin(angle3)) * ring_radius3
		var pcolor: Color
		match powerup["type"]:
			PowerType.SHIELD:
				pcolor = Color(0.3, 0.9, 1.0)
			PowerType.SLOWMO:
				pcolor = Color(0.4, 0.6, 1.0)
			_:
				pcolor = Color(1.0, 0.85, 0.2)
		var diamond := PackedVector2Array([
			pos3 + Vector2(0, -12),
			pos3 + Vector2(12, 0),
			pos3 + Vector2(0, 12),
			pos3 + Vector2(-12, 0),
		])
		draw_polygon(diamond, PackedColorArray([pcolor, pcolor, pcolor, pcolor]))

	draw_status_icons()

	var ship_angle: float = fmod(track_distance, TAU)
	var ship_pos: Vector2 = CENTER + Vector2(cos(ship_angle), sin(ship_angle)) * ship_visual_radius
	var facing: float = ship_angle + PI / 2.0
	var tip: Vector2 = ship_pos + Vector2(cos(facing), sin(facing)) * SHIP_RADIUS
	var left: Vector2 = ship_pos + Vector2(cos(facing + 2.5), sin(facing + 2.5)) * SHIP_RADIUS
	var right: Vector2 = ship_pos + Vector2(cos(facing - 2.5), sin(facing - 2.5)) * SHIP_RADIUS
	var ship_color := Color(1, 1, 1)
	if shield_active:
		ship_color = Color(0.3, 0.9, 1.0)
	var visible_ship := true
	if invincible_timer > 0.0 and not shield_active:
		visible_ship = fmod(invincible_timer, 0.2) > 0.1
	if visible_ship:
		draw_polygon(
			PackedVector2Array([tip, left, right]),
			PackedColorArray([ship_color, ship_color, ship_color])
		)


func draw_status_icons() -> void:
	for i in range(MAX_LIVES):
		var pip_pos := Vector2(700.0 - i * 34.0, 200.0)
		if i < lives:
			draw_circle(pip_pos, 10.0, Color(1.0, 0.35, 0.4))
		else:
			draw_arc(pip_pos, 10.0, 0.0, TAU, 16, Color(0.4, 0.4, 0.5, 0.6), 2.0)

	var icon_x := 700.0
	var icon_y := 236.0

	if shield_active:
		draw_circle(Vector2(icon_x, icon_y), 10.0, Color(0.3, 0.9, 1.0, 0.9))
		icon_x -= 34.0

	if slow_timer > 0.0:
		var frac: float = slow_timer / SLOWMO_DURATION
		draw_arc(Vector2(icon_x, icon_y), 10.0, 0.0, TAU, 16, Color(0.4, 0.6, 1.0, 0.25), 4.0)
		draw_arc(Vector2(icon_x, icon_y), 10.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 16, Color(0.4, 0.6, 1.0, 0.95), 4.0)
		icon_x -= 34.0

	if mult_timer > 0.0:
		var frac2: float = mult_timer / MULT_DURATION
		draw_arc(Vector2(icon_x, icon_y), 10.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.2, 0.25), 4.0)
		draw_arc(Vector2(icon_x, icon_y), 10.0, -PI / 2.0, -PI / 2.0 + TAU * frac2, 16, Color(1.0, 0.85, 0.2, 0.95), 4.0)
