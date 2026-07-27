extends Node2D

enum State { MENU, PLAYING, GAME_OVER }

const VIEWPORT_SIZE := Vector2(720, 1280)
const CENTER := Vector2(360, 640)
const INNER_RADIUS := 160.0
const OUTER_RADIUS := 280.0
const SHIP_RADIUS := 18.0
const OBSTACLE_ANGULAR_WIDTH := 0.35
const GEM_WINDOW := 0.12
const SAVE_PATH := "user://novadodge_save.json"

var state: int = State.MENU
var track_distance: float = 0.0
var angular_speed: float = 1.6
var ship_ring: int = 0
var ship_visual_radius: float = INNER_RADIUS

var score: int = 0
var best_score: int = 0

var obstacles: Array = []
var gems: Array = []

var next_obstacle_distance: float = 2.5
var next_gem_distance: float = 4.0

var rng := RandomNumberGenerator.new()

@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var best_label: Label = $CanvasLayer/BestLabel
@onready var center_label: Label = $CanvasLayer/CenterLabel


func _ready() -> void:
	rng.randomize()
	load_best_score()
	best_label.text = "Meilleur score : %d" % best_score
	reset_game()


func _input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	elif event is InputEventKey and event.pressed and not event.echo:
		tapped = true

	if not tapped:
		return

	match state:
		State.MENU:
			start_game()
		State.PLAYING:
			switch_ring()
		State.GAME_OVER:
			reset_game()


func switch_ring() -> void:
	ship_ring = 1 - ship_ring


func start_game() -> void:
	state = State.PLAYING
	center_label.visible = false


func reset_game() -> void:
	state = State.MENU
	track_distance = 0.0
	angular_speed = 1.6
	ship_ring = 0
	ship_visual_radius = INNER_RADIUS
	score = 0
	obstacles.clear()
	gems.clear()
	next_obstacle_distance = 2.5
	next_gem_distance = 4.0
	score_label.text = "0"
	center_label.text = "NOVA DODGE\nTouchez pour commencer"
	center_label.visible = true


func _process(delta: float) -> void:
	if state == State.PLAYING:
		angular_speed = min(3.2, 1.6 + track_distance * 0.01)
		track_distance += angular_speed * delta

		var target_radius: float = INNER_RADIUS if ship_ring == 0 else OUTER_RADIUS
		ship_visual_radius = lerp(ship_visual_radius, target_radius, min(1.0, delta * 12.0))

		spawn_if_needed()
		check_collisions_and_scoring()

	queue_redraw()


func spawn_if_needed() -> void:
	while next_obstacle_distance < track_distance + 6.0:
		obstacles.append({
			"distance": next_obstacle_distance,
			"ring": rng.randi_range(0, 1),
			"passed": false,
		})
		next_obstacle_distance += rng.randf_range(1.4, 2.2)

	while next_gem_distance < track_distance + 6.0:
		gems.append({
			"distance": next_gem_distance,
			"ring": rng.randi_range(0, 1),
			"collected": false,
		})
		next_gem_distance += rng.randf_range(2.0, 3.5)


func check_collisions_and_scoring() -> void:
	var half_width: float = OBSTACLE_ANGULAR_WIDTH * 0.5

	for obstacle in obstacles:
		if obstacle["passed"]:
			continue
		var d: float = obstacle["distance"]
		if obstacle["ring"] == ship_ring and abs(track_distance - d) <= half_width:
			game_over()
			return
		if track_distance - d > half_width:
			obstacle["passed"] = true
			score += 1
			score_label.text = str(score)

	for gem in gems:
		if gem["collected"]:
			continue
		var d2: float = gem["distance"]
		if gem["ring"] == ship_ring and abs(track_distance - d2) <= GEM_WINDOW:
			gem["collected"] = true
			score += 5
			score_label.text = str(score)

	if obstacles.size() > 0 and track_distance - obstacles[0]["distance"] > 20.0:
		obstacles.pop_front()
	if gems.size() > 0 and track_distance - gems[0]["distance"] > 20.0:
		gems.pop_front()


func game_over() -> void:
	state = State.GAME_OVER
	if score > best_score:
		best_score = score
		save_best_score()
	center_label.text = "PERDU !\nScore : %d\nMeilleur : %d\nTouchez pour rejouer" % [score, best_score]
	center_label.visible = true
	best_label.text = "Meilleur score : %d" % best_score


func load_best_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var content := f.get_as_text()
		var parsed = JSON.parse_string(content)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("best_score"):
			best_score = int(parsed["best_score"])


func save_best_score() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"best_score": best_score}))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color(0.04, 0.05, 0.09), true)

	draw_arc(CENTER, INNER_RADIUS, 0.0, TAU, 64, Color(0.24, 0.55, 0.95, 0.35), 2.0)
	draw_arc(CENTER, OUTER_RADIUS, 0.0, TAU, 64, Color(0.7, 0.3, 0.9, 0.35), 2.0)

	draw_circle(CENTER, 60.0, Color(1.0, 0.7, 0.2))

	var half_width: float = OBSTACLE_ANGULAR_WIDTH * 0.5
	for obstacle in obstacles:
		var ring_radius: float = INNER_RADIUS if obstacle["ring"] == 0 else OUTER_RADIUS
		var center_angle: float = fmod(obstacle["distance"], TAU)
		var color := Color(0.3, 0.3, 0.3, 0.3) if obstacle["passed"] else Color(1.0, 0.2, 0.3, 0.9)
		draw_arc(CENTER, ring_radius, center_angle - half_width, center_angle + half_width, 12, color, 14.0)

	for gem in gems:
		if gem["collected"]:
			continue
		var ring_radius2: float = INNER_RADIUS if gem["ring"] == 0 else OUTER_RADIUS
		var angle2: float = fmod(gem["distance"], TAU)
		var pos: Vector2 = CENTER + Vector2(cos(angle2), sin(angle2)) * ring_radius2
		draw_circle(pos, 10.0, Color(0.3, 1.0, 0.6))

	if state != State.MENU:
		var ship_angle: float = fmod(track_distance, TAU)
		var ship_pos: Vector2 = CENTER + Vector2(cos(ship_angle), sin(ship_angle)) * ship_visual_radius
		var facing: float = ship_angle + PI / 2.0
		var tip: Vector2 = ship_pos + Vector2(cos(facing), sin(facing)) * SHIP_RADIUS
		var left: Vector2 = ship_pos + Vector2(cos(facing + 2.5), sin(facing + 2.5)) * SHIP_RADIUS
		var right: Vector2 = ship_pos + Vector2(cos(facing - 2.5), sin(facing - 2.5)) * SHIP_RADIUS
		draw_polygon(
			PackedVector2Array([tip, left, right]),
			PackedColorArray([Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1)])
		)
	else:
		var menu_ship_pos: Vector2 = CENTER + Vector2(cos(-PI / 2.0), sin(-PI / 2.0)) * INNER_RADIUS
		draw_circle(menu_ship_pos, SHIP_RADIUS, Color(1, 1, 1))
