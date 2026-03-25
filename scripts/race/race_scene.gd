## RaceScene — Root script. Wires TrackGenerator → WaypointSystem → RaceManager → HUD.
extends Node3D

@onready var track_gen:    TrackGenerator = $TrackGenerator
@onready var waypoint_sys: WaypointSystem = $WaypointSystem
@onready var race_mgr:     RaceManager   = $RaceManager
@onready var hud:          HUD           = $HUD

func _ready() -> void:
	_build_world_environment()
	_build_lighting()
	_start_music()
	await get_tree().process_frame   # Let TrackGenerator._ready() run first
	await get_tree().physics_frame   # Ensure collision shapes are active before spawning vehicles
	waypoint_sys.set_waypoints(track_gen.waypoints)
	race_mgr.initialize(track_gen, waypoint_sys, hud)
	hud.set_minimap_data(waypoint_sys.waypoints, race_mgr.all_vehicles)

func _start_music() -> void:
	var music_path := "res://audio/The Hidden Gems of Ambient Drum and Bass - Vic^ (128k) (mp3cut.net).mp3"
	var stream := load(music_path)
	if stream:
		AudioManager.play_music(stream, 1.0)

func _build_world_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env      := Environment.new()

	# Deep space night sky
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.007, 0.016)

	# Minimal ambient — let the neon lights do the work
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.03, 0.04, 0.10)
	env.ambient_light_energy = 0.15

	# Atmospheric fog — blue depth haze, starts 120m out
	env.fog_enabled      = true
	env.fog_density      = 0.0028
	env.fog_light_color  = Color(0.04, 0.09, 0.26)
	env.fog_sun_scatter  = 0.0

	# Tone mapping — CRITICAL: without this, all lights above 1.0 look identical
	env.tonemap_mode     = 2  # Filmic
	env.tonemap_exposure = 1.8   # Brighter overall
	env.tonemap_white    = 16.0  # High white point — lets bright lights actually look bright

	# Glow — makes every emissive neon surface actually bloom on screen
	env.glow_enabled    = true
	env.glow_normalized = true
	env.glow_intensity  = 1.5
	env.glow_bloom      = 0.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.6  # Lower threshold — more things glow
	var gl := [0.5, 0.8, 1.0, 0.9, 0.6, 0.3, 0.1]
	for i in gl.size():
		env.set_glow_level(i, gl[i])

	# Contrast/brightness boost
	env.adjustment_enabled    = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast   = 1.2
	env.adjustment_saturation = 1.3

	env_node.environment = env
	add_child(env_node)

func _build_lighting() -> void:
	# Dim moonlight — just enough to see silhouettes, neons provide real lighting
	var sun := DirectionalLight3D.new()
	sun.light_color             = Color(0.3, 0.35, 0.6)
	sun.light_energy            = 0.12
	sun.shadow_enabled          = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.rotation_degrees        = Vector3(-48.0, 28.0, 0.0)
	add_child(sun)

	# Very faint fill — just barely separates ships from darkness
	var fill := DirectionalLight3D.new()
	fill.light_color    = Color(0.4, 0.3, 0.2)
	fill.light_energy   = 0.05
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-22.0, -145.0, 0.0)
	add_child(fill)

	race_mgr.countdown_tick.connect(hud.show_countdown)
	race_mgr.lap_completed.connect(_on_lap_completed)
	race_mgr.best_lap_set.connect(_on_best_lap)
	race_mgr.position_updated.connect(_on_position_updated)
	race_mgr.race_finished.connect(_on_race_finished)
	race_mgr.gap_updated.connect(hud.update_gap)

func _on_lap_completed(vehicle: IonVehicle, lap: int, time: float) -> void:
	if vehicle == race_mgr.player_vehicle:
		hud.update_lap(lap, race_mgr.total_laps, time)

func _on_best_lap(vehicle: IonVehicle, lap_time: float) -> void:
	if vehicle == race_mgr.player_vehicle:
		hud.update_best_lap(lap_time)

func _on_position_updated(positions: Array) -> void:
	if race_mgr.player_vehicle == null:
		return
	hud.update_position(race_mgr.player_vehicle.race_position, positions.size())

func _on_race_finished(results: Array) -> void:
	hud.show_results(results)
