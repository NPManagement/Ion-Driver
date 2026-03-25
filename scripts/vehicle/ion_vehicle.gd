## IonVehicle — Anti-gravity hover vehicle.
## Nimble raceship physics: snappy steering, ground-effect hover,
## speed turbulence, camera shake, g-force banking, boost surge.
extends RigidBody3D
class_name IonVehicle

# ─── Signals ───────────────────────────────────────────────────────────────────
signal speed_changed(kmh: float)
signal energy_changed(current: float, maximum: float)
signal boost_activated()
signal boost_depleted()
signal airborne(seconds: float)
signal slipstream_changed(active: bool)

# ─── Exports: Hover ────────────────────────────────────────────────────────────
@export_group("Hover System")
@export var hover_height: float           = 2.0    # Hover target above surface
@export var hover_force: float            = 7000.0  # Gentle spring — no flinging
@export var hover_damping: float          = 4000.0  # Overdamped — settles fast, no bounce
@export var hover_tilt_correction: float  = 200.0   # Gentle alignment
@export var ground_effect_strength: float = 0.10

# ─── Exports: Propulsion ───────────────────────────────────────────────────────
@export_group("Propulsion")
@export var max_speed: float              = 145.0   # m/s  (~522 km/h) — OG OG value
@export var max_speed_boosted: float      = 230.0
@export var thrust_force: float           = 40000.0
@export var brake_force: float            = 65000.0
@export var reverse_force: float          = 3000.0
@export var drag_coefficient: float       = 0.0     # Disabled — custom drag curve below
@export var lateral_drag: float           = 24.0    # 4× more grip — locked to your heading

# ─── Exports: Steering ─────────────────────────────────────────────────────────
@export_group("Steering")
@export var steer_speed: float            = 7500.0  # Base value — scaled by sensitivity level
@export var steer_tilt_factor: float      = 0.85    # Dramatic banking into corners
@export var steer_recovery_speed: float   = 11.0
@export var air_brake_force: float        = 20000.0 # WipEout: air brakes are the key mechanic
@export var high_speed_understeer: float  = 0.05   # Barely any understeer — nimble at all speeds

# Steering sensitivity: 5 levels, press T to cycle. Level 3 = current default (1.0×).
const STEER_LABELS = ["VERY LOW", "LOW", "MEDIUM", "HIGH", "VERY HIGH"]
const STEER_MULTIPLIERS = [0.25, 0.5, 0.75, 1.0, 1.5]
var steer_sensitivity: int = 1   # Start at LOW (index 1 = 50%)

# ─── Exports: Boost ────────────────────────────────────────────────────────────
@export_group("Boost")
@export var boost_force: float            = 70000.0
@export var boost_kick_speed: float       = 50.0
@export var max_energy: float             = 100.0
@export var energy_drain: float           = 20.0
@export var energy_regen: float           = 18.0
@export var boost_recharge_delay: float   = 0.8

# ─── Exports: Visual ───────────────────────────────────────────────────────────
@export_group("Visual")
@export var vehicle_color: Color          = Color(0.1, 0.45, 0.95)
@export var accent_color: Color           = Color(0.3, 0.85, 1.0)

# ─── Runtime State ─────────────────────────────────────────────────────────────
var energy: float             = 100.0
var current_speed: float      = 0.0
var is_boosting: bool         = false
var boost_empty: bool         = false
var boost_recharge_t: float   = 0.0

var input_thrust: float       = 0.0
var input_brake: float        = 0.0
var input_steer: float        = 0.0
var input_boost: bool         = false
var input_under_boost: bool   = false

# ─── Air Bank ──────────────────────────────────────────────────────────────────
var _trail_boost: MeshInstance3D                  # White TRON trail from boost light
var _trail_data_boost: Array = []                 # [{pos, up}]
var _air_bank_input: float    = 0.0    # -1 left, +1 right, 0 none (held)
var _dash_cam_roll: float     = 0.0    # Additive camera roll from air bank (decays to 0)
var _dash_body_roll: float    = 0.0    # Additive vehicle mesh bank from air bank
var _dash_whoosh: float       = 0.0    # Audio burst trigger (1.0 → 0.0)
var _dash_chirp_phase: float  = 0.0    # Air bank chirp synthesis phase
var _ghost_nodes: Array       = []     # [{node, mat, t, max_t, vel, base_alpha, base_energy}]

var on_track: bool            = false
var track_normal: Vector3     = Vector3.UP
var current_roll: float       = 0.0
# Per-pad smoothed normals — irons out the seam-line jolt when crossing road quad edges
var _hover_smooth_n: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]

var is_player: bool           = false
var has_finished: bool        = false
var race_time: float          = 0.0
var lap: int                  = 0
var checkpoint_idx: int       = 0
var race_position: int        = 1
var total_race_distance: float = 0.0
var finish_time: float        = 0.0

# ─── Track bounds ──────────────────────────────────────────────────────────────
var _track_waypoints: Array[Vector3] = []
var _track_half_width: float  = 160.0  # TRACK_WIDTH / 2
var _off_road: bool           = false
var _off_road_penalty_cooldown: float = 0.0  # Prevents repeated instant penalties

# ─── Railing collision ────────────────────────────────────────────────────────
const RAILING_RAY_LAYER := 4
const RAILING_RAY_COUNT := 6   # 3 per side (front, mid, rear)
const RAILING_RAY_REACH := 5.0 # How far sideways the rays extend
var _railing_sparks: GPUParticles3D        # Reusable spark emitter (reparented to contact)
var _railing_spark_light: OmniLight3D      # Flash at contact point
var _railing_hit_cooldown: float = 0.0     # Prevent stacking penalties per frame
var _railing_scrape_t: float     = 0.0     # Continuous scrape timer for sustained contact

# ─── Physics State ─────────────────────────────────────────────────────────────
var _prev_fwd_speed: float    = 0.0
var _hover_avg_dist: float    = 0.85
var _turbulence_t: float      = 0.0
var _airtime_t: float         = 0.0  # Seconds continuously off the track
var _in_slipstream: bool      = false # True when drafting directly behind another vehicle
var _fall_timer: float        = 0.0  # Seconds with no track contact (fall detection)
var _respawn_pos: Vector3     = Vector3.ZERO  # Last safe on-track position
var _respawn_basis: Basis     = Basis.IDENTITY
var _respawn_save_t: float    = 0.0  # Countdown until next respawn point save
var _has_respawn_pos: bool    = false          # True once a valid on-track save exists
var _cam_trauma: float        = 0.0
var _cam_shake_vel: Vector3   = Vector3.ZERO
var _shake_time: float        = 0.0
var _cam_lean: float          = 0.0
var _cam_lateral: float       = 0.0  # Sideways offset — camera slides in turns
var _cam_yaw_lag: float       = 0.0  # Rotational yaw lag — camera drags behind
var _cam_initialized: bool    = false # Snap camera on first frame
var _boost_shudder_t: float   = 0.0  # Countdown after boost fires

# Audio synthesis state
var _audio_phase1: float      = 0.0  # Base hum fundamental
var _audio_phase2: float      = 0.0  # Base hum 2nd harmonic
var _audio_phase3: float      = 0.0  # Turbine whine
var _audio_phase4: float      = 0.0  # Wind noise carrier
var _audio_phase5: float      = 0.0  # Boost high-freq layer
var _audio_phase6: float      = 0.0  # Grit FM wobble
var _noise_t: float           = 0.0  # Collision noise burst timer
var _boost_whoosh: float      = 0.0  # Boost start whoosh burst
var _boost_full_ping: float   = 0.0  # Hum envelope (rises then fades)
var _boost_full_ping2: float  = 0.0  # unused — kept for refill trigger compat
var _boost_full_ping3: float  = 0.0  # End click envelope
var _boost_full_phase: float  = 0.0  # Hum oscillator phase
var _boost_full_phase2: float = 0.0  # unused
var _boost_full_phase3: float = 0.0  # Click phase
var _boost_full_t: float      = 0.0  # Time since trigger (for pitch rise)
var _was_boosting: bool       = false # Track boost state changes
var _was_throttle: float      = 0.0  # Track throttle for turbo trigger
var _throttle_off_time: float = 0.0  # How long throttle has been released
var _was_heavy_throttle: bool = false # Was on heavy throttle before releasing
var _prev_wind_sample: float  = 0.0  # Low-pass filter state for wind
var _flutter_filt1: float     = 0.0  # Flutter dedicated LP filter stage 1
var _flutter_filt2: float     = 0.0  # Flutter dedicated LP filter stage 2
var _flutter_filt3: float     = 0.0  # Flutter dedicated LP filter stage 3

# ── Turbo flutter (STUTUTU) — separate audio system ──
var _flutter_gen: AudioStreamGenerator
var _flutter_playback: AudioStreamGeneratorPlayback
var _flutter_active: bool     = false
var _flutter_sample_pos: int  = 0     # Current position in the burst sequence
var _flutter_total_samples: int = 0   # Total samples to generate
var _flutter_pulse_rate: float = 0.0  # Pulses per second (varies with speed)
var _flutter_intensity: float = 0.0   # 0→1 based on speed when triggered

# ─── Node References ───────────────────────────────────────────────────────────
var _vehicle_mesh: Node3D
var _underbody_light: OmniLight3D
var _boost_light: OmniLight3D
var _pad_lights: Array          = []
var _brake_lights: Array        = []   # OmniLights for brake thrusters
var _brake_light_phase: Array   = [0.0, 0.0]
var _brake_burner_mats: Array   = []   # Afterburner disc materials
var _brake_ring_mats: Array     = []   # Jet ring glow materials
var _brake_plasma_mats: Array   = []   # Plasma cone materials (outer, inner, core)
var _brake_sparks: Array        = []   # GPUParticles3D plasma sparks
# Under-boost side thruster visuals
var _ub_jet_mats: Array         = []   # [left_outer, left_mid, left_core, right_outer, right_mid, right_core]
var _ub_lights: Array           = []   # [left OmniLight3D, right OmniLight3D]
var _ub_sparks: Array           = []   # [left GPUParticles3D, right GPUParticles3D]
var _ub_intensity: float        = 0.0  # Smoothed 0→1 for visuals/audio
var _ub_audio_phase: float      = 0.0  # Thruster tone oscillator
var _ub_hiss_filter: float      = 0.0  # Low-pass state for pressurized hiss
var _hover_rays: Array          = []
var _trail_left: MeshInstance3D
var _trail_right: MeshInstance3D
var _trail_data_left: Array = []   # [{pos: Vector3, up: Vector3}]
var _trail_data_right: Array = []
const TRAIL_MAX_POINTS := 4500
const TRAIL_HEIGHT := 0.6       # Vertical ribbon height (TRON wall)
const AIR_BANK_YAW_FORCE: float   = 150.0    # Near-zero yaw — purely cosmetic feel
const AIR_BANK_BRAKE_FORCE: float = 100.0    # Negligible speed scrub
const UNDER_BOOST_FORCE: float    = 750000.0   # Lateral thrust when under-boosting
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _blur_rect: ColorRect
var _blur_material: ShaderMaterial
var _position_label: Label3D
var _engine_player: AudioStreamPlayer
var _engine_gen: AudioStreamGenerator
var _engine_playback: AudioStreamGeneratorPlayback

# ─── Constants ─────────────────────────────────────────────────────────────────
const HOVER_OFFSETS: Array = [
	Vector3( 1.65, 0.0,  2.0),
	Vector3(-1.65, 0.0,  2.0),
	Vector3( 1.65, 0.0, -2.5),
	Vector3(-1.65, 0.0, -2.5),
]
const MAX_RAY_LENGTH: float = 22.0  # Extended — covers 400m elevation test track banking geometry
const KMH_FACTOR: float     = 3.6

# ─── Setup ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_configure_rigidbody()
	_build_visual_mesh()
	_build_effects()
	if is_player:
		_build_camera()
	add_to_group("vehicles")

func _exit_tree() -> void:
	# Trail meshes are parented to scene root, not this node — clean them up
	for t in [_trail_left, _trail_right]:
		if t and is_instance_valid(t):
			t.queue_free()

func _configure_rigidbody() -> void:
	mass                  = 180.0   # Light — anti-grav ships are featherweight
	gravity_scale         = 0.4    # Low gravity — only applies when off-track (hover cancels it)
	linear_damp           = 0.02   # Near zero — aero drag does all the speed limiting
	angular_damp          = 2.5    # Strong yaw damping prevents spinouts
	collision_layer       = 2      # Detected by checkpoint Area3Ds (mask=2)
	collision_mask        = 8      # Collide with railing walls (layer 4) — hover spring handles track
	continuous_cd         = true   # Prevent tunnelling through thin walls at high speed

func _build_visual_mesh() -> void:
	_vehicle_mesh = Node3D.new()
	_vehicle_mesh.name = "VehicleMesh"
	_vehicle_mesh.rotation.y = PI  # Mesh nose was at +Z, flip so nose is at -Z (Godot forward)
	add_child(_vehicle_mesh)

	var body_mat   := _make_body_material()
	var accent_mat := _make_accent_material()
	var engine_mat := _make_engine_material()
	var canopy_mat := _make_canopy_material()
	var dark_mat   := _make_dark_panel_material()
	var carbon_mat := _make_carbon_material()

	# ════════════════════════════════════════════════════════════════════════
	#  CENTRAL MONOCOQUE — the main survival cell
	# ════════════════════════════════════════════════════════════════════════
	# Main tub — wide, low, tapered
	_box(_vehicle_mesh, Vector3(1.8, 0.24, 4.8), Vector3(0, 0.08, 0), body_mat)
	# Upper spine ridge — gives depth to the top surface
	_box(_vehicle_mesh, Vector3(0.6, 0.08, 3.6), Vector3(0, 0.22, -0.2), dark_mat)
	# Lower tub reinforcement
	_box(_vehicle_mesh, Vector3(1.5, 0.06, 4.4), Vector3(0, -0.06, 0), carbon_mat)

	# ── Nose section — layered taper ──
	_box(_vehicle_mesh, Vector3(1.3, 0.18, 1.2), Vector3(0, 0.05, 2.8), body_mat)
	_box(_vehicle_mesh, Vector3(0.9, 0.14, 0.8), Vector3(0, 0.02, 3.5), body_mat)
	_box(_vehicle_mesh, Vector3(0.45, 0.08, 0.6), Vector3(0, 0.0, 4.0), accent_mat)
	# Nose splitter blade
	_box(_vehicle_mesh, Vector3(2.2, 0.03, 0.5), Vector3(0, -0.06, 3.2), carbon_mat)
	# Nose camera/sensor pod
	_box(_vehicle_mesh, Vector3(0.15, 0.10, 0.25), Vector3(0, 0.14, 3.9), accent_mat)

	# ── Front wing assembly ──
	_box(_vehicle_mesh, Vector3(3.6, 0.03, 0.45), Vector3(0, -0.08, 3.5), accent_mat)
	# Front wing flaps (multi-element)
	_box(_vehicle_mesh, Vector3(3.2, 0.03, 0.25), Vector3(0, -0.04, 3.2), accent_mat)
	# Front wing endplates
	for side: int in [-1, 1]:
		_box(_vehicle_mesh, Vector3(0.03, 0.18, 0.55), Vector3(side * 1.8, -0.02, 3.4), accent_mat)

	# ════════════════════════════════════════════════════════════════════════
	#  SIDEPODS — air intakes + radiator housing
	# ════════════════════════════════════════════════════════════════════════
	for side: int in [-1, 1]:
		var sx := side * 1.2
		# Sidepod body
		_box(_vehicle_mesh, Vector3(0.55, 0.22, 2.8), Vector3(sx, 0.04, -0.2), body_mat)
		# Sidepod intake opening
		_box(_vehicle_mesh, Vector3(0.5, 0.18, 0.12), Vector3(sx, 0.06, 1.2), dark_mat)
		# Sidepod undercut — carved out bottom edge
		_box(_vehicle_mesh, Vector3(0.4, 0.04, 2.4), Vector3(sx, -0.08, -0.2), dark_mat)
		# Cooling vents — horizontal slats on top
		for v in range(3):
			_box(_vehicle_mesh, Vector3(0.45, 0.015, 0.4), Vector3(sx, 0.16, -0.6 + float(v) * 0.55), dark_mat)

	# ════════════════════════════════════════════════════════════════════════
	#  ENGINE NACELLES — twin pontoon engines
	# ════════════════════════════════════════════════════════════════════════
	for side: int in [-1, 1]:
		var sx := side * 1.65
		# Nacelle main body
		_box(_vehicle_mesh, Vector3(0.55, 0.26, 2.4), Vector3(sx, 0.0, -1.8), body_mat)
		# Nacelle top fairing
		_box(_vehicle_mesh, Vector3(0.4, 0.06, 1.8), Vector3(sx, 0.16, -1.8), dark_mat)
		# Nacelle bottom plate
		_box(_vehicle_mesh, Vector3(0.5, 0.03, 2.2), Vector3(sx, -0.12, -1.8), carbon_mat)

		# Engine exhaust nozzle — layered rings
		var nozzle_outer := MeshInstance3D.new()
		var noz_o := CylinderMesh.new()
		noz_o.top_radius = 0.18; noz_o.bottom_radius = 0.28; noz_o.height = 0.5
		nozzle_outer.mesh = noz_o
		nozzle_outer.position = Vector3(sx, 0.0, -3.1)
		nozzle_outer.rotation_degrees = Vector3(90, 0, 0)
		nozzle_outer.material_override = engine_mat
		_vehicle_mesh.add_child(nozzle_outer)

		var nozzle_inner := MeshInstance3D.new()
		var noz_i := CylinderMesh.new()
		noz_i.top_radius = 0.12; noz_i.bottom_radius = 0.20; noz_i.height = 0.3
		nozzle_inner.mesh = noz_i
		nozzle_inner.position = Vector3(sx, 0.0, -3.25)
		nozzle_inner.rotation_degrees = Vector3(90, 0, 0)
		nozzle_inner.material_override = accent_mat
		_vehicle_mesh.add_child(nozzle_inner)

		# Intake scoop
		_box(_vehicle_mesh, Vector3(0.35, 0.14, 0.5), Vector3(sx, 0.18, -0.8), accent_mat)

		# ════════════════════════════════════════════════════════════════
		#  RETRO-JET BRAKE ENGINE — full jet engine facing the nose
		#  Mirror of the rear exhaust but pointing forward for braking
		# ════════════════════════════════════════════════════════════════
		# ── Jet engine cowling — big, visible from behind ──
		# Outer cowling shell
		var rj_cowl := MeshInstance3D.new()
		var cowl_m := CylinderMesh.new()
		cowl_m.top_radius = 0.45; cowl_m.bottom_radius = 0.35; cowl_m.height = 1.0
		rj_cowl.mesh = cowl_m
		rj_cowl.position = Vector3(sx, 0.05, -0.4)
		rj_cowl.rotation_degrees = Vector3(90, 0, 0)
		rj_cowl.material_override = dark_mat
		_vehicle_mesh.add_child(rj_cowl)

		# Inner turbine cone
		var rj_inner := MeshInstance3D.new()
		var inner_m := CylinderMesh.new()
		inner_m.top_radius = 0.30; inner_m.bottom_radius = 0.10; inner_m.height = 0.7
		rj_inner.mesh = inner_m
		rj_inner.position = Vector3(sx, 0.05, -0.4)
		rj_inner.rotation_degrees = Vector3(90, 0, 0)
		rj_inner.material_override = engine_mat
		_vehicle_mesh.add_child(rj_inner)

		# Front nozzle lip — where fire exits
		var rj_nozzle := MeshInstance3D.new()
		var noz_m := CylinderMesh.new()
		noz_m.top_radius = 0.40; noz_m.bottom_radius = 0.46; noz_m.height = 0.15
		rj_nozzle.mesh = noz_m
		rj_nozzle.position = Vector3(sx, 0.05, 0.15)
		rj_nozzle.rotation_degrees = Vector3(90, 0, 0)
		rj_nozzle.material_override = carbon_mat
		_vehicle_mesh.add_child(rj_nozzle)

		# Rear intake lip
		var rj_intake := MeshInstance3D.new()
		var intake_m := CylinderMesh.new()
		intake_m.top_radius = 0.38; intake_m.bottom_radius = 0.42; intake_m.height = 0.12
		rj_intake.mesh = intake_m
		rj_intake.position = Vector3(sx, 0.05, -0.96)
		rj_intake.rotation_degrees = Vector3(90, 0, 0)
		rj_intake.material_override = engine_mat
		_vehicle_mesh.add_child(rj_intake)

		# Glowing nozzle rim — visible from behind as hot ring
		var ring_mat := StandardMaterial3D.new()
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(1.0, 0.5, 0.1)
		ring_mat.albedo_color = Color(1.0, 0.4, 0.05, 0.0)
		ring_mat.emission_energy_multiplier = 0.0
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_brake_ring_mats.append(ring_mat)

		var glow_ring := MeshInstance3D.new()
		var gr_m := TorusMesh.new()
		gr_m.inner_radius = 0.30; gr_m.outer_radius = 0.42
		gr_m.rings = 16; gr_m.ring_segments = 16
		glow_ring.mesh = gr_m
		glow_ring.position = Vector3(sx, 0.05, 0.22)
		glow_ring.rotation_degrees = Vector3(90, 0, 0)
		glow_ring.material_override = ring_mat
		_vehicle_mesh.add_child(glow_ring)

		# Afterburner disc — big white-hot circle
		var burner_mat := StandardMaterial3D.new()
		burner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		burner_mat.emission_enabled = true
		burner_mat.emission = Color(1.0, 0.85, 0.6)
		burner_mat.albedo_color = Color(1.0, 0.9, 0.7, 0.0)
		burner_mat.emission_energy_multiplier = 0.0
		burner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_brake_burner_mats.append(burner_mat)

		var burner_disc := MeshInstance3D.new()
		var bd_m := CylinderMesh.new()
		bd_m.top_radius = 0.28; bd_m.bottom_radius = 0.28; bd_m.height = 0.05
		burner_disc.mesh = bd_m
		burner_disc.position = Vector3(sx, 0.05, 0.18)
		burner_disc.rotation_degrees = Vector3(90, 0, 0)
		burner_disc.material_override = burner_mat
		_vehicle_mesh.add_child(burner_disc)

		# ── PLASMA JET CONE — layered transparent cones for plasma thrust ──
		# Outer plasma cone — wide, blue-white transparent
		var plasma_outer_mat := StandardMaterial3D.new()
		plasma_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plasma_outer_mat.emission_enabled = true
		plasma_outer_mat.emission = Color(0.4, 0.7, 1.0)
		plasma_outer_mat.albedo_color = Color(0.3, 0.6, 1.0, 0.0)
		plasma_outer_mat.emission_energy_multiplier = 0.0
		plasma_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plasma_outer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_brake_plasma_mats.append(plasma_outer_mat)

		var outer_cone := MeshInstance3D.new()
		var oc_m := CylinderMesh.new()
		oc_m.top_radius = 0.38; oc_m.bottom_radius = 0.0; oc_m.height = 4.0
		outer_cone.mesh = oc_m
		outer_cone.position = Vector3(sx, 0.05, 2.25)
		outer_cone.rotation_degrees = Vector3(-90, 0, 0)  # tip forward
		outer_cone.material_override = plasma_outer_mat
		_vehicle_mesh.add_child(outer_cone)

		# Mid plasma cone — brighter, narrower
		var plasma_mid_mat := StandardMaterial3D.new()
		plasma_mid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plasma_mid_mat.emission_enabled = true
		plasma_mid_mat.emission = Color(0.6, 0.85, 1.0)
		plasma_mid_mat.albedo_color = Color(0.5, 0.8, 1.0, 0.0)
		plasma_mid_mat.emission_energy_multiplier = 0.0
		plasma_mid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plasma_mid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_brake_plasma_mats.append(plasma_mid_mat)

		var mid_cone := MeshInstance3D.new()
		var mc_m := CylinderMesh.new()
		mc_m.top_radius = 0.24; mc_m.bottom_radius = 0.0; mc_m.height = 3.0
		mid_cone.mesh = mc_m
		mid_cone.position = Vector3(sx, 0.05, 1.75)
		mid_cone.rotation_degrees = Vector3(-90, 0, 0)
		mid_cone.material_override = plasma_mid_mat
		_vehicle_mesh.add_child(mid_cone)

		# Core plasma cone — white-hot center, tight
		var plasma_core_mat := StandardMaterial3D.new()
		plasma_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plasma_core_mat.emission_enabled = true
		plasma_core_mat.emission = Color(0.9, 0.95, 1.0)
		plasma_core_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.0)
		plasma_core_mat.emission_energy_multiplier = 0.0
		plasma_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plasma_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_brake_plasma_mats.append(plasma_core_mat)

		var core_cone := MeshInstance3D.new()
		var cc_m := CylinderMesh.new()
		cc_m.top_radius = 0.12; cc_m.bottom_radius = 0.0; cc_m.height = 2.0
		core_cone.mesh = cc_m
		core_cone.position = Vector3(sx, 0.05, 1.25)
		core_cone.rotation_degrees = Vector3(-90, 0, 0)
		core_cone.material_override = plasma_core_mat
		_vehicle_mesh.add_child(core_cone)

		# ── Plasma sparks — small bright bits that fly off the cone ──
		var sparks := GPUParticles3D.new()
		sparks.amount = 24
		sparks.lifetime = 0.6
		sparks.explosiveness = 0.0
		sparks.randomness = 0.5
		sparks.emitting = false
		sparks.local_coords = true
		sparks.position = Vector3(sx, 0.05, 1.0)
		sparks.rotation_degrees = Vector3(-90, 0, 0)
		sparks.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))

		var spmat := ParticleProcessMaterial.new()
		spmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		spmat.emission_sphere_radius = 0.3

		# Sparks scatter outward in all directions from the plume
		spmat.direction = Vector3(0, 1, 0)
		spmat.spread = 60.0
		spmat.initial_velocity_min = 15.0
		spmat.initial_velocity_max = 40.0

		# Tiny bright dots
		spmat.scale_min = 0.03
		spmat.scale_max = 0.08

		# Fade from bright cyan-white to nothing
		var sp_grad := GradientTexture1D.new()
		var sp_g := Gradient.new()
		sp_g.colors = PackedColorArray([
			Color(0.8, 0.95, 1.0, 1.0),
			Color(0.4, 0.7, 1.0, 0.8),
			Color(0.2, 0.4, 1.0, 0.0),
		])
		sp_g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		sp_grad.gradient = sp_g
		spmat.color_ramp = sp_grad

		spmat.gravity = Vector3(0, -3.0, 0)
		spmat.damping_min = 1.0
		spmat.damping_max = 3.0

		sparks.process_material = spmat

		var sp_quad := QuadMesh.new()
		sp_quad.size = Vector2(0.12, 0.12)
		var sp_mat := StandardMaterial3D.new()
		sp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sp_mat.emission_enabled = true
		sp_mat.emission = Color(0.5, 0.8, 1.0)
		sp_mat.emission_energy_multiplier = 150.0
		sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sp_mat.vertex_color_use_as_albedo = true
		sp_quad.material = sp_mat
		sparks.draw_pass_1 = sp_quad

		_vehicle_mesh.add_child(sparks)
		_brake_sparks.append(sparks)

		# Brake light — blue plasma glow
		var brake_light := OmniLight3D.new()
		brake_light.light_color = Color(0.4, 0.7, 1.0)
		brake_light.light_energy = 0.0
		brake_light.omni_range = 25.0
		brake_light.omni_attenuation = 1.0
		brake_light.shadow_enabled = false
		brake_light.position = Vector3(sx, 0.05, 1.5)
		_vehicle_mesh.add_child(brake_light)
		_brake_lights.append(brake_light)

		# Strut connecting nacelle to monocoque
		_box(_vehicle_mesh, Vector3(absf(sx) - 0.7, 0.05, 1.4), Vector3(side * 0.95, -0.04, -1.2), carbon_mat)

		# Neon trim along nacelle
		_box(_vehicle_mesh, Vector3(0.03, 0.06, 2.2), Vector3(sx + side * 0.28, 0.02, -1.8), accent_mat)

	# ════════════════════════════════════════════════════════════════════════
	#  COCKPIT — realistic canopy with frame
	# ════════════════════════════════════════════════════════════════════════
	# Cockpit surround / halo
	_box(_vehicle_mesh, Vector3(0.82, 0.06, 1.1), Vector3(0, 0.28, 0.7), carbon_mat)
	# Canopy glass
	_box(_vehicle_mesh, Vector3(0.60, 0.18, 0.85), Vector3(0, 0.26, 0.75), canopy_mat)
	# Headrest fairing
	_box(_vehicle_mesh, Vector3(0.35, 0.16, 0.5), Vector3(0, 0.24, 0.1), body_mat)
	# Roll hoop / airbox intake
	_box(_vehicle_mesh, Vector3(0.28, 0.22, 0.35), Vector3(0, 0.36, 0.3), carbon_mat)

	# ════════════════════════════════════════════════════════════════════════
	#  REAR WING — multi-element, high mounted
	# ════════════════════════════════════════════════════════════════════════
	# Main plane
	_box(_vehicle_mesh, Vector3(3.4, 0.04, 0.4), Vector3(0, 0.50, -2.8), accent_mat)
	# Flap
	_box(_vehicle_mesh, Vector3(3.2, 0.03, 0.22), Vector3(0, 0.46, -3.05), accent_mat)
	# Endplates
	for side: int in [-1, 1]:
		_box(_vehicle_mesh, Vector3(0.03, 0.34, 0.6), Vector3(side * 1.7, 0.36, -2.9), accent_mat)
	# Swan-neck supports (top-mounted)
	for side: int in [-1, 1]:
		_box(_vehicle_mesh, Vector3(0.04, 0.04, 0.9), Vector3(side * 0.6, 0.48, -2.4), carbon_mat)
		_box(_vehicle_mesh, Vector3(0.04, 0.28, 0.04), Vector3(side * 0.6, 0.36, -2.0), carbon_mat)

	# ════════════════════════════════════════════════════════════════════════
	#  DORSAL FIN + SHARK FIN
	# ════════════════════════════════════════════════════════════════════════
	_box(_vehicle_mesh, Vector3(0.04, 0.40, 1.6), Vector3(0, 0.38, -1.5), body_mat)
	# Antenna/telemetry mast
	_box(_vehicle_mesh, Vector3(0.02, 0.12, 0.02), Vector3(0, 0.60, -0.8), accent_mat)

	# ════════════════════════════════════════════════════════════════════════
	#  DIFFUSER — aggressive rear undertray
	# ════════════════════════════════════════════════════════════════════════
	_box(_vehicle_mesh, Vector3(2.0, 0.06, 0.7), Vector3(0, -0.10, -2.8), carbon_mat)
	# Diffuser fences
	for i in range(-2, 3):
		_box(_vehicle_mesh, Vector3(0.02, 0.10, 0.65), Vector3(float(i) * 0.4, -0.06, -2.8), dark_mat)

	# ════════════════════════════════════════════════════════════════════════
	#  FLOOR + BARGEBOARDS
	# ════════════════════════════════════════════════════════════════════════
	_box(_vehicle_mesh, Vector3(1.6, 0.02, 5.0), Vector3(0, -0.10, 0), carbon_mat)
	# Bargeboards
	for side: int in [-1, 1]:
		_box(_vehicle_mesh, Vector3(0.02, 0.14, 0.8), Vector3(side * 0.85, 0.0, 1.8), accent_mat)
		_box(_vehicle_mesh, Vector3(0.02, 0.10, 0.6), Vector3(side * 0.95, 0.0, 1.5), body_mat)

	# Neon underbody strips
	for side: int in [-1, 1]:
		_box(_vehicle_mesh, Vector3(0.04, 0.02, 4.5), Vector3(side * 0.7, -0.12, 0), accent_mat)

	# ════════════════════════════════════════════════════════════════════════
	#  LIGHTS
	# ════════════════════════════════════════════════════════════════════════
	_underbody_light = OmniLight3D.new()
	_underbody_light.light_color      = accent_color
	_underbody_light.light_energy     = 5.0
	_underbody_light.omni_range       = 6.0
	_underbody_light.omni_attenuation = 1.4
	_underbody_light.position         = Vector3(0, -0.35, 0)
	_vehicle_mesh.add_child(_underbody_light)

	_boost_light = OmniLight3D.new()
	_boost_light.light_color  = Color(0.4, 0.75, 1.0)
	_boost_light.light_energy = 0.0
	_boost_light.omni_range   = 12.0
	_boost_light.position     = Vector3(0, 0, -3.5)
	_vehicle_mesh.add_child(_boost_light)

	# Headlights
	for side: int in [-1, 1]:
		var hl := OmniLight3D.new()
		hl.light_color      = Color(0.85, 0.92, 1.0)
		hl.light_energy     = 3.0
		hl.omni_range       = 15.0
		hl.omni_attenuation = 1.2
		hl.position         = Vector3(side * 0.35, 0.0, 3.8)
		_vehicle_mesh.add_child(hl)

	# Engine glow
	for side: int in [-1, 1]:
		var eg := OmniLight3D.new()
		eg.light_color      = accent_color
		eg.light_energy     = 6.0
		eg.omni_range       = 4.0
		eg.omni_attenuation = 1.8
		eg.position         = Vector3(side * 1.65, 0.0, -3.2)
		_vehicle_mesh.add_child(eg)

	# Hover pad lights
	for offset in HOVER_OFFSETS:
		var pad_l := OmniLight3D.new()
		pad_l.light_color      = accent_color
		pad_l.light_energy     = 2.5
		pad_l.omni_range       = 3.0
		pad_l.omni_attenuation = 1.8
		pad_l.position         = offset + Vector3(0, -0.26, 0)
		_vehicle_mesh.add_child(pad_l)
		_pad_lights.append(pad_l)

	# Rear brake light strip
	_box(_vehicle_mesh, Vector3(1.8, 0.06, 0.04), Vector3(0, 0.12, -3.1), _make_neon_mat(Color(0.2, 0.5, 1.0), 3.0))

	# ════════════════════════════════════════════════════════════════════════
	#  UNDER-BOOST SIDE THRUSTERS — lateral plasma jets under each side
	# ════════════════════════════════════════════════════════════════════════
	for side: int in [-1, 1]:
		var sx := side * 1.2
		var jet_y := -0.18  # Under the hull

		# Plasma cones fire sideways — 3 layers like brake jets
		# Outer — wide, warm orange-magenta
		var ub_outer_mat := StandardMaterial3D.new()
		ub_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ub_outer_mat.emission_enabled = true
		ub_outer_mat.emission = Color(1.0, 0.45, 0.2)
		ub_outer_mat.albedo_color = Color(1.0, 0.4, 0.15, 0.0)
		ub_outer_mat.emission_energy_multiplier = 0.0
		ub_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ub_outer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ub_jet_mats.append(ub_outer_mat)

		var ub_outer := MeshInstance3D.new()
		var ub_oc := CylinderMesh.new()
		ub_oc.top_radius = 0.30; ub_oc.bottom_radius = 0.0; ub_oc.height = 3.0
		ub_outer.mesh = ub_oc
		ub_outer.position = Vector3(sx + side * 1.5, jet_y, 0.0)
		ub_outer.rotation_degrees = Vector3(0, 0, side * 90.0)  # Fire sideways outward
		ub_outer.material_override = ub_outer_mat
		_vehicle_mesh.add_child(ub_outer)

		# Mid — brighter, tighter
		var ub_mid_mat := StandardMaterial3D.new()
		ub_mid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ub_mid_mat.emission_enabled = true
		ub_mid_mat.emission = Color(1.0, 0.6, 0.3)
		ub_mid_mat.albedo_color = Color(1.0, 0.55, 0.25, 0.0)
		ub_mid_mat.emission_energy_multiplier = 0.0
		ub_mid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ub_mid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ub_jet_mats.append(ub_mid_mat)

		var ub_mid := MeshInstance3D.new()
		var ub_mc := CylinderMesh.new()
		ub_mc.top_radius = 0.18; ub_mc.bottom_radius = 0.0; ub_mc.height = 2.2
		ub_mid.mesh = ub_mc
		ub_mid.position = Vector3(sx + side * 1.1, jet_y, 0.0)
		ub_mid.rotation_degrees = Vector3(0, 0, side * 90.0)
		ub_mid.material_override = ub_mid_mat
		_vehicle_mesh.add_child(ub_mid)

		# Core — white-hot center
		var ub_core_mat := StandardMaterial3D.new()
		ub_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ub_core_mat.emission_enabled = true
		ub_core_mat.emission = Color(1.0, 0.9, 0.7)
		ub_core_mat.albedo_color = Color(1.0, 0.95, 0.8, 0.0)
		ub_core_mat.emission_energy_multiplier = 0.0
		ub_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ub_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ub_jet_mats.append(ub_core_mat)

		var ub_core := MeshInstance3D.new()
		var ub_cc := CylinderMesh.new()
		ub_cc.top_radius = 0.08; ub_cc.bottom_radius = 0.0; ub_cc.height = 1.4
		ub_core.mesh = ub_cc
		ub_core.position = Vector3(sx + side * 0.7, jet_y, 0.0)
		ub_core.rotation_degrees = Vector3(0, 0, side * 90.0)
		ub_core.material_override = ub_core_mat
		_vehicle_mesh.add_child(ub_core)

		# Thruster light — orange glow that spills onto the ground
		var ub_light := OmniLight3D.new()
		ub_light.light_color = Color(1.0, 0.5, 0.2)
		ub_light.light_energy = 0.0
		ub_light.omni_range = 8.0
		ub_light.omni_attenuation = 1.2
		ub_light.shadow_enabled = false
		ub_light.position = Vector3(sx, jet_y, 0.0)
		_vehicle_mesh.add_child(ub_light)
		_ub_lights.append(ub_light)

		# Sparks — hot embers blasting sideways
		var ub_sp := GPUParticles3D.new()
		ub_sp.amount = 32
		ub_sp.lifetime = 0.5
		ub_sp.explosiveness = 0.0
		ub_sp.randomness = 0.6
		ub_sp.emitting = false
		ub_sp.local_coords = true
		ub_sp.position = Vector3(sx + side * 0.5, jet_y, 0.0)
		ub_sp.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))

		var ub_spmat := ParticleProcessMaterial.new()
		ub_spmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		ub_spmat.emission_sphere_radius = 0.2
		ub_spmat.direction = Vector3(side, 0, 0)  # Blast sideways
		ub_spmat.spread = 35.0
		ub_spmat.initial_velocity_min = 20.0
		ub_spmat.initial_velocity_max = 50.0
		ub_spmat.scale_min = 0.04
		ub_spmat.scale_max = 0.10
		ub_spmat.gravity = Vector3(0, -5.0, 0)
		ub_spmat.damping_min = 2.0
		ub_spmat.damping_max = 5.0

		var ub_sp_grad := GradientTexture1D.new()
		var ub_sp_g := Gradient.new()
		ub_sp_g.colors = PackedColorArray([
			Color(1.0, 0.9, 0.6, 1.0),
			Color(1.0, 0.5, 0.2, 0.8),
			Color(1.0, 0.2, 0.05, 0.0),
		])
		ub_sp_g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		ub_sp_grad.gradient = ub_sp_g
		ub_spmat.color_ramp = ub_sp_grad
		ub_sp.process_material = ub_spmat

		var ub_sp_quad := QuadMesh.new()
		ub_sp_quad.size = Vector2(0.14, 0.14)
		var ub_sp_mat := StandardMaterial3D.new()
		ub_sp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ub_sp_mat.emission_enabled = true
		ub_sp_mat.emission = Color(1.0, 0.6, 0.2)
		ub_sp_mat.emission_energy_multiplier = 120.0
		ub_sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ub_sp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		ub_sp_mat.vertex_color_use_as_albedo = true
		ub_sp_quad.material = ub_sp_mat
		ub_sp.draw_pass_1 = ub_sp_quad

		_vehicle_mesh.add_child(ub_sp)
		_ub_sparks.append(ub_sp)

	# Collision box
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.8, 0.22, 5.0)
	col_shape.shape    = box
	col_shape.position = Vector3(0, 0.0, 0)
	add_child(col_shape)

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)

func _build_hover_rays() -> void:
	var ray_root := Node3D.new()
	ray_root.name = "HoverRays"
	add_child(ray_root)
	for pos in HOVER_OFFSETS:
		var ray := RayCast3D.new()
		ray.target_position = Vector3.DOWN * MAX_RAY_LENGTH
		ray.collision_mask  = 1
		ray.enabled         = true
		ray.position        = pos
		ray_root.add_child(ray)
		_hover_rays.append(ray)

func _build_effects() -> void:
	var fx := Node3D.new()
	fx.name = "Effects"
	add_child(fx)

	# Position label above AI vehicles — updates to show race position each frame
	if not is_player:
		_position_label = Label3D.new()
		_position_label.text          = "P?"
		_position_label.position      = Vector3(0, 2.2, 0)
		_position_label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
		_position_label.font_size     = 28
		_position_label.modulate      = vehicle_color.lightened(0.35)
		_position_label.outline_size  = 6
		_position_label.outline_modulate = Color.BLACK
		add_child(_position_label)

	if is_player:
		_build_audio()

	# ── Railing collision sparks ──────────────────────────────────────────────
	_railing_sparks = GPUParticles3D.new()
	_railing_sparks.amount = 48
	_railing_sparks.lifetime = 0.5
	_railing_sparks.explosiveness = 0.9   # Burst on contact
	_railing_sparks.randomness = 0.6
	_railing_sparks.one_shot = true
	_railing_sparks.emitting = false
	_railing_sparks.local_coords = false  # World space — sparks stay where they spawn
	_railing_sparks.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))

	var rsmat := ParticleProcessMaterial.new()
	rsmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	rsmat.emission_sphere_radius = 0.3
	rsmat.direction = Vector3(0, 1, 0)
	rsmat.spread = 70.0
	rsmat.initial_velocity_min = 20.0
	rsmat.initial_velocity_max = 50.0
	rsmat.scale_min = 0.04
	rsmat.scale_max = 0.12
	rsmat.gravity = Vector3(0, -15.0, 0)
	rsmat.damping_min = 2.0
	rsmat.damping_max = 5.0

	var rs_grad := GradientTexture1D.new()
	var rs_g := Gradient.new()
	rs_g.colors = PackedColorArray([
		Color(1.0, 0.9, 0.5, 1.0),    # Hot white-yellow
		Color(1.0, 0.5, 0.1, 0.9),    # Orange
		Color(0.8, 0.2, 0.0, 0.0),    # Fade to dark red
	])
	rs_g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	rs_grad.gradient = rs_g
	rsmat.color_ramp = rs_grad

	_railing_sparks.process_material = rsmat

	var rs_quad := QuadMesh.new()
	rs_quad.size = Vector2(0.15, 0.15)
	var rs_mat := StandardMaterial3D.new()
	rs_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rs_mat.emission_enabled = true
	rs_mat.emission = Color(1.0, 0.6, 0.2)
	rs_mat.emission_energy_multiplier = 120.0
	rs_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rs_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	rs_mat.vertex_color_use_as_albedo = true
	rs_quad.material = rs_mat
	_railing_sparks.draw_pass_1 = rs_quad
	add_child(_railing_sparks)

	# Contact flash light
	_railing_spark_light = OmniLight3D.new()
	_railing_spark_light.light_color = Color(1.0, 0.6, 0.2)
	_railing_spark_light.light_energy = 0.0
	_railing_spark_light.omni_range = 15.0
	_railing_spark_light.shadow_enabled = false
	add_child(_railing_spark_light)

	# TRON light trails — geometry ribbons built from position history
	_trail_left = _make_trail_mesh()
	_trail_left.name = "TrailL"
	_trail_right = _make_trail_mesh()
	_trail_right.name = "TrailR"

	# Boost rear light trail — red/orange TRON wall
	_trail_boost = MeshInstance3D.new()
	_trail_boost.mesh = ImmediateMesh.new()
	_trail_boost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_boost.name = "TrailBoost"
	var bmat := StandardMaterial3D.new()
	bmat.vertex_color_use_as_albedo = true
	bmat.albedo_color               = Color(1.0, 1.0, 1.0)
	bmat.emission_enabled           = true
	bmat.emission                   = Color(1.0, 1.0, 1.0)
	bmat.emission_energy_multiplier = 120.0
	bmat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.cull_mode                  = BaseMaterial3D.CULL_DISABLED
	_trail_boost.material_override  = bmat

	# Add to scene root (not vehicle child) so trails stay in world space
	call_deferred("_attach_trails")

func _build_audio() -> void:
	_engine_gen = AudioStreamGenerator.new()
	_engine_gen.mix_rate      = 44100.0
	_engine_gen.buffer_length = 0.30   # 300ms buffer — safe at any frame rate

	_engine_player = AudioStreamPlayer.new()
	_engine_player.stream    = _engine_gen
	_engine_player.volume_db = -3.0
	_engine_player.bus       = "SFX"
	add_child(_engine_player)
	_engine_player.play()

	# ── Flutter (STUTUTU) — separate audio stream ──
	_flutter_gen = AudioStreamGenerator.new()
	_flutter_gen.mix_rate      = 44100.0
	_flutter_gen.buffer_length = 0.50

	var flutter_player := AudioStreamPlayer.new()
	flutter_player.stream    = _flutter_gen
	flutter_player.volume_db = 1.0
	flutter_player.bus       = "SFX"
	flutter_player.name      = "FlutterPlayer"
	add_child(flutter_player)
	flutter_player.play()

	# Defer so the audio server has one frame to initialize the stream
	call_deferred("_init_audio_playback")

func _init_audio_playback() -> void:
	if _engine_player and _engine_player.is_playing():
		_engine_playback = _engine_player.get_stream_playback() as AudioStreamGeneratorPlayback
	var fp := get_node_or_null("FlutterPlayer") as AudioStreamPlayer
	if fp and fp.is_playing():
		_flutter_playback = fp.get_stream_playback() as AudioStreamGeneratorPlayback

func _build_camera() -> void:
	_spring_arm = SpringArm3D.new()
	_spring_arm.name              = "CameraArm"
	_spring_arm.spring_length     = 7.0
	# Test track has a road trimesh on layer 1 — spring arm colliding with the
	# banked surface behind the vehicle causes violent camera compression. On the
	# open test oval there are no walls to clip through, so disable collision there.
	_spring_arm.collision_mask    = 0 if GameManager.selected_track != 0 else 1
	_spring_arm.rotation_degrees.x = -16.0
	_spring_arm.position          = Vector3(0, 1.2, 0)
	add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name    = "PlayerCamera"
	_camera.fov     = 95.0
	_camera.near    = 0.15
	_camera.far     = 60000.0 if GameManager.selected_track != 0 else 8000.0
	_camera.current = true
	_spring_arm.add_child(_camera)

	# Speed-dependent motion blur overlay
	var blur_layer := CanvasLayer.new()
	blur_layer.name  = "MotionBlurLayer"
	blur_layer.layer = 100
	add_child(blur_layer)

	_blur_rect = ColorRect.new()
	_blur_rect.anchors_preset = Control.PRESET_FULL_RECT
	_blur_rect.mouse_filter   = Control.MOUSE_FILTER_IGNORE

	var shader := load("res://shaders/motion_blur.gdshader") as Shader
	if shader:
		_blur_material = ShaderMaterial.new()
		_blur_material.shader = shader
		_blur_material.set_shader_parameter("blur_strength", 0.0)
		_blur_material.set_shader_parameter("samples", 12)
		_blur_material.set_shader_parameter("blur_center", Vector2(0.5, 0.5))
		_blur_rect.material = _blur_material
	blur_layer.add_child(_blur_rect)

# ─── Materials ─────────────────────────────────────────────────────────────────
func _make_body_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color        = vehicle_color
	m.metallic            = 0.95
	m.roughness           = 0.08
	m.clearcoat           = 1.0
	m.clearcoat_roughness = 0.03
	m.emission_enabled    = true
	m.emission            = vehicle_color * 0.18
	return m

func _make_accent_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color               = accent_color
	m.metallic                   = 0.82
	m.roughness                  = 0.05
	m.emission_enabled           = true
	m.emission                   = accent_color
	m.emission_energy_multiplier = 2.5
	return m

func _make_canopy_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color               = Color(0.07, 0.52, 0.92, 0.48)
	m.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic                   = 0.1
	m.roughness                  = 0.02
	m.emission_enabled           = true
	m.emission                   = Color(0.1, 0.42, 0.82)
	m.emission_energy_multiplier = 1.1
	return m

func _make_engine_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color               = Color(0.08, 0.10, 0.16)
	m.metallic                   = 0.98
	m.roughness                  = 0.20
	m.emission_enabled           = true
	m.emission                   = accent_color
	m.emission_energy_multiplier = 3.5
	return m

func _make_dark_panel_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.07, 0.10)
	m.metallic     = 0.9
	m.roughness    = 0.3
	return m

func _make_carbon_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.04)
	m.metallic     = 0.7
	m.roughness    = 0.45
	return m

func _make_neon_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color               = color * 0.5
	m.emission_enabled           = true
	m.emission                   = color
	m.emission_energy_multiplier = energy
	return m

# ─── TRON Light Trails — Geometry ribbon from position history ─────────────────
func _make_trail_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color               = accent_color
	mat.emission_enabled           = true
	mat.emission                   = accent_color
	mat.emission_energy_multiplier = 75.0
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode                  = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test              = false
	mi.material_override = mat
	return mi

func _attach_trails() -> void:
	var root := get_tree().current_scene
	if root:
		if _trail_left:  root.add_child(_trail_left)
		if _trail_right: root.add_child(_trail_right)
		if _trail_boost: root.add_child(_trail_boost)

func _update_trail(trail: MeshInstance3D, data: Array) -> void:
	if trail == null or data.size() < 2:
		return
	var im := trail.mesh as ImmediateMesh
	if im == null:
		return
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var count := data.size()
	for i in count:
		var alpha  := 1.0 - float(i) / float(count)
		var bright := alpha * alpha
		var col    := Color(accent_color.r, accent_color.g, accent_color.b, bright)
		im.surface_set_color(col)
		var entry: Dictionary = data[count - 1 - i]
		var p:  Vector3 = entry.pos
		var up: Vector3 = entry.up
		im.surface_add_vertex(p)
		im.surface_add_vertex(p + up * TRAIL_HEIGHT)
	im.surface_end()

func _update_boost_trail() -> void:
	if _trail_boost == null:
		return
	var im := _trail_boost.mesh as ImmediateMesh
	if im == null:
		return
	im.clear_surfaces()
	if _trail_data_boost.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var count := _trail_data_boost.size()
	for i in count:
		var alpha  := 1.0 - float(i) / float(count)
		var bright := alpha * alpha
		im.surface_set_color(Color(1.0, 1.0, 1.0, bright))
		var entry: Dictionary = _trail_data_boost[count - 1 - i]
		var p:     Vector3 = entry.pos
		var right: Vector3 = entry.get("right", Vector3.RIGHT)
		im.surface_add_vertex(p - right * 0.9)
		im.surface_add_vertex(p + right * 0.9)
	im.surface_end()

# ─── Physics Process ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if has_finished:
		_coast_to_stop()
		return

	# Safety net: trigger well below ground (test track climbs to 420m so only
	# fire if we've genuinely fallen through the world, not off a banked section)
	if global_position.y < -80.0:
		_do_respawn()
		return
	
	_apply_hover(delta)
	_track_airtime(delta)
	_update_respawn(delta)
	_check_slipstream()
	_check_off_road(delta)
	_check_railing_collision(delta)
	_align_to_track(delta)
	_apply_propulsion(delta)
	_apply_steering(delta)
	_update_boost(delta)
	_clamp_velocity()
	_update_effects(delta)
	if is_player:
		_update_camera(delta)

	current_speed = linear_velocity.length()
	speed_changed.emit(current_speed * KMH_FACTOR)

# ─── Hover Physics ─────────────────────────────────────────────────────────────
# Spring-damper hover using synchronous PhysicsDirectSpaceState3D ray queries.
# Magnet hover — locks car at exactly hover_height above the road surface.
# Uses a velocity impulse instead of a spring: no oscillation, no resonance,
# no seam bumps. On each physics frame the car's velocity component along the
# road normal is set to exactly what's needed to reach hover_height, then left
# alone. When rays miss (hill crest, genuine jump) the car goes airborne freely.
func _apply_hover(_delta: float) -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		on_track = false
		return

	var hit_count  := 0
	var normal_sum := Vector3.ZERO
	var dist_sum   := 0.0
	var horiz_spd  := Vector2(linear_velocity.x, linear_velocity.z).length()

	for i in HOVER_OFFSETS.size():
		var off    := HOVER_OFFSETS[i] as Vector3
		var start  := to_global(off)
		var finish := start + Vector3(0.0, -MAX_RAY_LENGTH, 0.0)

		var p := PhysicsRayQueryParameters3D.new()
		p.from           = start
		p.to             = finish
		p.collision_mask = 1

		var r := space.intersect_ray(p)
		if r.is_empty():
			continue

		var hit_n := r["normal"] as Vector3

		# Smooth normal per-pad to remove seam-line jolts (safe: only affects direction)
		var n_smooth := lerpf(0.6, 0.06, clampf(horiz_spd / 400.0, 0.0, 1.0))
		_hover_smooth_n[i] = _hover_smooth_n[i].lerp(hit_n, n_smooth).normalized()

		normal_sum += _hover_smooth_n[i]
		dist_sum   += start.distance_to(r["position"] as Vector3)
		hit_count  += 1

	if hit_count > 0:
		on_track        = true
		track_normal    = (normal_sum / hit_count).normalized()
		_hover_avg_dist = dist_sum / hit_count

		# Cancel gravity so ship feels weightless while hovering
		apply_central_force(Vector3.UP * gravity_scale * 9.8 * mass)

		# ── Predictive anti-tunnel ────────────────────────────────────────────
		# At high speed, cast a ray along our velocity vector for 1 frame of
		# travel. If it hits the road surface *from above* (approaching the
		# surface), and we'd overshoot past it, deflect the velocity component
		# that's driving us into the surface so we skim along instead.
		if horiz_spd > 60.0:
			var vel_dir  := linear_velocity.normalized()
			var look_len := linear_velocity.length() * _delta * 2.5  # 2.5 frames ahead
			if look_len > 1.0:
				var vp := PhysicsRayQueryParameters3D.new()
				vp.from           = global_position
				vp.to             = global_position + vel_dir * look_len
				vp.collision_mask = 1
				var vr := space.intersect_ray(vp)
				if not vr.is_empty():
					var vhit_n := (vr["normal"] as Vector3)
					# Only act if we're heading INTO the surface (not away)
					var approach := linear_velocity.dot(-vhit_n)
					if approach > 10.0:
						# Remove the into-surface component, keep tangential speed
						linear_velocity += vhit_n * approach

		# ── Magnet lock ───────────────────────────────────────────────────────
		# Compute the velocity the car needs along the road normal to sit at
		# hover_height. Directly impulse to that velocity — no spring, no bounce.
		#   err > 0 → car is too low  → push up   (large positive target_n)
		#   err < 0 → car is too high → let gravity pull (small negative target_n)
		var err      := hover_height - _hover_avg_dist
		var vel_n    := linear_velocity.dot(track_normal)
		var target_n := clampf(err * 40.0, -20.0, 50.0)
		apply_central_impulse(track_normal * (target_n - vel_n) * mass)
	else:
		# ── Tunnel-through recovery ──────────────────────────────────────────
		# All downward rays missed. We may have punched through the road.
		# Strategy: cast a DOWNWARD ray from well above our position to find
		# the TOP surface of the road. This avoids the old bug where an
		# upward ray hit the slab's bottom face and teleported us inside it.
		# Try multiple probe origins: last known track normal, vehicle local
		# up, and world up — to handle steep banks where "above" isn't +Y.
		var recovered := false
		var probe_dirs: Array[Vector3] = []
		probe_dirs.append(track_normal)              # Last known surface normal
		probe_dirs.append(global_basis.y.normalized()) # Vehicle's local up
		if track_normal.distance_to(Vector3.UP) > 0.1:
			probe_dirs.append(Vector3.UP)             # World up (if different)

		for probe_up in probe_dirs:
			if recovered:
				break
			# Start 20m above along this direction, cast 40m downward
			var probe_origin := global_position + probe_up * 20.0
			var probe_end    := global_position - probe_up * 20.0
			var rp := PhysicsRayQueryParameters3D.new()
			rp.from           = probe_origin
			rp.to             = probe_end
			rp.collision_mask = 1
			var rr := space.intersect_ray(rp)
			if not rr.is_empty():
				var surf_pos := rr["position"] as Vector3
				var surf_n   := rr["normal"] as Vector3
				# Ensure normal faces outward (toward probe origin, away from slab)
				if surf_n.dot(probe_up) < 0.0:
					surf_n = -surf_n
				# Only recover if we're actually BELOW this surface (tunnelled)
				var to_surf := surf_pos - global_position
				if to_surf.dot(probe_up) > 0.5:
					# Teleport to hover_height above the TOP surface
					global_position  = surf_pos + surf_n * hover_height
					# Kill velocity component driving into the surface
					var pen_vel := linear_velocity.dot(-surf_n)
					if pen_vel > 0.0:
						linear_velocity += surf_n * pen_vel
					on_track        = true
					track_normal    = surf_n
					_hover_avg_dist = hover_height
					recovered       = true

		if not recovered:
			on_track        = false
			track_normal    = Vector3.UP
			_hover_avg_dist = MAX_RAY_LENGTH


func _track_airtime(delta: float) -> void:
	if not on_track:
		_airtime_t += delta
	else:
		if _airtime_t > 0.30:
			if is_player:
				_cam_trauma = minf(_cam_trauma + _airtime_t * 0.18, 0.60)
			airborne.emit(_airtime_t)
		_airtime_t = 0.0

## Respawn system: saves the last safe on-track position every second.
## If the vehicle falls off-world for > 6s, teleports back to that position.
func _update_respawn(delta: float) -> void:
	if has_finished or lap == 0:
		return
	if on_track:
		_fall_timer     = 0.0
		# Save a respawn point every 1.2s of good on-track driving, OR immediately
		# if we've never saved one yet (e.g. start of race).
		_respawn_save_t += delta
		# Save more frequently on high-speed test track so respawn always lands on road
		var save_interval := 0.15 if GameManager.selected_track != 0 else 0.4
		if _respawn_save_t >= save_interval or not _has_respawn_pos:
			_respawn_save_t  = 0.0
			_has_respawn_pos = true
			_respawn_pos     = global_position
			# Always save upright basis — never save a tilted orientation
			var sfwd := -global_transform.basis.z
			sfwd.y = 0.0
			_respawn_basis = Basis.looking_at(
				sfwd.normalized() if sfwd.length_squared() > 0.01 else Vector3(0.0, 0.0, -1.0),
				Vector3.UP
			)
	else:
		_fall_timer += delta
		# Test track has large elevation changes — give more time to recover before respawning
		var fall_threshold := 4.0 if GameManager.selected_track != 0 else 1.8
		if _fall_timer >= fall_threshold:
			_do_respawn()

func _do_respawn() -> void:
	if not _has_respawn_pos:
		# No safe position known yet — lift straight up so hover can engage
		global_position  = Vector3(global_position.x, 5.0, global_position.z)
		linear_velocity  = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		_fall_timer      = 0.0
		return
	# Always respawn upright — _respawn_basis may have been saved while tilted
	var fwd := (_respawn_basis * Vector3(0.0, 0.0, -1.0))
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3(0.0, 0.0, -1.0)
	var upright := Basis.looking_at(fwd.normalized(), Vector3.UP)
	global_transform  = Transform3D(upright, _respawn_pos + Vector3(0, 2.5, 0))
	linear_velocity   = Vector3.ZERO
	angular_velocity  = Vector3.ZERO
	_fall_timer       = 0.0
	_airtime_t        = 0.0
	_trail_data_left.clear()
	_trail_data_right.clear()
	if is_player:
		_cam_trauma = minf(_cam_trauma + 0.35, 0.70)

## Slipstream: detect if we are in the aerodynamic wake of a vehicle ahead.
## Cone check — vehicle must be within 14m and within ~28° of our forward axis.
func _check_slipstream() -> void:
	var fwd    := -global_transform.basis.z
	var was_in := _in_slipstream
	_in_slipstream = false
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == self or not (v is IonVehicle):
			continue
		var iv := v as IonVehicle
		if iv.has_finished:
			continue
		var to_v := iv.global_position - global_position
		var dist  := to_v.length()
		if dist < 2.0 or dist > 14.0:
			continue
		if to_v.normalized().dot(fwd) > 0.88:   # ≈ 28° cone ahead
			_in_slipstream = true
			break
	if _in_slipstream != was_in:
		slipstream_changed.emit(_in_slipstream)

func _align_to_track(_delta: float) -> void:
	if not on_track:
		return
	var cur_up  := global_transform.basis.y
	var want_up := track_normal
	var axis    := cur_up.cross(want_up)
	if axis.length_squared() < 0.0001:
		return
	var angle := cur_up.angle_to(want_up)
	apply_torque(axis.normalized() * angle * hover_tilt_correction)

# ─── Off-road / barrier penalty ───────────────────────────────────────────
func set_track_waypoints(pts: Array[Vector3], half_width: float) -> void:
	_track_waypoints = pts
	_track_half_width = half_width

func _check_off_road(delta: float) -> void:
	if _track_waypoints.is_empty() or not on_track:
		_off_road = false
		return

	_off_road_penalty_cooldown = maxf(_off_road_penalty_cooldown - delta, 0.0)

	var pos := global_position
	var n := _track_waypoints.size()

	# Find the closest point on the entire track centerline.
	# Check every segment, project the vehicle onto it, keep the minimum.
	var best_lateral_sq := INF

	# Coarse pass: find nearest waypoint (check all — they're just distance checks)
	var best_wp := 0
	var best_wp_dist_sq := INF
	for i in n:
		var dx := pos.x - _track_waypoints[i].x
		var dz := pos.z - _track_waypoints[i].z
		var d := dx * dx + dz * dz
		if d < best_wp_dist_sq:
			best_wp_dist_sq = d
			best_wp = i

	# Fine pass: check segments around the nearest waypoint (generous window for curves)
	for offset in range(-20, 21):
		var i := (best_wp + offset + n) % n
		var a := _track_waypoints[i]
		var b := _track_waypoints[(i + 1) % n]
		var abx := b.x - a.x
		var abz := b.z - a.z
		var len_sq := abx * abx + abz * abz
		if len_sq < 0.001:
			continue
		var t := clampf((abx * (pos.x - a.x) + abz * (pos.z - a.z)) / len_sq, 0.0, 1.0)
		var cx := a.x + abx * t
		var cz := a.z + abz * t
		var dx := pos.x - cx
		var dz := pos.z - cz
		var lat_sq := dx * dx + dz * dz
		if lat_sq < best_lateral_sq:
			best_lateral_sq = lat_sq

	var lateral_dist := sqrt(best_lateral_sq)

	# Barrier edge: EDGE_OFFSET (150) from centre, curbs at EDGE_OFFSET + 3 = 153
	# Penalty starts right at the barrier line
	var barrier_dist := _track_half_width - 7.0  # 153m — where curbs actually are
	_off_road = lateral_dist > barrier_dist

	# Speed penalty is now handled by _check_railing_collision() with sparks

# ─── Railing collision — lateral raycasts detect track-edge walls ─────────────
# Casts rays sideways from vehicle to find railing walls (layer 4).
# On hit: sparks at contact, speed penalty, bounce force along wall normal.
func _check_railing_collision(delta: float) -> void:
	_railing_hit_cooldown = maxf(_railing_hit_cooldown - delta, 0.0)
	_railing_scrape_t = maxf(_railing_scrape_t - delta, 0.0)

	# Fade spark light
	if _railing_spark_light:
		_railing_spark_light.light_energy = lerpf(_railing_spark_light.light_energy, 0.0, delta * 12.0)

	var space := get_world_3d().direct_space_state
	if space == null:
		return

	var veh_right := global_transform.basis.x.normalized()
	var veh_fwd   := -global_transform.basis.z.normalized()

	# Ray origins: front, mid, rear — on both sides
	var ray_origins := [
		Vector3(0, 0.5,  2.2),   # Front centre-ish
		Vector3(0, 0.5,  0.0),   # Mid
		Vector3(0, 0.5, -2.2),   # Rear
	]

	var closest_hit_dist := RAILING_RAY_REACH + 1.0
	var closest_hit_pos  := Vector3.ZERO
	var closest_hit_n    := Vector3.ZERO
	var any_hit          := false

	for origin_local in ray_origins:
		var origin_world := to_global(origin_local)
		for side in [-1.0, 1.0]:
			var ray_dir: Vector3 = veh_right * float(side)
			var rp := PhysicsRayQueryParameters3D.new()
			rp.from           = origin_world
			rp.to             = origin_world + ray_dir * RAILING_RAY_REACH
			rp.collision_mask = RAILING_RAY_LAYER
			var rr := space.intersect_ray(rp)
			if not rr.is_empty():
				var hit_dist := origin_world.distance_to(rr["position"] as Vector3)
				if hit_dist < closest_hit_dist:
					closest_hit_dist = hit_dist
					closest_hit_pos  = rr["position"] as Vector3
					closest_hit_n    = rr["normal"] as Vector3
					any_hit = true

	if not any_hit:
		return

	# ── Contact response ──────────────────────────────────────────────────────
	# Railing proximity threshold — vehicle half-width is ~1.65m
	var contact_threshold := 2.5

	if closest_hit_dist < contact_threshold:
		# How hard are we pressing into the wall?
		var into_wall := linear_velocity.dot(-closest_hit_n)

		if into_wall > 3.0:
			# ── Speed penalty: scale with approach speed (Trackmania-style) ──
			if _railing_hit_cooldown <= 0.0:
				var penalty := clampf(into_wall / current_speed, 0.15, 0.5) if current_speed > 1.0 else 0.3
				linear_velocity *= (1.0 - penalty)
				_railing_hit_cooldown = 0.15  # Brief cooldown to prevent stacking

			# ── Bounce force: push away from wall ─────────────────────────────
			var bounce_strength := clampf(into_wall * 0.6, 5.0, 40.0)
			linear_velocity += closest_hit_n * bounce_strength

			# ── Sparks at contact point ───────────────────────────────────────
			if _railing_sparks:
				_railing_sparks.global_position = closest_hit_pos
				# Aim sparks along the wall in travel direction + outward scatter
				var spark_dir := (veh_fwd * 0.7 + closest_hit_n * 0.5).normalized()
				var pmat := _railing_sparks.process_material as ParticleProcessMaterial
				if pmat:
					pmat.direction = spark_dir
					# Scale particle speed with vehicle speed
					pmat.initial_velocity_min = clampf(current_speed * 0.3, 10.0, 30.0)
					pmat.initial_velocity_max = clampf(current_speed * 0.6, 20.0, 60.0)
				_railing_sparks.restart()
				_railing_sparks.emitting = true

			# ── Flash light ───────────────────────────────────────────────────
			if _railing_spark_light:
				_railing_spark_light.global_position = closest_hit_pos
				_railing_spark_light.light_energy = clampf(into_wall * 0.5, 2.0, 12.0)

			# ── Camera shake ──────────────────────────────────────────────────
			if is_player:
				_cam_trauma = minf(_cam_trauma + into_wall * 0.012, 0.8)

			_railing_scrape_t = 0.3

# ─── Propulsion ────────────────────────────────────────────────────────────────
func _apply_propulsion(delta: float) -> void:
	if not on_track:
		return
	var fwd := -global_transform.basis.z

	# Diminishing-returns thrust: full force at low speed, tapers as you go faster
	# but NEVER reaches zero — you can always gain a little more speed.
	# Formula: effective_thrust = base_thrust / (1 + speed/reference_speed)
	var spd := linear_velocity.length()
	var ref_speed := 300.0   # Speed at which thrust is halved
	var boost_ref := 500.0   # Boost reference — stays strong longer

	if input_thrust > 0.0:
		var thrust_eff := thrust_force / (1.0 + spd / ref_speed)
		var boost_eff  := (boost_force / (1.0 + spd / boost_ref)) if is_boosting else 0.0
		apply_central_force(fwd * (thrust_eff + boost_eff) * input_thrust)

	# Braking
	if input_brake > 0.0:
		var brake_fwd_spd := linear_velocity.dot(fwd)
		if brake_fwd_spd > 0.5:
			apply_central_force(-fwd * brake_force * input_brake)
		elif brake_fwd_spd > -5.0:
			apply_central_force(-fwd * reverse_force * input_brake)

	# Light drag — just enough to slow you down when not thrusting, never a hard wall
	if spd > 0.1:
		apply_central_force(-linear_velocity.normalized() * spd * 0.8)

	# Slipstream draft — free speed in the wake of a vehicle ahead
	if _in_slipstream and input_thrust > 0.3 and on_track:
		var fwd_slip := -global_transform.basis.z
		apply_central_force(fwd_slip * thrust_force * 0.24 * input_thrust)

	# Speed turbulence: organic airflow vibration at high velocity
	_apply_speed_turbulence(delta)

func _apply_speed_turbulence(delta: float) -> void:
	# Only fires above 600 m/s to avoid making low-speed feel sluggish
	var spd_ratio := clampf(current_speed / 2400.0, 0.0, 1.5)
	var turb_t    := maxf(spd_ratio - 0.25, 0.0) / 0.75
	if turb_t < 0.01 or not on_track:
		return

	_turbulence_t += delta * 16.0
	var t  := _turbulence_t
	var tt := turb_t * turb_t
	var tx := (sin(t * 1.37) + sin(t * 3.71) * 0.4 + sin(t * 7.13) * 0.2) * tt * 100.0
	var ty := (sin(t * 2.13) + sin(t * 5.41) * 0.3) * tt * 32.0
	var tz := (cos(t * 1.89) + cos(t * 4.23) * 0.3) * tt * 65.0
	apply_central_force(Vector3(tx, ty, tz))

# ─── Steering ──────────────────────────────────────────────────────────────────
func _apply_steering(delta: float) -> void:
	if not on_track:
		return

	var up    := global_transform.basis.y
	var right := global_transform.basis.x
	var fwd   := -global_transform.basis.z

	var spd := linear_velocity.length()

	# Speed-dependent steering: full authority at low speed, diminishing at high speed.
	# At 300 m/s steering is halved, at 600 m/s it's a third — prevents tiny inputs
	# causing massive direction changes when going fast.
	var steer_ref := 300.0
	var steer_scale := 1.0 / (1.0 + spd / steer_ref)

	var steer := input_steer * steer_scale
	var sens: float = STEER_MULTIPLIERS[steer_sensitivity]
	apply_torque(up * -steer * steer_speed * sens)

	# Progressive lateral grip: full grip at low speed for tight control,
	# softer at high speed so tiny yaw changes don't instantly redirect all velocity.
	# At 300 m/s grip is halved, still enough to hold corners but forgiving.
	var grip_ref := 300.0
	var grip_scale := 1.0 / (1.0 + spd / grip_ref)
	var lat_vel := linear_velocity.dot(right)
	var effective_grip := lateral_drag * (0.3 + 0.7 * grip_scale)  # Never below 30% grip
	# Reduce lateral grip during under-boost so the thrust can actually slide the car
	if input_under_boost and energy > 0.0 and not boost_empty:
		effective_grip *= 0.05
	apply_central_force(-right * lat_vel * effective_grip * mass)

	# Adaptive yaw damping: heavier at high speed for stability.
	# When steering → reduced damping so you can still turn.
	# When hands off → strong damping, even stronger at speed.
	var yaw_vel    := angular_velocity.dot(up)
	var steer_mag  := absf(steer)
	var base_damp  := lerpf(300.0, 50.0, clampf(steer_mag * 2.0, 0.0, 1.0))
	# Extra damping at speed — up to 2× more at high velocity
	var speed_damp := 1.0 + clampf(spd / 400.0, 0.0, 1.0)
	apply_torque(up * -yaw_vel * base_damp * speed_damp)

	# ── Air Bank (Q/E or LMB/RMB) ──
	if _air_bank_input != 0.0 and on_track:
		_apply_air_bank(delta, _air_bank_input, up)

	# ── Visual chassis dynamics ──
	var fwd_spd   := linear_velocity.dot(fwd)
	var fwd_accel := (fwd_spd - _prev_fwd_speed) / maxf(delta, 0.001)
	_prev_fwd_speed = fwd_spd

	# Banking into turns — lean into the direction you're steering
	var spd_ratio   := clampf(spd / 300.0, 0.0, 1.5)
	# Use steering input for banking direction (positive steer = turning right = bank right)
	var bank_target := -steer * steer_tilt_factor * 2.5
	# Add speed-proportional banking from lateral velocity for physical feel
	# Excluded during under-boost: UB lateral force would feed back through lat_vel
	# and flatten the car, defeating the purpose of the mechanic
	var ub_firing := input_under_boost and energy > 0.0 and not boost_empty
	if not ub_firing:
		bank_target += lat_vel * 0.015 * clampf(spd_ratio, 0.0, 1.3)
	bank_target = clampf(bank_target, -steer_tilt_factor * 2.2, steer_tilt_factor * 2.2)
	if absf(_dash_body_roll) > 0.01:
		bank_target = clampf(bank_target + _dash_body_roll, -steer_tilt_factor * 2.2, steer_tilt_factor * 2.2)
	# Only decay body roll when NOT actively air banking — prevents flattening mid-bank
	if _air_bank_input == 0.0:
		_dash_body_roll = lerpf(_dash_body_roll, 0.0, delta * 5.0)

	current_roll = lerpf(current_roll, bank_target, delta * steer_recovery_speed)

	# ── Under Boost (Shift) — lateral thrust based on actual vehicle roll angle ──
	# Works during air banking OR normal steering turns. The more the car is rolled,
	# the stronger the sideways push. No roll = no thrust.
	# Roll stays wherever air banking / steering put it — UB just pushes sideways.
	if input_under_boost and on_track and energy > 0.0 and not boost_empty:
		var roll_amount := current_roll
		var roll_ratio := clampf(absf(roll_amount) / (steer_tilt_factor * 2.2), 0.0, 1.0)
		if roll_ratio > 0.05:
			var roll_dir := -signf(roll_amount)  # Push opposite to lean — into the turn
			apply_central_force(right * roll_dir * UNDER_BOOST_FORCE * roll_ratio)

	if _vehicle_mesh:
		_vehicle_mesh.rotation.z = -current_roll  # Negated because mesh is flipped PI on Y
		# Pitch: nose dips on braking, lifts on heavy accel — weight-transfer feel
		var pitch_target := clampf(-fwd_accel * 0.00075 - input_thrust * 0.045 + input_brake * 0.08, -0.12, 0.10)
		_vehicle_mesh.rotation.x = lerpf(_vehicle_mesh.rotation.x, -pitch_target, delta * 7.0)

# ─── Boost / Energy ────────────────────────────────────────────────────────────
func refill_energy() -> void:
	energy = max_energy
	boost_empty = false
	boost_recharge_t = 0.0
	energy_changed.emit(energy, max_energy)
	if is_player:
		_boost_full_ping  = 1.0
		_boost_full_ping3 = 0.0
		_boost_full_t     = 0.0

func _update_boost(delta: float) -> void:
	var boost_just_started := false

	if input_boost and energy > 0.0 and not boost_empty:
		if not is_boosting:
			boost_just_started = true
		is_boosting        = true
		energy            -= energy_drain * delta
		boost_recharge_t   = boost_recharge_delay
		if energy <= 0.0:
			energy      = 0.0
			is_boosting = false
			boost_empty = true
			boost_depleted.emit()
	else:
		is_boosting = false

	# Under-boost drains from the same energy pool at 2× the normal rate
	if input_under_boost and energy > 0.0 and not boost_empty:
		energy -= energy_drain * 2.0 * delta
		boost_recharge_t = boost_recharge_delay
		if energy <= 0.0:
			energy = 0.0
			boost_empty = true
			boost_depleted.emit()

	# Boost activation: sharp velocity impulse + mild camera punch
	if boost_just_started and on_track:
		apply_central_impulse(-global_transform.basis.z * boost_kick_speed)
		_boost_shudder_t = 0.20
		if is_player:
			_cam_trauma = minf(_cam_trauma + 0.30, 1.0)
		boost_activated.emit()

	# Boost shudder: subtle lateral wobble only — no vertical force (that fights hover)
	if _boost_shudder_t > 0.0:
		_boost_shudder_t -= delta
		var shudder_force := sin(_boost_shudder_t * 22.0) * 400.0
		apply_central_force(global_transform.basis.x * shudder_force)

	if boost_recharge_t > 0.0:
		boost_recharge_t -= delta
	else:
		boost_empty = false
		var prev_energy := energy
		energy = minf(energy + energy_regen * delta, max_energy)
		if is_player and energy >= max_energy and prev_energy < max_energy:
			_boost_full_ping  = 1.0
			_boost_full_ping3 = 0.0
			_boost_full_t     = 0.0

	energy_changed.emit(energy, max_energy)


# ─── Air Bank ──────────────────────────────────────────────────────────────────
# Applies continuous yaw torque + braking drag while held, like WipEout air brakes.
# Called from _apply_steering each physics frame when _air_bank_input != 0.
func _apply_air_bank(delta: float, dir: float, up: Vector3) -> void:
	var spd := linear_velocity.length()
	# Stronger effect at higher speed — air brakes matter most when fast
	var speed_factor := clampf(spd / 200.0, 0.3, 1.5)

	# Yaw torque: turn the nose into the banked direction
	apply_torque(up * -dir * AIR_BANK_YAW_FORCE * speed_factor)

	# Braking drag: air banks scrub speed — you trade speed for turning
	var fwd := -global_transform.basis.z
	var fwd_spd := linear_velocity.dot(fwd)
	if fwd_spd > 5.0:
		apply_central_force(fwd * -AIR_BANK_BRAKE_FORCE * speed_factor)

	# Visual: body roll only — camera follows normal steering tilt
	# Negative dir so the ship banks INTO the turn (mesh rotation is negated)
	_dash_body_roll = lerpf(_dash_body_roll, -dir * steer_tilt_factor * 2.5, delta * 10.0)

func _update_ghosts(delta: float) -> void:
	for i in range(_ghost_nodes.size() - 1, -1, -1):
		var g: Dictionary = _ghost_nodes[i]
		g.t -= delta
		if g.t <= 0.0:
			(g.node as Node3D).queue_free()
			_ghost_nodes.remove_at(i)
			continue
		var ratio: float = g.t / g.max_t
		var v: Vector3 = g.vel
		if v != Vector3.ZERO:
			(g.node as Node3D).global_position += v * delta
			g.vel.y -= 9.8 * delta
		var mat: StandardMaterial3D = g.mat
		mat.albedo_color.a               = ratio * (g.base_alpha as float)
		mat.emission_energy_multiplier   = ratio * (g.base_energy as float)


# ─── Camera ────────────────────────────────────────────────────────────────────
func _update_camera(delta: float) -> void:
	if _camera == null or _spring_arm == null:
		return

	var cs := CameraSettings  # Shorthand for the autoload

	# Speed ratio
	var spd := linear_velocity.length()
	var spd_ratio := clampf(spd / 150.0, 0.0, 2.0)

	# ── Distance / Height / Pitch ──
	var boost_len := 0.8 if is_boosting else 0.0
	var target_len := cs.distance_base + spd_ratio * cs.distance_speed_scale + boost_len
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, target_len, delta * 3.5)

	var target_y := cs.height_base - spd_ratio * 0.3
	_spring_arm.position.y = lerpf(_spring_arm.position.y, target_y, delta * 2.5)

	# Only tilt camera down after genuine airtime (≥0.5s), not brief physics bounces
	var air_extra := clampf((_airtime_t - 0.5) / 0.8, 0.0, 1.0) * 12.0
	var target_pitch := cs.pitch_base - spd_ratio * cs.pitch_speed_scale + air_extra
	_spring_arm.rotation_degrees.x = lerpf(_spring_arm.rotation_degrees.x, target_pitch, delta * 3.0)

	# ── Lateral slide ──
	var speed_factor := clampf(spd / 150.0, 0.0, 1.0)
	var lateral_target := input_steer * cs.lateral_base + input_steer * cs.lateral_speed_scale * speed_factor
	var lat_rate := cs.lateral_out_rate if absf(lateral_target) >= absf(_cam_lateral) else cs.lateral_return_rate
	_cam_lateral = lerpf(_cam_lateral, lateral_target, delta * lat_rate)
	_spring_arm.position.x = _cam_lateral

	# ── Yaw follow ──
	var yaw_target := -input_steer * (cs.yaw_base + cs.yaw_speed_scale * speed_factor)
	_cam_yaw_lag = lerpf(_cam_yaw_lag, yaw_target, delta * cs.yaw_rate)
	_spring_arm.rotation.y = _cam_yaw_lag

	# ── Roll tilt ──
	var tilt_input := input_steer if absf(input_steer) > cs.tilt_deadzone else 0.0
	var lean_target := -tilt_input * (cs.tilt_base + cs.tilt_speed_scale * speed_factor)
	_cam_lean = lerpf(_cam_lean, lean_target, delta * cs.tilt_rate)
	_dash_cam_roll = lerpf(_dash_cam_roll, 0.0, delta * 7.0)
	_spring_arm.rotation.z = _cam_lean + _dash_cam_roll

	# ── FOV ──
	var boost_fov := cs.fov_boost if is_boosting else (5.0 if _in_slipstream else 0.0)
	var target_fov := cs.fov_base + spd_ratio * cs.fov_speed_scale + boost_fov
	_camera.fov = lerpf(_camera.fov, target_fov, delta * 4.0)

	# ── Motion blur ──
	if _blur_material:
		var blur_spd := clampf(spd / cs.blur_speed_ref, 0.0, 1.0)
		var blur_t := blur_spd * blur_spd
		var boost_extra := 0.35 if is_boosting else 0.0
		var target_blur := clampf(blur_t * cs.blur_strength + boost_extra, 0.0, 1.0)
		var cur_blur: float = _blur_material.get_shader_parameter("blur_strength")
		_blur_material.set_shader_parameter("blur_strength", lerpf(cur_blur, target_blur, delta * 5.0))


# ─── Effects ───────────────────────────────────────────────────────────────────
func _update_effects(delta: float) -> void:
	# ── TRON light trails — record world positions of each engine nozzle ──
	if current_speed > 3.0 and on_track:
		# Use the visual mesh's world transform so trails follow the banked/pitched ship
		var mesh_xf := _vehicle_mesh.global_transform if _vehicle_mesh else global_transform
		var right := mesh_xf.basis.x
		var up_v  := mesh_xf.basis.y
		var back  := -mesh_xf.basis.z  # Mesh is flipped PI, so -Z = behind the vehicle
		var base  := mesh_xf.origin + back * 3.3 - up_v * 0.1
		var pos_l := base - right * 1.65
		var pos_r := base + right * 1.65

		# Interpolate extra points when moving fast so the trail curves smoothly
		var seg_max := 3.0
		if not _trail_data_left.is_empty():
			var prev_l: Vector3 = _trail_data_left[-1].pos
			var prev_r: Vector3 = _trail_data_right[-1].pos
			var prev_up: Vector3 = _trail_data_left[-1].up
			var gap := prev_l.distance_to(pos_l)
			if gap > seg_max:
				var steps := ceili(gap / seg_max)
				for s in range(1, steps):
					var t := float(s) / float(steps)
					var interp_up := prev_up.lerp(up_v, t).normalized()
					_trail_data_left.append({pos = prev_l.lerp(pos_l, t), up = interp_up, right = right})
					_trail_data_right.append({pos = prev_r.lerp(pos_r, t), up = interp_up, right = right})

		_trail_data_left.append({pos = pos_l, up = up_v, right = right})
		_trail_data_right.append({pos = pos_r, up = up_v, right = right})
		while _trail_data_left.size() > TRAIL_MAX_POINTS:
			_trail_data_left.remove_at(0)
		while _trail_data_right.size() > TRAIL_MAX_POINTS:
			_trail_data_right.remove_at(0)
	# Rebuild trail meshes
	_update_trail(_trail_left, _trail_data_left)
	_update_trail(_trail_right, _trail_data_right)

	# ── Boost rear TRON trail — records the boost light's world position ──
	if is_boosting and _boost_light:
		var mesh_right := (_vehicle_mesh.global_transform.basis.x if _vehicle_mesh else global_transform.basis.x)
		_trail_data_boost.append({pos = _boost_light.global_position, right = mesh_right})
		while _trail_data_boost.size() > 1500:
			_trail_data_boost.remove_at(0)
	elif not _trail_data_boost.is_empty():
		_trail_data_boost.clear()
	_update_boost_trail()

	# Pad lights — brighter when compressed
	for pad: OmniLight3D in _pad_lights:
		var pad_prox := clampf(1.0 - _hover_avg_dist / hover_height, 0.0, 1.0)
		var target_e := 1.5 + pad_prox * 5.0 + (2.5 if is_boosting else 0.0)
		pad.light_energy = lerpf(pad.light_energy, target_e, delta * 12.0)

	# Underbody glow
	if _underbody_light:
		var e_ratio := energy / max_energy
		var target  := 3.0 + e_ratio * 2.5 + (6.0 if is_boosting else 0.0)
		_underbody_light.light_energy = lerpf(_underbody_light.light_energy, target, delta * 7.0)

	# Boost rear light
	if _boost_light:
		_boost_light.light_energy = lerpf(_boost_light.light_energy,
			14.0 if is_boosting else 0.0, delta * 12.0)

	# ── Brake retro-jet plasma cones ──
	var braking := input_brake > 0.1
	for bi in _brake_lights.size():
		_brake_light_phase[bi] += delta * (20.0 + float(bi) * 9.0)
		var p: float = _brake_light_phase[bi]
		var flicker := 0.75 + 0.15 * sin(p) + 0.07 * sin(p * 3.3 + 1.0) + 0.03 * sin(p * 8.1 + 2.5)
		var intensity := input_brake * flicker if braking else 0.0

		# Plasma light
		var light: OmniLight3D = _brake_lights[bi]
		light.light_energy = lerpf(light.light_energy, intensity * 35.0, delta * 20.0)

		# Afterburner disc
		var bmat: StandardMaterial3D = _brake_burner_mats[bi]
		var burn_a := clampf(intensity * 1.2, 0.0, 1.0) if braking else 0.0
		bmat.albedo_color.a = lerpf(bmat.albedo_color.a, burn_a, delta * 25.0)
		bmat.emission_energy_multiplier = lerpf(bmat.emission_energy_multiplier, burn_a * 200.0, delta * 25.0)

		# Nozzle ring
		var rmat: StandardMaterial3D = _brake_ring_mats[bi]
		var ring_a := clampf(intensity, 0.0, 1.0) if braking else 0.0
		rmat.albedo_color.a = lerpf(rmat.albedo_color.a, ring_a * 0.9, delta * 20.0)
		rmat.emission_energy_multiplier = lerpf(rmat.emission_energy_multiplier, ring_a * 100.0, delta * 20.0)

		# Plasma cones — 3 per side (outer, mid, core)
		var base_idx := bi * 3
		# Outer cone — wide blue plasma
		var outer_m: StandardMaterial3D = _brake_plasma_mats[base_idx]
		outer_m.albedo_color.a = lerpf(outer_m.albedo_color.a, intensity * 0.5, delta * 18.0)
		outer_m.emission_energy_multiplier = lerpf(outer_m.emission_energy_multiplier, intensity * 80.0, delta * 18.0)
		# Mid cone — brighter
		var mid_m: StandardMaterial3D = _brake_plasma_mats[base_idx + 1]
		mid_m.albedo_color.a = lerpf(mid_m.albedo_color.a, intensity * 0.7, delta * 20.0)
		mid_m.emission_energy_multiplier = lerpf(mid_m.emission_energy_multiplier, intensity * 140.0, delta * 20.0)
		# Core cone — white hot
		var core_m: StandardMaterial3D = _brake_plasma_mats[base_idx + 2]
		core_m.albedo_color.a = lerpf(core_m.albedo_color.a, intensity * 0.9, delta * 22.0)
		core_m.emission_energy_multiplier = lerpf(core_m.emission_energy_multiplier, intensity * 250.0, delta * 22.0)

		# Plasma sparks
		if bi < _brake_sparks.size():
			var sp: GPUParticles3D = _brake_sparks[bi]
			sp.emitting = braking

	# ── Under-boost side thrusters ──
	var ub_active := input_under_boost and energy > 0.0 and not boost_empty and absf(current_roll) > 0.05
	_ub_intensity = lerpf(_ub_intensity, 1.0 if ub_active else 0.0, delta * (15.0 if ub_active else 8.0))
	var roll_sign := signf(current_roll) if absf(current_roll) > 0.05 else 0.0
	# Determine which side fires: thrust pushes opposite to roll, so jet fires on the roll side
	# roll_sign > 0 = banked right → right jet fires (pushing left)
	# Left side = index 0, Right side = index 1
	for si in 2:
		var side_sign := -1.0 if si == 0 else 1.0
		# Jet fires on the side the car is banked toward
		var jet_active := _ub_intensity > 0.01 and side_sign == roll_sign
		var intensity := _ub_intensity if jet_active else 0.0
		var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.025 + float(si) * 3.0)
		var vis := intensity * flicker

		# 3 cone materials per side: outer, mid, core
		var base_idx := si * 3
		if base_idx + 2 < _ub_jet_mats.size():
			var outer_m: StandardMaterial3D = _ub_jet_mats[base_idx]
			outer_m.albedo_color.a = lerpf(outer_m.albedo_color.a, vis * 0.6, delta * 20.0)
			outer_m.emission_energy_multiplier = lerpf(outer_m.emission_energy_multiplier, vis * 80.0, delta * 20.0)
			var mid_m: StandardMaterial3D = _ub_jet_mats[base_idx + 1]
			mid_m.albedo_color.a = lerpf(mid_m.albedo_color.a, vis * 0.8, delta * 22.0)
			mid_m.emission_energy_multiplier = lerpf(mid_m.emission_energy_multiplier, vis * 150.0, delta * 22.0)
			var core_m: StandardMaterial3D = _ub_jet_mats[base_idx + 2]
			core_m.albedo_color.a = lerpf(core_m.albedo_color.a, vis * 0.95, delta * 24.0)
			core_m.emission_energy_multiplier = lerpf(core_m.emission_energy_multiplier, vis * 250.0, delta * 24.0)

		if si < _ub_lights.size():
			var ul: OmniLight3D = _ub_lights[si]
			ul.light_energy = lerpf(ul.light_energy, vis * 25.0, delta * 18.0)

		if si < _ub_sparks.size():
			var usp: GPUParticles3D = _ub_sparks[si]
			usp.emitting = jet_active and _ub_intensity > 0.3

	# Collision trauma + noise burst
	if is_player and get_contact_count() > 0:
		var impact := linear_velocity.length()
		if impact > 8.0:
			_cam_trauma = minf(_cam_trauma + impact * 0.010, 1.0)
			_noise_t = minf(_noise_t + impact * 0.004, 0.25)

	# Position label update for AI
	if _position_label:
		_position_label.text = "P%d" % race_position

	# Engine audio synthesis
	if is_player:
		_fill_audio()
		_fill_flutter()

# ─── Engine Audio Synthesis ────────────────────────────────────────────────────
# Deep V10-style engine with sub-bass rumble, exhaust bark, and heavy saturation.
# ─── Multi-layer engine audio: hum + whine + wind + boost + grit + turbo blowoff
func _fill_audio() -> void:
	if _engine_playback == null:
		return
	var frames := _engine_playback.get_frames_available()
	if frames <= 0:
		return

	var rate := _engine_gen.mix_rate
	var dt := float(frames) / rate
	# 890 m/s ≈ 3200 km/h — full scale; allow up to 1.5 so pitch keeps climbing at mega speeds
	var spd_ratio := clampf(current_speed / 890.0, 0.0, 1.5)
	var spd2 := spd_ratio * spd_ratio

	# ── Trigger STUTUTU flutter — 1 second after heavy lift off gas ──
	if input_thrust > 0.8:
		_was_heavy_throttle = true
		_throttle_off_time = 0.0
	elif _was_heavy_throttle and input_thrust < 0.05:
		_throttle_off_time += dt
		if _throttle_off_time >= 0.75 and not _flutter_active and current_speed > 80.0:
			_trigger_flutter(spd_ratio)
			_was_heavy_throttle = false
			_throttle_off_time = 0.0
	else:
		# Back on throttle or gentle input — reset
		_was_heavy_throttle = false
		_throttle_off_time = 0.0

	# ── Trigger boost whoosh on boost start ──
	if is_boosting and not _was_boosting:
		_boost_whoosh = 1.0
	_was_boosting = is_boosting

	# ══════════════════════════════════════════════════════════════════════
	# LAYER 1: Base hum — electric motor / sci-fi turbine
	# Deep smooth tone that pitches up gently with speed
	# ══════════════════════════════════════════════════════════════════════
	var hum_f0 := 42.0 + spd_ratio * 90.0          # 42–132 Hz
	var hum_f1 := hum_f0 * 2.0                      # 2nd harmonic for body
	var hum_vol := 0.30 + spd_ratio * 0.15
	var hum_sat := 1.5 + spd_ratio * 1.0

	var hum_inc0 := hum_f0 * TAU / rate
	var hum_inc1 := hum_f1 * TAU / rate

	# ══════════════════════════════════════════════════════════════════════
	# LAYER 2: High-pitch whine — jet turbine, ramps hard with speed
	# This is what makes it FEEL fast
	# ══════════════════════════════════════════════════════════════════════
	var whine_f := 280.0 + spd2 * 2200.0            # 280–2480 Hz (quadratic ramp)
	var whine_vol := spd2 * 0.10                     # Silent at low speed, present at high
	var whine_inc := whine_f * TAU / rate

	# ══════════════════════════════════════════════════════════════════════
	# LAYER 3: Wind / air noise — crucial for speed feel
	# Volume increases with speed², filtered noise
	# ══════════════════════════════════════════════════════════════════════
	var wind_vol := spd2 * 0.18                      # Ramps up hard at speed
	# Low-pass filter cutoff rises with speed (more hiss at top speed)
	var wind_alpha := clampf(0.02 + spd_ratio * 0.15, 0.0, 1.0)

	# ══════════════════════════════════════════════════════════════════════
	# LAYER 4: Boost — distortion + extra high-freq screech + whoosh burst
	# ══════════════════════════════════════════════════════════════════════
	var boost_f := 900.0 + spd_ratio * 1200.0       # 900–2100 Hz screech
	var boost_vol := (0.08 if is_boosting else 0.0)
	var boost_sat_extra := (2.0 if is_boosting else 0.0)  # Extra distortion on all layers
	var boost_inc := boost_f * TAU / rate

	# ══════════════════════════════════════════════════════════════════════
	# LAYER 5: Grit / vibration — FM wobble on the hum + tiny noise
	# Makes it feel like a machine under stress
	# ══════════════════════════════════════════════════════════════════════
	var wobble_f := 6.0 + spd_ratio * 12.0          # 6–18 Hz wobble rate
	var wobble_depth := 0.3 + spd_ratio * 0.5       # How much pitch bends
	var grit_vol := 0.01 + spd_ratio * 0.02         # Tiny mechanical noise
	var wobble_inc := wobble_f * TAU / rate

	var local_noise := _noise_t
	var noise_step := dt

	for _i in frames:
		# ── Layer 5: Grit FM wobble (modulates hum pitch) ──
		_audio_phase6 = fmod(_audio_phase6 + wobble_inc, TAU)
		var fm := sin(_audio_phase6) * wobble_depth

		# ── Layer 1: Base hum with FM wobble ──
		var actual_hum_inc0 := (hum_f0 + fm) * TAU / rate
		var actual_hum_inc1 := (hum_f1 + fm * 2.0) * TAU / rate
		_audio_phase1 = fmod(_audio_phase1 + actual_hum_inc0, TAU)
		_audio_phase2 = fmod(_audio_phase2 + actual_hum_inc1, TAU)

		var s := sin(_audio_phase1) * 0.60          # Fundamental
		s += sin(_audio_phase2) * 0.30               # 2nd harmonic
		s = tanh(s * (hum_sat + boost_sat_extra)) * hum_vol

		# ── Layer 2: Turbine whine ──
		_audio_phase3 = fmod(_audio_phase3 + whine_inc, TAU)
		s += sin(_audio_phase3) * whine_vol

		# ── Layer 3: Wind noise (low-pass filtered white noise) ──
		var raw_wind := randf_range(-1.0, 1.0)
		_prev_wind_sample = _prev_wind_sample + wind_alpha * (raw_wind - _prev_wind_sample)
		s += _prev_wind_sample * wind_vol

		# ── Layer 4: Boost screech + whoosh ──
		if boost_vol > 0.001:
			_audio_phase5 = fmod(_audio_phase5 + boost_inc, TAU)
			s += sin(_audio_phase5) * boost_vol
		if _boost_whoosh > 0.01:
			s += randf_range(-1.0, 1.0) * _boost_whoosh * 0.12
			_boost_whoosh *= 0.9992

		# ── Dash chirp: descending frequency sweep 1800→200 Hz + noise punch ──
		if _dash_whoosh > 0.001:
			var chirp_f := 200.0 + _dash_whoosh * 1600.0
			_dash_chirp_phase = fmod(_dash_chirp_phase + chirp_f * TAU / rate, TAU)
			s += sin(_dash_chirp_phase) * _dash_whoosh * 0.22
			s += randf_range(-1.0, 1.0) * _dash_whoosh * 0.10
			_dash_whoosh *= 0.9992

		# ── Under-boost thruster: deep pressurized hiss + rising thruster tone ──
		if _ub_intensity > 0.01:
			# Thruster tone: 120 Hz base rising to 400 Hz at full intensity — beefy RCS feel
			var ub_freq := 120.0 + _ub_intensity * 280.0
			_ub_audio_phase = fmod(_ub_audio_phase + ub_freq * TAU / rate, TAU)
			# Square-ish wave (clipped sine) for harsh thruster character
			var ub_tone := clampf(sin(_ub_audio_phase) * 2.5, -1.0, 1.0)
			s += ub_tone * _ub_intensity * 0.12
			# Sub-harmonic rumble — half frequency for chest-thumping bass
			s += sin(_ub_audio_phase * 0.5) * _ub_intensity * 0.08
			# Pressurized gas hiss — filtered noise, louder at higher intensity
			var ub_raw := randf_range(-1.0, 1.0)
			_ub_hiss_filter += 0.08 * (ub_raw - _ub_hiss_filter)
			s += _ub_hiss_filter * _ub_intensity * 0.15

		# ── Boost full: resonant chime click ──
		if _boost_full_ping > 0.001:
			var e1 := _boost_full_ping
			# Primary bell tone ~2400 Hz
			_boost_full_phase = fmod(_boost_full_phase + 2400.0 * TAU / rate, TAU)
			s += sin(_boost_full_phase) * e1 * 0.30
			# Octave shimmer ~4800 Hz
			s += sin(_boost_full_phase * 2.0) * e1 * e1 * 0.14
			# Bright tink ~7200 Hz — initial sparkle only
			s += sin(_boost_full_phase * 3.0) * e1 * e1 * e1 * 0.08
			# Initial transient click — first ~3ms
			if e1 > 0.90:
				s += randf_range(-1.0, 1.0) * (e1 - 0.90) * 10.0 * 0.06
			# Medium decay — sharp attack, ~120ms ring-out
			_boost_full_ping *= 0.99945

		# ── Layer 5: Mechanical grit ──
		s += randf_range(-1.0, 1.0) * grit_vol

		# ── Collision crackle ──
		if local_noise > 0.0:
			s += randf_range(-1.0, 1.0) * local_noise * 0.3
			local_noise -= noise_step / float(frames)

		# ── Master output: soft tanh limiter (no hard clipping) ──
		var sv := tanh(s * 1.8) * 0.5
		_engine_playback.push_frame(Vector2(sv, sv))

	_noise_t        = maxf(_noise_t        - noise_step, 0.0)
	_boost_whoosh   = maxf(_boost_whoosh   - dt * 3.0,  0.0)
	_dash_whoosh    = maxf(_dash_whoosh    - dt * 2.5,  0.0)
	_boost_full_ping = maxf(_boost_full_ping - dt * 3.0, 0.0)

# ─── Turbo Flutter (STUTUTU) — Compressor Surge ──────────────────────────────
# Separate audio stream. Each "tu" = a soft air puff with a breathy tail,
# NOT a hard click. Pulses are wide (60% duty), spaced at 18-28 Hz (slower
# than before — audibly distinct), with slight timing jitter for realism.
# Two layers: shaped low-freq air bursts + continuous breathy whoosh bed.

func _trigger_flutter(spd_ratio: float) -> void:
	_flutter_active = true
	_flutter_sample_pos = 0
	_flutter_intensity = 0.7 + spd_ratio * 0.3
	# 6-8 bursts — slower at high speed, more turbo character
	_flutter_pulse_rate = 6.0 + spd_ratio * 2.0 + randf_range(-1.0, 1.0)
	var num_pulses := int(4 + spd_ratio * 3 + randf_range(-1.0, 1.0))
	var duration := float(num_pulses) / _flutter_pulse_rate + 0.08
	_flutter_total_samples = int(duration * 44100.0)
	_flutter_intensity *= randf_range(0.75, 1.15)
	# Reset filter states for clean start
	_flutter_filt1 = 0.0
	_flutter_filt2 = 0.0
	_flutter_filt3 = 0.0

func _fill_flutter() -> void:
	if _flutter_playback == null:
		return
	var frames := _flutter_playback.get_frames_available()
	if frames <= 0:
		return

	var rate := 44100.0

	for _i in frames:
		if not _flutter_active or _flutter_sample_pos >= _flutter_total_samples:
			_flutter_filt1 *= 0.9995
			_flutter_filt2 *= 0.9995
			_flutter_playback.push_frame(Vector2(_flutter_filt2 * 0.05, _flutter_filt2 * 0.05))
			if _flutter_active and _flutter_sample_pos >= _flutter_total_samples:
				_flutter_active = false
			continue

		var t := float(_flutter_sample_pos) / rate
		var progress := float(_flutter_sample_pos) / float(_flutter_total_samples)

		# ── Master fade: 20ms in, gradual out ──
		var master := minf(float(_flutter_sample_pos) / 880.0, 1.0) * (1.0 - progress * 0.85)

		# ── Which burst are we in? At 4-6 Hz each burst is ~200ms ──
		var cycle_raw := t * _flutter_pulse_rate
		var cycle_pos := fmod(cycle_raw, 1.0)

		# ── Each burst: 50% on, 50% off. Smooth sine-squared envelope ──
		# sin² gives perfectly smooth attack AND decay — zero clicks guaranteed
		var burst_env := 0.0
		if cycle_pos < 0.50:
			burst_env = sin(cycle_pos / 0.50 * PI)
			burst_env *= burst_env  # sin² = smooth bell shape

		# ── Noise source: 2-pole filter, alpha=0.45 (~3200 Hz cutoff) ──
		# High hiss = turbo compressor character
		var raw := randf_range(-1.0, 1.0)
		_flutter_filt1 += 0.45 * (raw - _flutter_filt1)
		_flutter_filt2 += 0.45 * (_flutter_filt1 - _flutter_filt2)
		var air := _flutter_filt2

		# ── Mix: turbo hiss ──
		var s := air * burst_env * master * _flutter_intensity * 0.35

		# Soft limit
		s = tanh(s * 2.0) * 0.32

		_flutter_playback.push_frame(Vector2(s, s))
		_flutter_sample_pos += 1

# ─── Clamp Speed ───────────────────────────────────────────────────────────────
func _clamp_velocity() -> void:
	# No hard cap — diminishing returns in _apply_propulsion handles speed limiting
	pass

func _coast_to_stop() -> void:
	input_thrust = 0.0
	input_brake  = 1.0
	input_steer  = 0.0
	is_boosting  = false

# ─── Process (Player Input) ────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if has_finished:
		return
	_update_ghosts(delta)
	if is_player:
		_read_player_input()
		race_time += delta

func _read_player_input() -> void:
	input_thrust   = Input.get_action_strength("accelerate")
	input_brake    = Input.get_action_strength("brake")
	input_steer    = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	input_boost       = Input.is_action_pressed("boost")
	input_under_boost = Input.is_action_pressed("under_boost")

	_air_bank_input = 0.0
	if Input.is_action_pressed("dash_left"):
		_air_bank_input -= 1.0
	if Input.is_action_pressed("dash_right"):
		_air_bank_input += 1.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_player:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_T:
		steer_sensitivity = (steer_sensitivity + 1) % STEER_LABELS.size()
		var label: String = STEER_LABELS[steer_sensitivity]
		var mult: float   = STEER_MULTIPLIERS[steer_sensitivity]
		print("Steering: %s (%.0f%%)" % [label, mult * 100.0])
		# Show on HUD if available
		var hud_node = get_tree().get_first_node_in_group("hud")
		if hud_node and hud_node.has_method("flash_lap_message"):
			hud_node.flash_lap_message("STEERING: %s" % label)

# ─── AI Interface ──────────────────────────────────────────────────────────────
func set_ai_inputs(thrust: float, steer: float, do_boost: bool, do_brake: bool = false) -> void:
	input_thrust   = thrust
	input_steer    = steer
	input_brake    = 1.0 if do_brake else 0.0
	input_boost    = do_boost

# ─── Public ────────────────────────────────────────────────────────────────────
func get_speed_kmh() -> float:
	return current_speed * KMH_FACTOR

## Called by RaceManager immediately after placing the vehicle on the grid.
## Seeds the respawn system so there is always a valid fallback from frame one.
func seed_respawn(pos: Vector3, fwd: Vector3) -> void:
	_has_respawn_pos = true
	_respawn_pos     = pos
	var f := fwd
	f.y = 0.0
	_respawn_basis   = Basis.looking_at(
		f.normalized() if f.length_squared() > 0.01 else Vector3(0.0, 0.0, -1.0),
		Vector3.UP
	)

func finish_race(time: float) -> void:
	has_finished = true
	finish_time  = time
