## RaceManager — Orchestrates a race: spawns vehicles, manages laps, handles results.
extends Node
class_name RaceManager

# ─── Signals ───────────────────────────────────────────────────────────────────
signal race_started()
signal lap_completed(vehicle: IonVehicle, lap: int, lap_time: float)
signal position_updated(positions: Array)
signal race_finished(results: Array)
signal countdown_tick(count: int)
signal best_lap_set(vehicle: IonVehicle, lap_time: float)
signal gap_updated(gap_ahead: float, gap_behind: float)   # Seconds to car ahead/behind (INF if none)

# ─── Config ────────────────────────────────────────────────────────────────────
const VEHICLE_SCENE := "res://scenes/vehicle/ion_vehicle.tscn"
const TOTAL_LAPS_DEFAULT := 3
const AI_COUNT := 0   # Solo time trial — no AI opponents
const COUNTDOWN_SECONDS := 3
const GRID_SPACING := Vector3(4.5, 0.0, 7.0)   # Wider spacing for nimble ships

# Flash message shown when player crosses each intermediate checkpoint.
# Index matches Checkpoint.checkpoint_index (0 = S/F line, skipped here).
const CHECKPOINT_SECTIONS := {
	1: "P1",
	2: "P2",
	3: "P3",
	4: "P4",
	5: "P5",
	6: "P6",
	7: "P7",
	8: "P8",
	9: "P9",
}

# ─── References ────────────────────────────────────────────────────────────────
var track_gen: TrackGenerator
var waypoint_sys: WaypointSystem
var hud: HUD

# ─── State ─────────────────────────────────────────────────────────────────────
var player_vehicle: IonVehicle
var ai_vehicles: Array[IonVehicle] = []
var all_vehicles: Array[IonVehicle] = []
var checkpoints: Array[Checkpoint]  = []

var total_laps: int    = TOTAL_LAPS_DEFAULT
var race_time: float   = 0.0
var countdown: float   = 0.0
var race_active: bool  = false
var race_complete: bool= false

# Per-vehicle lap tracking
var lap_start_times: Dictionary = {}  # vehicle -> time
var best_lap_times:  Dictionary = {}  # vehicle -> best lap

# ─── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	total_laps = GameManager.get_lap_count()

func initialize(tgen: TrackGenerator, wp_sys: WaypointSystem, hud_layer: HUD) -> void:
	track_gen    = tgen
	waypoint_sys = wp_sys
	hud          = hud_layer
	_spawn_vehicles()
	_collect_checkpoints()
	_start_countdown()

# ─── Spawn ─────────────────────────────────────────────────────────────────────
func _spawn_vehicles() -> void:
	var spawn_pt := waypoint_sys.waypoints[0] + Vector3(0, 2.5, 0) if not waypoint_sys.waypoints.is_empty() else Vector3(0, 2.5, 0)
	var spawn_dir := Vector3(0, 0, -1)
	if waypoint_sys.waypoints.size() > 1:
		spawn_dir = (waypoint_sys.waypoints[1] - waypoint_sys.waypoints[0]).normalized()

	var vehicle_scene_res = load(VEHICLE_SCENE)

	# Player vehicle — grid position 0
	player_vehicle = vehicle_scene_res.instantiate() as IonVehicle
	player_vehicle.is_player    = true
	player_vehicle.vehicle_color = GameManager.selected_vehicle_color
	player_vehicle.name          = "Player"
	get_parent().add_child(player_vehicle)
	_place_on_grid(player_vehicle, 0, spawn_pt, spawn_dir)
	player_vehicle.seed_respawn(player_vehicle.global_position, spawn_dir)
	player_vehicle.set_track_waypoints(waypoint_sys.waypoints, track_gen.TRACK_WIDTH * 0.5)
	all_vehicles.append(player_vehicle)
	lap_start_times[player_vehicle] = 0.0
	best_lap_times[player_vehicle]  = INF

	# Connect signals
	player_vehicle.speed_changed.connect(_on_player_speed_changed)
	player_vehicle.energy_changed.connect(_on_player_energy_changed)
	player_vehicle.boost_activated.connect(_on_player_boost)
	player_vehicle.airborne.connect(_on_player_airborne)
	player_vehicle.slipstream_changed.connect(_on_player_slipstream)

	# AI vehicles
	var ai_colors := [
		Color(0.9, 0.15, 0.15),
		Color(0.15, 0.85, 0.25),
		Color(0.9, 0.65, 0.05),
		Color(0.7, 0.15, 0.9),
		Color(0.9, 0.4, 0.1),
	]

	for i in AI_COUNT:
		var ai_v := vehicle_scene_res.instantiate() as IonVehicle
		ai_v.is_player     = false
		ai_v.vehicle_color = ai_colors[i % ai_colors.size()]
		ai_v.name          = "AI_%d" % (i + 1)
		get_parent().add_child(ai_v)
		_place_on_grid(ai_v, i + 1, spawn_pt, spawn_dir)
		ai_v.seed_respawn(ai_v.global_position, spawn_dir)
		ai_v.set_track_waypoints(waypoint_sys.waypoints, track_gen.TRACK_WIDTH * 0.5)

		# Attach AI controller — each car gets a distinct personality
		var ai_ctrl := AIController.new()
		ai_ctrl.name = "AIController"
		ai_v.add_child(ai_ctrl)
		# Spread AI across different lines: inner, outer, near-centre
		var lane_offsets := [-4.5, 4.5, -7.5, 7.5, 1.5]
		# Rotate through personalities: Balanced, Aggressive, Consistent, Drafter, Aggressive
		var personalities := [0, 1, 2, 3, 1]
		ai_ctrl.setup(waypoint_sys.waypoints, GameManager.selected_difficulty,
			lane_offsets[i % lane_offsets.size()],
			personalities[i % personalities.size()])

		ai_vehicles.append(ai_v)
		all_vehicles.append(ai_v)
		lap_start_times[ai_v] = 0.0
		best_lap_times[ai_v]  = INF

func _place_on_grid(v: IonVehicle, slot: int, origin: Vector3, forward: Vector3) -> void:
	var right  := forward.cross(Vector3.UP).normalized()
	var side   := (slot % 2) * 2 - 1   # Alternates -1, 1
	var row    := slot / 2
	v.global_position = origin + right * side * GRID_SPACING.x - forward * row * GRID_SPACING.z
	v.global_transform.basis = Basis.looking_at(forward, Vector3.UP)

# ─── Checkpoints ───────────────────────────────────────────────────────────────
func _collect_checkpoints() -> void:
	# Search the entire scene tree for Checkpoint nodes
	var root := get_tree().current_scene
	for child in root.find_children("*", "Checkpoint", true, false):
		var cp := child as Checkpoint
		if cp:
			checkpoints.append(cp)
			cp.checkpoint_passed.connect(_on_checkpoint_passed)
	checkpoints.sort_custom(func(a, b): return a.checkpoint_index < b.checkpoint_index)
	if checkpoints.is_empty():
		push_warning("RaceManager: No checkpoints found! Laps will not work.")
	else:
		print("RaceManager: Found %d checkpoints" % checkpoints.size())

# ─── Countdown ─────────────────────────────────────────────────────────────────
func _start_countdown() -> void:
	_freeze_all_vehicles(true)
	var timer := get_tree().create_timer(0.5)
	await timer.timeout
	for i in range(COUNTDOWN_SECONDS, 0, -1):
		countdown_tick.emit(i)
		await get_tree().create_timer(1.0).timeout
	countdown_tick.emit(0)
	_begin_race()

func _freeze_all_vehicles(freeze: bool) -> void:
	for v in all_vehicles:
		v.freeze = freeze

# ─── Race Start ────────────────────────────────────────────────────────────────
func _begin_race() -> void:
	_freeze_all_vehicles(false)
	race_active = true
	for v in all_vehicles:
		v.lap = 1
		v.checkpoint_idx = 0
		# Set initial respawn position to spawn point — prevents infinite falls
		# if vehicle falls before the 0.4s on-track save window completes
		var spawn_pos := waypoint_sys.waypoints[0] + Vector3(0, 2.5, 0)
		var spawn_fwd := Vector3(0, 0, -1)
		if waypoint_sys.waypoints.size() > 1:
			spawn_fwd = (waypoint_sys.waypoints[1] - waypoint_sys.waypoints[0]).normalized()
		v.seed_respawn(spawn_pos, spawn_fwd)
	race_started.emit()
	GameManager.on_race_started()

# ─── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Update track chunk visibility based on player position
	if player_vehicle and track_gen:
		track_gen.update_chunks(player_vehicle.global_position)

	if not race_active or race_complete:
		return
	race_time += delta
	_update_positions()
	_update_rubber_banding()
	_update_delta_display()

func _update_positions() -> void:
	var scored: Array = []
	for v in all_vehicles:
		var lap_dist  := waypoint_sys.get_path_distance(v.global_position)
		var total_d   := (v.lap - 1) * waypoint_sys.total_length + lap_dist
		v.total_race_distance = total_d
		scored.append({"vehicle": v, "dist": total_d})
	scored.sort_custom(func(a, b): return a["dist"] > b["dist"])
	for i in scored.size():
		scored[i]["vehicle"].race_position = i + 1
	position_updated.emit(scored)

	# Emit gap to car ahead and behind for the player
	if player_vehicle != null:
		var player_pos := player_vehicle.race_position
		var gap_ahead  := INF
		var gap_behind := INF
		# Find the car immediately ahead (lower position number)
		for entry in scored:
			var v := entry["vehicle"] as IonVehicle
			if v.race_position == player_pos - 1:
				var ahead_dist := (entry["dist"] as float) - player_vehicle.total_race_distance
				var ahead_spd  := maxf((player_vehicle.current_speed + v.current_speed) * 0.5, 1.0)
				gap_ahead = absf(ahead_dist) / ahead_spd
			elif v.race_position == player_pos + 1:
				var behind_dist := player_vehicle.total_race_distance - (entry["dist"] as float)
				var behind_spd  := maxf((player_vehicle.current_speed + v.current_speed) * 0.5, 1.0)
				gap_behind = absf(behind_dist) / behind_spd
		gap_updated.emit(gap_ahead, gap_behind)

func _update_delta_display() -> void:
	if player_vehicle == null or hud == null:
		return
	var best: float = best_lap_times.get(player_vehicle, INF)
	if best == INF:
		return
	var elapsed := race_time - (lap_start_times[player_vehicle] as float)
	hud.update_lap_delta(elapsed - best)

func _update_rubber_banding() -> void:
	if player_vehicle == null:
		return
	for ai_v in ai_vehicles:
		var ai_ctrl := ai_v.find_child("AIController") as AIController
		if ai_ctrl == null:
			continue
		var gap := (player_vehicle.total_race_distance - ai_v.total_race_distance) / maxf(waypoint_sys.total_length, 1.0)
		ai_ctrl.set_rubber_band_gap(gap)

# ─── Checkpoint Passed ─────────────────────────────────────────────────────────
func _on_checkpoint_passed(vehicle: IonVehicle, idx: int) -> void:
	if checkpoints.is_empty():
		return
	var max_idx := checkpoints.size() - 1

	# Flash track section name for player (intermediate checkpoints only)
	if vehicle == player_vehicle and hud and idx > 0 and idx < max_idx:
		var sect: String = CHECKPOINT_SECTIONS.get(idx, "")
		if sect != "":
			hud.flash_lap_message(sect)

	# Boost refill at every checkpoint (P1, P2, etc.)
	if idx > 0:
		vehicle.refill_energy()

	if idx == max_idx:
		_on_lap_finished(vehicle)

func _on_lap_finished(vehicle: IonVehicle) -> void:
	vehicle.checkpoint_idx = 0
	var lap_time: float = race_time - (lap_start_times[vehicle] as float)
	lap_start_times[vehicle] = race_time
	if lap_time < best_lap_times[vehicle]:
		best_lap_times[vehicle] = lap_time
		best_lap_set.emit(vehicle, lap_time)

	lap_completed.emit(vehicle, vehicle.lap, lap_time)

	vehicle.lap += 1
	if vehicle.lap > total_laps:
		_vehicle_finished(vehicle)

func _vehicle_finished(vehicle: IonVehicle) -> void:
	vehicle.finish_race(race_time)
	if vehicle == player_vehicle:
		_check_race_over()

func _check_race_over() -> void:
	race_complete = true
	race_active   = false

	var results: Array = []
	for v in all_vehicles:
		results.append({
			"name":        v.name,
			"position":    v.race_position,
			"time":        v.finish_time if v.has_finished else race_time,
			"best_lap":    best_lap_times.get(v, INF),
			"is_player":   v == player_vehicle,
		})
	results.sort_custom(func(a, b): return a["position"] < b["position"])

	race_finished.emit(results)
	GameManager.on_race_finished(results, player_vehicle.finish_time, player_vehicle.race_position)

# ─── HUD Relays ────────────────────────────────────────────────────────────────
func _on_player_speed_changed(kmh: float) -> void:
	if hud and hud.has_method("update_speed"):
		hud.update_speed(kmh)

func _on_player_energy_changed(cur: float, max_e: float) -> void:
	if hud and hud.has_method("update_energy"):
		hud.update_energy(cur, max_e)

func _on_player_boost() -> void:
	if hud and hud.has_method("show_boost_flash"):
		hud.show_boost_flash()

func _on_player_airborne(seconds: float) -> void:
	if hud and seconds > 0.5:
		var msg := "AIRBORNE!  %.1fs" % seconds if seconds > 1.2 else "AIRBORNE!"
		hud.flash_lap_message(msg)

func _on_player_slipstream(active: bool) -> void:
	if active and hud and hud.has_method("flash_lap_message"):
		hud.flash_lap_message("SLIPSTREAM!")
