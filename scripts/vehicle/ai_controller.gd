## AIController — Drives an IonVehicle along the waypoint path.
## Multi-waypoint look-ahead, corner speed prediction, personality traits,
## aggressive boost usage, racing line awareness, overtake behaviour.
extends Node
class_name AIController

@export var difficulty: int = 1  # 0=Novice, 1=Pro, 2=Elite, 3=Master

var vehicle: IonVehicle
var waypoints: Array[Vector3] = []
var current_wp: int = 0

# Per-difficulty tuning
const SPEED_FACTORS    := [0.74, 0.86, 0.96, 1.04]
const STEER_FACTORS    := [0.72, 0.85, 0.94, 1.00]
const BOOST_THRESHOLDS := [0.88, 0.76, 0.60, 0.45]
const LOOK_AHEAD_WPS   := [4,    6,    8,    10]    # Waypoints to scan for corners
const ADVANCE_DIST     := [18.0, 22.0, 25.0, 28.0] # Waypoint advance trigger distance

var _speed_factor:    float = 0.86
var _steer_factor:    float = 0.85
var _boost_threshold: float = 0.76
var _look_ahead:      int   = 6
var _advance_dist:    float = 22.0

# Rubber-banding gap (set by RaceManager each frame)
var _target_gap: float = 0.0

# Lane offset: lateral metres from waypoint centre (racing line spread)
var _lane_offset: float = 0.0

# ── Personality ───────────────────────────────────────────────────────────────
# Each AI driver has a distinct racing personality that modifies base behaviour.
# Values are set once at setup() and remain fixed for the whole race.
#   aggression:   0.0–1.0  Higher = harder braking later, more corner entry speed
#   consistency:  0.0–1.0  Higher = less random variation in inputs
#   draft_seek:   0.0–1.0  Higher = actively steers toward other vehicles to draft
var _aggression:   float = 0.5
var _consistency:  float = 0.8
var _draft_seek:   float = 0.3
var _personality:  int   = 0   # 0=Balanced, 1=Aggressive, 2=Consistent, 3=Drafter

# Personality definitions — [aggression, consistency, draft_seek]
const PERSONALITIES := [
	[0.50, 0.80, 0.25],   # 0 Balanced     — solid all-rounder
	[0.85, 0.55, 0.15],   # 1 Aggressive   — late braking, risky corners
	[0.40, 0.95, 0.10],   # 2 Consistent   — precise, clean, never crashes
	[0.55, 0.70, 0.80],   # 3 Drafter      — hunts slipstream, patience then burst
]

# Internal state
var _steer_smoothed:   float = 0.0   # Smoothed steer output
var _overtake_side:    float = 0.0   # -1 left, 0 none, +1 right (overtake nudge)
var _overtake_timer:   float = 0.0   # How long we've been attempting this overtake

func _ready() -> void:
	vehicle = get_parent() as IonVehicle
	if vehicle == null:
		push_error("AIController must be a child of IonVehicle")
		return
	_apply_difficulty()

func _apply_difficulty() -> void:
	difficulty      = clampi(difficulty, 0, 3)
	_speed_factor   = SPEED_FACTORS[difficulty]
	_steer_factor   = STEER_FACTORS[difficulty]
	_boost_threshold = BOOST_THRESHOLDS[difficulty]
	_look_ahead     = LOOK_AHEAD_WPS[difficulty]
	_advance_dist   = ADVANCE_DIST[difficulty]

func setup(wp: Array[Vector3], diff: int, lane_offset: float = 0.0, personality: int = -1) -> void:
	waypoints    = wp
	difficulty   = diff
	_lane_offset = lane_offset
	# If no personality specified, pick one based on slot index (deterministic variety)
	_personality = personality if personality >= 0 else (diff % PERSONALITIES.size())
	var p: Array  = PERSONALITIES[_personality]
	_aggression  = p[0]
	_consistency = p[1]
	_draft_seek  = p[2]
	_apply_difficulty()

func _physics_process(delta: float) -> void:
	if vehicle == null or vehicle.has_finished or waypoints.is_empty():
		return
	_drive(delta)

func _drive(delta: float) -> void:
	var n      := waypoints.size()
	var target := waypoints[current_wp]

	# Apply lane offset — each AI targets a slightly different lateral line
	if abs(_lane_offset) > 0.1:
		var wp_fwd   := (waypoints[(current_wp + 1) % n] - target).normalized()
		var wp_right := wp_fwd.cross(Vector3.UP).normalized()
		target += wp_right * _lane_offset

	var to_wp  := target - vehicle.global_position
	var dist   := to_wp.length()

	# Advance to next waypoint when close enough
	if dist < _advance_dist:
		current_wp = (current_wp + 1) % n

	# ── Multi-waypoint look-ahead corner prediction ──────────────────────────
	var sharpness_weighted := 0.0
	var worst_sharpness    := 0.0
	var corner_dist_steps  := 0

	for k in range(1, _look_ahead + 1):
		var wp_a   := waypoints[(current_wp + k - 1) % n]
		var wp_b   := waypoints[(current_wp + k    ) % n]
		var wp_c   := waypoints[(current_wp + k + 1) % n]
		var dir_ab := (wp_b - wp_a).normalized()
		var dir_bc := (wp_c - wp_b).normalized()
		var corner := 1.0 - clampf(dir_ab.dot(dir_bc), -1.0, 1.0)
		var weight := 1.0 / (1.0 + float(k) * 0.35)
		sharpness_weighted += corner * weight
		if corner > worst_sharpness:
			worst_sharpness   = corner
			corner_dist_steps = k

	# ── Speed target — personality-modulated ─────────────────────────────────
	# Aggressive drivers brake later and carry more corner speed.
	var aggr_bias := 1.0 + _aggression * 0.20   # 1.00–1.20 speed bonus
	var base_mult := clampf(1.0 - sharpness_weighted * (1.10 - _aggression * 0.35), 0.25, 1.0)
	var speed_mult := base_mult * _speed_factor * aggr_bias

	# Rubber-banding
	speed_mult = clampf(speed_mult + _target_gap * 0.18, 0.22, 1.14)

	# Consistency: low-consistency drivers have micro-variations in throttle
	if _consistency < 0.9:
		var jitter := (1.0 - _consistency) * randf_range(-0.06, 0.06)
		speed_mult = clampf(speed_mult + jitter, 0.15, 1.14)

	# ── Thrust / Brake ───────────────────────────────────────────────────────
	var thrust := speed_mult
	var brake  := false

	# Brake threshold scales with aggression — aggressive = brakes LATER
	var brake_sharp  := 0.80 - _aggression * 0.18   # 0.62–0.80
	var brake_medium := 0.60 - _aggression * 0.15   # 0.45–0.60
	if worst_sharpness > brake_sharp and corner_dist_steps <= 3:
		thrust = 0.18 + _aggression * 0.12
		brake  = true
	elif worst_sharpness > brake_medium and corner_dist_steps <= 2:
		thrust = clampf(thrust * 0.58, 0.18, 0.72)

	# ── Overtake nudge — used when close behind another AI ───────────────────
	var overtake_steer := 0.0
	if _overtake_timer > 0.0:
		_overtake_timer = maxf(_overtake_timer - delta, 0.0)
		overtake_steer  = _overtake_side * 0.35
	else:
		_overtake_side = 0.0

	# ── Draft seek — Drafter personality steers toward nearest vehicle ────────
	var draft_steer := 0.0
	if _draft_seek > 0.4:
		var best_dist := 999.0
		for v in vehicle.get_tree().get_nodes_in_group("vehicles"):
			if v == vehicle or not (v is IonVehicle):
				continue
			var iv       := v as IonVehicle
			var gap_dist := iv.global_position.distance_to(vehicle.global_position)
			if gap_dist < best_dist and gap_dist < 20.0:
				best_dist = gap_dist
				var to_v       := iv.global_position - vehicle.global_position
				var local_to_v := vehicle.global_transform.basis.inverse() * to_v
				# Only steer toward if vehicle is ahead
				if local_to_v.z < -2.0:
					draft_steer = clampf(local_to_v.x * 0.08, -0.25, 0.25) * _draft_seek

	# ── Steering ─────────────────────────────────────────────────────────────
	var local_dir   := vehicle.global_transform.basis.inverse() * to_wp.normalized()
	var steer_raw   := clampf(local_dir.x * 2.5, -1.0, 1.0) * _steer_factor
	steer_raw       = clampf(steer_raw + draft_steer + overtake_steer, -1.0, 1.0)
	var steer_smooth := lerpf(0.18, 0.30, 1.0 - _consistency)  # Consistent = smoother
	_steer_smoothed  = lerpf(_steer_smoothed, steer_raw, steer_smooth)

	# ── Boost decision ────────────────────────────────────────────────────────
	var e_ratio    := vehicle.energy / vehicle.max_energy
	var is_straight := worst_sharpness < 0.12 and sharpness_weighted < 0.08
	# Drafter boosts aggressively when already in a slipstream zone
	var e_thresh   := _boost_threshold - (_draft_seek * 0.12 if is_straight else 0.0)
	var do_boost   := (is_straight
		and e_ratio > e_thresh
		and not vehicle.boost_empty
		and speed_mult > 0.70)

	vehicle.set_ai_inputs(thrust, _steer_smoothed, do_boost, brake)

## Called by RaceManager to set rubber-band gap.
## gap > 0 = AI is behind player → speed up
## gap < 0 = AI is ahead of player → slow down
func set_rubber_band_gap(gap: float) -> void:
	_target_gap = clampf(gap, -1.0, 1.0)
