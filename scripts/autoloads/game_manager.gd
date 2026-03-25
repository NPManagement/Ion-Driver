## GameManager — Global singleton managing game state, settings, and scene transitions.
extends Node

# ─── Signals ───────────────────────────────────────────────────────────────────
signal game_state_changed(new_state: GameState)
signal race_settings_changed()

# ─── Enums ─────────────────────────────────────────────────────────────────────
enum GameState { MENU, LOADING, RACING, PAUSED, RESULTS }

# ─── Constants ─────────────────────────────────────────────────────────────────
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_RACE      := "res://scenes/race.tscn"

const DIFFICULTY_NAMES := ["Novice", "Pro", "Elite", "Master"]
const LAP_OPTIONS      := [1, 3, 5, 7]

# ─── State ─────────────────────────────────────────────────────────────────────
var current_state: GameState = GameState.MENU
var selected_difficulty: int = 1     # 0-3
var selected_laps: int = 1           # Index into LAP_OPTIONS
var selected_track: int = 0          # 0 = Night City, 1 = Test
var selected_vehicle_color: Color = Color(0.1, 0.45, 0.95)

# Race results (set by race_manager on finish)
var last_race_results: Array = []    # [{name, time, position}]
var best_lap_time: float = INF
var player_finish_time: float = 0.0
var player_finish_position: int = 0

# ─── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()

func _input(event: InputEvent) -> void:
	var is_pause_key := event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
	if is_pause_key and (current_state == GameState.RACING or current_state == GameState.PAUSED):
		toggle_pause()

# ─── Scene Management ──────────────────────────────────────────────────────────
func start_race() -> void:
	get_tree().paused = false   # Always unpause — restart from results/pause must clear this
	AudioManager.stop_music(0.5)  # Fade out menu music
	_set_state(GameState.LOADING)
	get_tree().change_scene_to_file(SCENE_RACE)

func return_to_menu() -> void:
	get_tree().paused = false
	AudioManager.stop_music(0.5)  # Fade out race music
	_set_state(GameState.MENU)
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)

func toggle_pause() -> void:
	if current_state == GameState.RACING:
		get_tree().paused = true
		_set_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		get_tree().paused = false
		_set_state(GameState.RACING)

func on_race_started() -> void:
	_set_state(GameState.RACING)

func on_race_finished(results: Array, player_time: float, player_pos: int) -> void:
	last_race_results = results
	player_finish_time = player_time
	player_finish_position = player_pos
	if player_time < best_lap_time:
		best_lap_time = player_time
	_set_state(GameState.RESULTS)

# ─── Getters ───────────────────────────────────────────────────────────────────
func get_lap_count() -> int:
	return LAP_OPTIONS[selected_laps]

func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES[selected_difficulty]

func get_ai_speed_multiplier() -> float:
	return 0.75 + selected_difficulty * 0.1   # 0.75 – 1.05

func format_time(seconds: float) -> String:
	var mins  := int(seconds) / 60
	var secs  := int(seconds) % 60
	var ms    := int(fmod(seconds, 1.0) * 1000)
	return "%d:%02d.%03d" % [mins, secs, ms]

# ─── Persistence ───────────────────────────────────────────────────────────────
func _set_state(new_state: GameState) -> void:
	current_state = new_state
	emit_signal("game_state_changed", new_state)

func _load_settings() -> void:
	pass  # Extend with ConfigFile for persistent settings

func _save_settings() -> void:
	pass
