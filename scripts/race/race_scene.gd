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

	# Pure black sky
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)

	# No ambient light — only neons illuminate
	env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	env.ambient_light_energy = 0.0

	# No fog
	env.fog_enabled      = false

	# Tone mapping
	env.tonemap_mode     = 2  # Filmic
	env.tonemap_exposure = 1.0
	env.tonemap_white    = 16.0

	# Glow — makes every emissive neon surface actually bloom on screen
	env.glow_enabled    = true
	env.glow_normalized = true
	env.glow_intensity  = 1.5
	env.glow_bloom      = 0.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.6
	var gl := [0.5, 0.8, 1.0, 0.9, 0.6, 0.3, 0.1]
	for i in gl.size():
		env.set_glow_level(i, gl[i])

	# No brightness/contrast boost
	env.adjustment_enabled    = false

	env_node.environment = env
	add_child(env_node)

func _build_lighting() -> void:
	# No sun/moon — all lighting comes from track neons
	pass

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
