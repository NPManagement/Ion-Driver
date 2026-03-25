## CameraSettings — Global camera tuning values, adjustable from options menu.
## All values have sensible defaults matching the current tuning.
extends Node

# ── Lateral slide (camera shifts sideways in turns) ──
var lateral_base: float       = 2.5    # Slide amount at low speed (meters)
var lateral_speed_scale: float = 6.5   # Extra slide at full speed (meters)
var lateral_out_rate: float   = 1.2    # How fast camera slides out
var lateral_return_rate: float = 2.5   # How fast camera returns to center

# ── Roll tilt (horizon tilts in turns) ──
var tilt_deadzone: float      = 0.65   # Steering input below this = no tilt (0-1)
var tilt_base: float          = 0.1    # Tilt at low speed (radians)
var tilt_speed_scale: float   = 0.35   # Extra tilt at full speed (radians)
var tilt_rate: float          = 0.5    # How fast tilt responds

# ── Yaw follow (camera rotates to follow nose) ──
var yaw_base: float           = 0.04   # Yaw at low speed (radians)
var yaw_speed_scale: float    = 0.08   # Extra yaw at full speed (radians)
var yaw_rate: float           = 1.5    # How fast yaw responds

# ── FOV ──
var fov_base: float           = 95.0   # FOV at rest (degrees)
var fov_speed_scale: float    = 20.0   # Extra FOV at full speed (degrees)
var fov_boost: float          = 12.0   # Extra FOV during boost (degrees)

# ── Distance / Height / Pitch ──
var distance_base: float      = 5.0    # Spring arm length at rest
var distance_speed_scale: float = 1.5  # Extra distance at full speed
var height_base: float        = 1.0    # Camera height at rest
var pitch_base: float         = -14.0  # Pitch at rest (degrees)
var pitch_speed_scale: float  = 10.0   # Extra pitch-down at full speed

# ── Motion Blur ──
var blur_strength: float      = 0.9    # Max blur multiplier (0-1)
var blur_speed_ref: float     = 120.0  # Speed for full blur (m/s)


const SAVE_PATH := "user://camera_settings.cfg"

# Defaults — used by reset
const DEFAULTS := {
	"lateral_base": 2.5, "lateral_speed_scale": 6.5,
	"lateral_out_rate": 1.2, "lateral_return_rate": 2.5,
	"tilt_deadzone": 0.65, "tilt_base": 0.1,
	"tilt_speed_scale": 0.35, "tilt_rate": 0.5,
	"yaw_base": 0.04, "yaw_speed_scale": 0.08, "yaw_rate": 1.5,
	"fov_base": 95.0, "fov_speed_scale": 20.0, "fov_boost": 12.0,
	"distance_base": 5.0, "distance_speed_scale": 1.5,
	"height_base": 1.0, "pitch_base": -14.0, "pitch_speed_scale": 10.0,
	"blur_strength": 0.9, "blur_speed_ref": 120.0,
}

signal settings_reset  # Emitted so UI sliders can refresh

func reset_defaults() -> void:
	for key in DEFAULTS:
		set(key, DEFAULTS[key])
	save_settings()
	settings_reset.emit()

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "lateral_base", lateral_base)
	cfg.set_value("camera", "lateral_speed_scale", lateral_speed_scale)
	cfg.set_value("camera", "lateral_out_rate", lateral_out_rate)
	cfg.set_value("camera", "lateral_return_rate", lateral_return_rate)
	cfg.set_value("camera", "tilt_deadzone", tilt_deadzone)
	cfg.set_value("camera", "tilt_base", tilt_base)
	cfg.set_value("camera", "tilt_speed_scale", tilt_speed_scale)
	cfg.set_value("camera", "tilt_rate", tilt_rate)
	cfg.set_value("camera", "yaw_base", yaw_base)
	cfg.set_value("camera", "yaw_speed_scale", yaw_speed_scale)
	cfg.set_value("camera", "yaw_rate", yaw_rate)
	cfg.set_value("camera", "fov_base", fov_base)
	cfg.set_value("camera", "fov_speed_scale", fov_speed_scale)
	cfg.set_value("camera", "fov_boost", fov_boost)
	cfg.set_value("camera", "distance_base", distance_base)
	cfg.set_value("camera", "distance_speed_scale", distance_speed_scale)
	cfg.set_value("camera", "height_base", height_base)
	cfg.set_value("camera", "pitch_base", pitch_base)
	cfg.set_value("camera", "pitch_speed_scale", pitch_speed_scale)
	cfg.set_value("camera", "blur_strength", blur_strength)
	cfg.set_value("camera", "blur_speed_ref", blur_speed_ref)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	lateral_base = cfg.get_value("camera", "lateral_base", lateral_base)
	lateral_speed_scale = cfg.get_value("camera", "lateral_speed_scale", lateral_speed_scale)
	lateral_out_rate = cfg.get_value("camera", "lateral_out_rate", lateral_out_rate)
	lateral_return_rate = cfg.get_value("camera", "lateral_return_rate", lateral_return_rate)
	tilt_deadzone = cfg.get_value("camera", "tilt_deadzone", tilt_deadzone)
	tilt_base = cfg.get_value("camera", "tilt_base", tilt_base)
	tilt_speed_scale = cfg.get_value("camera", "tilt_speed_scale", tilt_speed_scale)
	tilt_rate = cfg.get_value("camera", "tilt_rate", tilt_rate)
	yaw_base = cfg.get_value("camera", "yaw_base", yaw_base)
	yaw_speed_scale = cfg.get_value("camera", "yaw_speed_scale", yaw_speed_scale)
	yaw_rate = cfg.get_value("camera", "yaw_rate", yaw_rate)
	fov_base = cfg.get_value("camera", "fov_base", fov_base)
	fov_speed_scale = cfg.get_value("camera", "fov_speed_scale", fov_speed_scale)
	fov_boost = cfg.get_value("camera", "fov_boost", fov_boost)
	distance_base = cfg.get_value("camera", "distance_base", distance_base)
	distance_speed_scale = cfg.get_value("camera", "distance_speed_scale", distance_speed_scale)
	height_base = cfg.get_value("camera", "height_base", height_base)
	pitch_base = cfg.get_value("camera", "pitch_base", pitch_base)
	pitch_speed_scale = cfg.get_value("camera", "pitch_speed_scale", pitch_speed_scale)
	blur_strength = cfg.get_value("camera", "blur_strength", blur_strength)
	blur_speed_ref = cfg.get_value("camera", "blur_speed_ref", blur_speed_ref)
